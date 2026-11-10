// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Thread con prelazione su tutte le CPU (K2, esteso in K3). Il timer APIC di ogni CPU
//! (100 Hz) chiama `tick`.
//!
//! K3: scelta per "tempo virtuale" pesato dalla priorità. A ogni tick il thread corrente
//! accumula `QUANTO / peso` (pesi 1, 2, 4 per priorità bassa, normale, alta) e gira il thread
//! disponibile con il tempo virtuale minore: un thread ad alta priorità riceve circa quattro
//! volte il tempo di uno a bassa priorità e nessuno resta senza CPU. I thread d'attesa delle
//! CPU secondarie (priorità 0) girano solo quando non c'è altro. Ogni thread ha il proprio
//! spazio d'indirizzi (CR3) e, se esegue codice utente, il proprio stack del kernel, la cui
//! cima va in RSP0 del TSS e nei dati della CPU per le chiamate di sistema.
//!
//! Il cambio di contesto salva i registri da preservare e RFLAGS sullo stack del thread
//! uscente e solo DOPO azzera il suo flag "in esecuzione": un'altra CPU non può riprendere un
//! thread finché il suo stack non è stato salvato del tutto.

use crate::arch::{anelli, cpu};
use crate::mem::{heap, pagine};
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

/// Priorità 0: thread d'attesa di una CPU (gira solo se non c'è altro).
pub const PRIORITA_ATTESA: u8 = 0;
pub const PRIORITA_BASSA: u8 = 1;
pub const PRIORITA_NORMALE: u8 = 2;
pub const PRIORITA_ALTA: u8 = 3;
const QUANTO: u64 = 12;

fn peso(p: u8) -> u64 {
    1 << (p.clamp(1, 3) - 1)
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
    priorita: u8,
    virtuale: u64,
    /// tick del timer passati in esecuzione
    quanti: u64,
    cr3: u64,
    /// stack del kernel (cima, pagine); None per i flussi d'avvio
    pila: Option<(u64, u64)>,
    /// processo utente (0 = thread del kernel)
    processo: u64,
    /// richiesta di terminazione (processo che termina): eseguita al prossimo rientro dal kernel
    uccidi: AtomicBool,
}

struct Pianificatore {
    // Box: l'indirizzo di `Thread::rsp` e del flag deve restare stabile anche quando il Vec
    // cresce, perché omni_cambia_contesto vi scrive. Le posizioni liberate da `raccogli`
    // vengono riusate (identificativi riusati solo dopo la raccolta).
    #[allow(clippy::vec_box)]
    thread: Vec<Option<Box<Thread>>>,
    corrente: [usize; MAX_CPU],
    attivo: bool,
    /// minimo tempo virtuale visto all'ultima scelta (punto di partenza dei nuovi thread)
    minimo: u64,
}

static PIANIFICATORE: Blocco<Pianificatore> = Blocco::new(Pianificatore { thread: Vec::new(), corrente: [0; MAX_CPU], attivo: false, minimo: 0 });
pub static CAMBI: AtomicU64 = AtomicU64::new(0);

impl Pianificatore {
    fn t(&self, i: usize) -> &Thread {
        self.thread[i].as_deref().expect("thread inesistente")
    }
    fn t_mut(&mut self, i: usize) -> &mut Thread {
        self.thread[i].as_deref_mut().expect("thread inesistente")
    }
    fn inserisci(&mut self, t: Box<Thread>) -> usize {
        if let Some(i) = self.thread.iter().position(|x| x.is_none()) {
            self.thread[i] = Some(t);
            i
        } else {
            self.thread.push(Some(t));
            self.thread.len() - 1
        }
    }
}

struct Nuovo {
    nome: &'static str,
    rsp: u64,
    in_esecuzione: bool,
    affinita: Option<usize>,
    priorita: u8,
    virtuale: u64,
    cr3: u64,
    pila: Option<(u64, u64)>,
    processo: u64,
}

fn nuovo(n: Nuovo) -> Box<Thread> {
    Box::new(Thread {
        nome: n.nome,
        rsp: n.rsp,
        stato: Stato::Pronto,
        esecuzioni: 0,
        in_esecuzione: AtomicBool::new(n.in_esecuzione),
        affinita: n.affinita,
        cpu_usate: 0,
        priorita: n.priorita,
        virtuale: n.virtuale,
        quanti: 0,
        cr3: n.cr3,
        pila: n.pila,
        processo: n.processo,
        uccidi: AtomicBool::new(false),
    })
}

/// Registra il flusso corrente (kmain, sullo stack di avvio) come thread della CPU 0.
pub fn inizializza() {
    let cr3 = pagine::pml4_kernel();
    let mut p = PIANIFICATORE.prendi();
    let mut t = nuovo(Nuovo {
        nome: "principale",
        rsp: 0,
        in_esecuzione: true,
        affinita: Some(0),
        priorita: PRIORITA_NORMALE,
        virtuale: 0,
        cr3,
        pila: None,
        processo: 0,
    });
    t.esecuzioni = 1;
    t.cpu_usate = 1;
    let id = p.inserisci(t);
    p.corrente[0] = id;
    p.attivo = true;
}

/// Registra il flusso d'avvio di una CPU secondaria come suo thread d'attesa.
pub fn registra_cpu(cpu: usize) {
    let cr3 = pagine::pml4_kernel();
    let mut p = PIANIFICATORE.prendi();
    let mut t =
        nuovo(Nuovo { nome: "attesa", rsp: 0, in_esecuzione: true, affinita: Some(cpu), priorita: PRIORITA_ATTESA, virtuale: 0, cr3, pila: None, processo: 0 });
    t.cpu_usate = 1 << cpu;
    let id = p.inserisci(t);
    p.corrente[cpu] = id;
}

#[no_mangle]
extern "C" fn omni_corpo_thread(funzione: usize, argomento: usize) -> ! {
    // SAFETY: `funzione` è un `fn(usize)` registrato da `crea`
    let f: fn(usize) = unsafe { core::mem::transmute(funzione) };
    f(argomento);
    termina_corrente()
}

/// Termina il thread corrente; non ritorna. Usabile anche da un gestore d'interruzione:
/// lo stack viene abbandonato e rilasciato più tardi da `raccogli`.
pub fn termina_corrente() -> ! {
    {
        let mut p = PIANIFICATORE.prendi();
        let c = p.corrente[smp::indice()];
        p.t_mut(c).stato = Stato::Terminato;
    }
    loop {
        cedi();
        // da un gestore d'interruzione le interruzioni sono disattivate: qui servono attive
        cpu::attiva_interruzioni();
        cpu::attendi();
    }
}

/// Stack iniziale come lo lascerebbe `omni_cambia_contesto`: rflags, r15..rbp, ritorno.
fn prepara_stack(cima: u64, funzione: fn(usize), argomento: usize) -> u64 {
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
    rsp
}

/// Crea un thread del kernel con uno stack proprio (con pagina di guardia).
pub fn crea(nome: &'static str, funzione: fn(usize), argomento: usize, pagine_stack: u64) -> u64 {
    crea_su(nome, funzione, argomento, pagine_stack, None)
}

/// Come `crea`, ma il thread gira solo sulla CPU indicata.
pub fn crea_su(nome: &'static str, funzione: fn(usize), argomento: usize, pagine_stack: u64, cpu: Option<usize>) -> u64 {
    crea_completo(nome, funzione, argomento, pagine_stack, cpu, PRIORITA_NORMALE, pagine::pml4_kernel(), 0)
}

/// Thread con spazio d'indirizzi, priorità e processo indicati (K3).
#[allow(clippy::too_many_arguments)]
pub fn crea_completo(
    nome: &'static str,
    funzione: fn(usize),
    argomento: usize,
    pagine_stack: u64,
    cpu: Option<usize>,
    priorita: u8,
    cr3: u64,
    processo: u64,
) -> u64 {
    let cima = heap::nuovo_stack(pagine_stack);
    let rsp = prepara_stack(cima, funzione, argomento);
    let mut p = PIANIFICATORE.prendi();
    let virtuale = p.minimo;
    let t = nuovo(Nuovo {
        nome,
        rsp,
        in_esecuzione: false,
        affinita: cpu,
        priorita: priorita.clamp(1, 3),
        virtuale,
        cr3,
        pila: Some((cima, pagine_stack)),
        processo,
    });
    p.inserisci(t) as u64
}

/// Passa al thread migliore per questa CPU. `volontario`: chiamata da `cedi` (il thread
/// corrente rinuncia: si sceglie fra gli altri). Interruzioni disattivate.
fn scegli(volontario: bool) {
    let cpu = smp::indice();
    let (vecchio, nuovo, flag, cr3, pila) = {
        let mut p = PIANIFICATORE.prendi();
        if !p.attivo {
            return;
        }
        let c = p.corrente[cpu];
        if !volontario {
            let t = p.t_mut(c);
            if t.priorita != PRIORITA_ATTESA {
                t.quanti += 1;
                t.virtuale += QUANTO / peso(t.priorita);
            }
        }
        let disponibile = |t: &Thread| t.stato == Stato::Pronto && !t.in_esecuzione.load(Ordering::Acquire) && t.affinita.is_none_or(|a| a == cpu);
        let mut migliore: Option<(usize, u64)> = None;
        let mut attesa = None;
        let n = p.thread.len();
        for k in 1..n {
            let i = (c + k) % n;
            let Some(t) = p.thread[i].as_deref() else { continue };
            if !disponibile(t) {
                continue;
            }
            if t.priorita == PRIORITA_ATTESA {
                attesa.get_or_insert(i);
            } else if migliore.is_none_or(|(_, v)| t.virtuale < v) {
                migliore = Some((i, t.virtuale));
            }
        }
        let corrente = p.t(c);
        let resta = corrente.stato == Stato::Pronto && corrente.priorita != PRIORITA_ATTESA;
        if let Some((_, v)) = migliore {
            p.minimo = if resta { v.min(p.t(c).virtuale) } else { v };
        }
        let s = match migliore {
            // il corrente continua se non cede e ha il tempo virtuale minore
            Some((_, v)) if resta && !volontario && p.t(c).virtuale <= v => return,
            Some((i, _)) => i,
            None if resta => return,
            None => match attesa {
                Some(i) => i,
                None => return,
            },
        };
        let t = p.t_mut(s);
        t.in_esecuzione.store(true, Ordering::Release);
        t.esecuzioni += 1;
        t.cpu_usate |= 1 << cpu;
        let (nuovo, cr3, pila) = (t.rsp, t.cr3, t.pila.map(|x| x.0).unwrap_or(0));
        p.corrente[cpu] = s;
        let vt = p.t_mut(c);
        let flag = vt.in_esecuzione.as_ptr() as *mut u8;
        let vecchio: *mut u64 = &mut vt.rsp;
        (vecchio, nuovo, flag, cr3, pila)
    };
    CAMBI.fetch_add(1, Ordering::Relaxed);
    if cr3 != cpu::cr3() & 0x000f_ffff_ffff_f000 {
        // SAFETY: ogni spazio contiene la metà alta del kernel (codice, dati, stack, heap)
        unsafe { cpu::imposta_cr3(cr3) };
    }
    if pila != 0 {
        anelli::imposta_pila_kernel(cpu, pila);
    }
    // SAFETY: i Thread sono in Box (indirizzi stabili, non rilasciati finché in esecuzione);
    // lo stack del thread entrante contiene un contesto salvato da omni_cambia_contesto (il
    // suo flag era falso, quindi il salvataggio è completo) o preparato da `prepara_stack`
    unsafe { omni_cambia_contesto(vecchio, nuovo, flag) };
}

/// Dal gestore del timer.
pub fn tick() {
    scegli(false);
}

/// Cede volontariamente la CPU.
pub fn cedi() {
    let attive = cpu::interruzioni_attive();
    cpu::disattiva_interruzioni(); // nessun timer durante il cambio
    scegli(true);
    if attive {
        cpu::attiva_interruzioni();
    }
}

fn con<R>(id: u64, f: impl FnOnce(&Thread) -> R) -> Option<R> {
    PIANIFICATORE.prendi().thread.get(id as usize).and_then(|t| t.as_deref()).map(f)
}

pub fn esecuzioni(id: u64) -> u64 {
    con(id, |t| t.esecuzioni).unwrap_or(0)
}

pub fn cpu_usate(id: u64) -> u32 {
    con(id, |t| t.cpu_usate).unwrap_or(0)
}

pub fn nome(id: u64) -> &'static str {
    con(id, |t| t.nome).unwrap_or("?")
}

pub fn terminato(id: u64) -> bool {
    con(id, |t| t.stato == Stato::Terminato).unwrap_or(true)
}

pub fn quanti(id: u64) -> u64 {
    con(id, |t| t.quanti).unwrap_or(0)
}

pub fn processo(id: u64) -> u64 {
    con(id, |t| t.processo).unwrap_or(0)
}

/// Thread corrente di questa CPU.
pub fn corrente() -> u64 {
    PIANIFICATORE.prendi().corrente[smp::indice()] as u64
}

/// Processo del thread corrente (0 = kernel) e richiesta di terminazione pendente.
pub fn processo_corrente() -> (u64, bool) {
    let p = PIANIFICATORE.prendi();
    let t = p.t(p.corrente[smp::indice()]);
    (t.processo, t.uccidi.load(Ordering::Acquire))
}

/// Chiede la terminazione di un thread (eseguita quando rientra dal kernel o dal timer).
pub fn segnala_uccisione(id: u64) {
    if let Some(t) = PIANIFICATORE.prendi().thread.get(id as usize).and_then(|t| t.as_deref()) {
        t.uccidi.store(true, Ordering::Release);
    }
}

/// Rilascia un thread terminato che nessuna CPU sta più eseguendo (stack e struttura).
/// true se rilasciato (o già inesistente).
pub fn raccogli(id: u64) -> bool {
    let t = {
        let mut p = PIANIFICATORE.prendi();
        let i = id as usize;
        match p.thread.get(i).and_then(|t| t.as_deref()) {
            None => return true,
            Some(t) if t.stato != Stato::Terminato || t.in_esecuzione.load(Ordering::Acquire) => return false,
            Some(_) => {}
        }
        p.thread[i].take()
    };
    if let Some((cima, pagine)) = t.as_ref().and_then(|t| t.pila) {
        heap::libera_stack(cima, pagine);
    }
    true
}
