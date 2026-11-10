// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Thread del kernel con prelazione, su tutte le CPU (K2). Il timer APIC di ogni CPU
//! (100 Hz) chiama `tick`, che passa al thread pronto successivo non in esecuzione altrove
//! (round-robin, con affinità facoltativa a una CPU).
//!
//! Il cambio di contesto salva i registri da preservare e RFLAGS sullo stack del thread
//! uscente e solo DOPO azzera il suo flag "in esecuzione": un'altra CPU non può riprendere un
//! thread finché il suo stack non è stato salvato del tutto.

use crate::mem::heap;
use crate::smp;
use crate::sync::Blocco;
use alloc::boxed::Box;
use alloc::vec::Vec;
use core::arch::global_asm;
use core::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use omni_comune::acpi::MAX_CPU;

global_asm!(
    r#"
.global omni_cambia_contesto
// rdi = &mut rsp del thread uscente, rsi = rsp del thread entrante,
// rdx = &flag "in esecuzione" del thread uscente (azzerato dopo il salvataggio)
omni_cambia_contesto:
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    pushfq
    mov [rdi], rsp
    mov byte ptr [rdx], 0
    mov rsp, rsi
    popfq
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global omni_avvio_thread
// primo ingresso di un thread: r12 = funzione, r13 = argomento
omni_avvio_thread:
    sti
    mov rdi, r12
    mov rsi, r13
    call omni_corpo_thread
    ud2
"#
);

extern "C" {
    fn omni_cambia_contesto(vecchio: *mut u64, nuovo: u64, flag_vecchio: *mut u8);
    fn omni_avvio_thread();
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Stato {
    Pronto,
    Terminato,
}

pub struct Thread {
    pub nome: &'static str,
    rsp: u64,
    pub stato: Stato,
    pub esecuzioni: u64,
    /// true mentre una CPU lo esegue (o ne sta salvando il contesto)
    in_esecuzione: AtomicBool,
    /// CPU su cui deve girare (None = qualsiasi)
    affinita: Option<usize>,
    /// CPU su cui è stato eseguito (una per bit)
    pub cpu_usate: u32,
}

struct Pianificatore {
    // Box: l'indirizzo di `Thread::rsp` e del flag deve restare stabile anche quando il Vec
    // cresce, perché omni_cambia_contesto vi scrive
    #[allow(clippy::vec_box)]
    thread: Vec<Box<Thread>>,
    corrente: [usize; MAX_CPU],
    attivo: bool,
}

static PIANIFICATORE: Blocco<Pianificatore> = Blocco::new(Pianificatore { thread: Vec::new(), corrente: [0; MAX_CPU], attivo: false });
pub static CAMBI: AtomicU64 = AtomicU64::new(0);

fn nuovo(nome: &'static str, rsp: u64, in_esecuzione: bool, affinita: Option<usize>) -> Box<Thread> {
    Box::new(Thread { nome, rsp, stato: Stato::Pronto, esecuzioni: 0, in_esecuzione: AtomicBool::new(in_esecuzione), affinita, cpu_usate: 0 })
}

/// Registra il flusso corrente (kmain, sullo stack di avvio) come thread della CPU 0.
pub fn inizializza() {
    let mut p = PIANIFICATORE.prendi();
    let mut t = nuovo("principale", 0, true, Some(0));
    t.esecuzioni = 1;
    t.cpu_usate = 1;
    p.thread.push(t);
    p.corrente[0] = 0;
    p.attivo = true;
}

/// Registra il flusso d'avvio di una CPU secondaria come suo thread d'attesa.
pub fn registra_cpu(cpu: usize) {
    let mut p = PIANIFICATORE.prendi();
    let id = p.thread.len();
    let mut t = nuovo("attesa", 0, true, Some(cpu));
    t.cpu_usate = 1 << cpu;
    p.thread.push(t);
    p.corrente[cpu] = id;
}

#[no_mangle]
extern "C" fn omni_corpo_thread(funzione: usize, argomento: usize) -> ! {
    // SAFETY: `funzione` è un `fn(usize)` registrato da `crea`
    let f: fn(usize) = unsafe { core::mem::transmute(funzione) };
    f(argomento);
    {
        let mut p = PIANIFICATORE.prendi();
        let c = p.corrente[smp::indice()];
        p.thread[c].stato = Stato::Terminato;
    }
    loop {
        cedi();
        crate::arch::cpu::attendi();
    }
}

/// Crea un thread del kernel con uno stack proprio (con pagina di guardia).
pub fn crea(nome: &'static str, funzione: fn(usize), argomento: usize, pagine_stack: u64) -> u64 {
    crea_su(nome, funzione, argomento, pagine_stack, None)
}

/// Come `crea`, ma il thread gira solo sulla CPU indicata.
pub fn crea_su(nome: &'static str, funzione: fn(usize), argomento: usize, pagine_stack: u64, cpu: Option<usize>) -> u64 {
    let cima = heap::nuovo_stack(pagine_stack);
    // stack iniziale come lo lascerebbe `omni_cambia_contesto`: rflags, r15..rbp, indirizzo di ritorno
    let valori: [u64; 8] = [
        0x2,                                                         // RFLAGS (interruzioni disattivate: le attiva omni_avvio_thread)
        0,                                                           // r15
        0,                                                           // r14
        argomento as u64,                                            // r13
        funzione as usize as u64,                                    // r12 (puntatore a funzione)
        0,                                                           // rbx
        0,                                                           // rbp
        omni_avvio_thread as unsafe extern "C" fn() as usize as u64, // ritorno
    ];
    let rsp = cima - 8 * (valori.len() as u64 + 1); // +1: allineamento a 16 dopo il `ret`
    for (i, v) in valori.iter().enumerate() {
        // SAFETY: lo stack è appena stato mappato e scrivibile
        unsafe { ((rsp + 8 * i as u64) as *mut u64).write(*v) };
    }
    let mut p = PIANIFICATORE.prendi();
    let id = p.thread.len() as u64;
    p.thread.push(nuovo(nome, rsp, false, cpu));
    id
}

/// Passa al thread pronto successivo per questa CPU, se esiste. Chiamata con le interruzioni
/// disattivate (dal gestore del timer) oppure da `cedi`.
pub fn tick() {
    let cpu = smp::indice();
    let (vecchio, nuovo, flag) = {
        let mut p = PIANIFICATORE.prendi();
        if !p.attivo || p.thread.len() < 2 {
            return;
        }
        let n = p.thread.len();
        let c = p.corrente[cpu];
        let disponibile = |t: &Thread| t.stato == Stato::Pronto && !t.in_esecuzione.load(Ordering::Acquire) && t.affinita.is_none_or(|a| a == cpu);
        let Some(s) = (1..n).map(|k| (c + k) % n).find(|&i| disponibile(&p.thread[i])) else { return };
        p.thread[s].in_esecuzione.store(true, Ordering::Release);
        p.corrente[cpu] = s;
        p.thread[s].esecuzioni += 1;
        p.thread[s].cpu_usate |= 1 << cpu;
        let flag = p.thread[c].in_esecuzione.as_ptr() as *mut u8;
        let vecchio: *mut u64 = &mut p.thread[c].rsp;
        (vecchio, p.thread[s].rsp, flag)
    };
    CAMBI.fetch_add(1, Ordering::Relaxed);
    // SAFETY: i Thread sono in Box (indirizzi stabili); lo stack del thread entrante contiene
    // un contesto salvato da omni_cambia_contesto (il suo flag era falso, quindi il
    // salvataggio è completo) o preparato da `crea_su`
    unsafe { omni_cambia_contesto(vecchio, nuovo, flag) };
}

/// Cede volontariamente la CPU.
pub fn cedi() {
    let attive = crate::arch::cpu::interruzioni_attive();
    crate::arch::cpu::disattiva_interruzioni(); // nessun timer durante il cambio
    tick();
    if attive {
        crate::arch::cpu::attiva_interruzioni();
    }
}

pub fn esecuzioni(id: u64) -> u64 {
    PIANIFICATORE.prendi().thread.get(id as usize).map(|t| t.esecuzioni).unwrap_or(0)
}

pub fn cpu_usate(id: u64) -> u32 {
    PIANIFICATORE.prendi().thread.get(id as usize).map(|t| t.cpu_usate).unwrap_or(0)
}

pub fn nome(id: u64) -> &'static str {
    PIANIFICATORE.prendi().thread.get(id as usize).map(|t| t.nome).unwrap_or("?")
}

pub fn terminato(id: u64) -> bool {
    PIANIFICATORE.prendi().thread.get(id as usize).map(|t| t.stato == Stato::Terminato).unwrap_or(true)
}
