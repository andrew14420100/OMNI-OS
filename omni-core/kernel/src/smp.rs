// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Multiprocessore (K2):
//! - avvio delle CPU secondarie con INIT-SIPI-SIPI (Intel SDM vol. 3, 9.4 e 11.6) e un
//!   trampolino che passa dalla modalità reale alla modalità lunga;
//! - indice della CPU corrente (dall'ID APIC);
//! - invalidazione del TLB su tutte le CPU (shootdown) dopo la rimozione di una pagina.

use crate::arch::{cpu, gdt, idt};
use crate::mem::{frame, heap, pagine};
use crate::{kprintln, sched, tempo};
use core::arch::global_asm;
use core::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, AtomicU8, Ordering};
use omni_comune::acpi::{Madt, MAX_CPU};

/// Pagina fisica del trampolino (sotto 1 MiB, multiplo di 4 KiB: vettore SIPI 0x08).
const TRAMPOLINO: u64 = 0x8000;

// Trampolino: copiato a 0x8000 ed eseguito dalle CPU secondarie. Gli indirizzi sono
// calcolati come differenze di etichette + 0x8000 (codice indipendente dalla posizione nel
// kernel). Modalità reale → modalità lunga diretta (PAE, LME, NXE, poi PG+PE insieme).
global_asm!(
    r#"
.section .rodata.omni_trampolino, "a"
.global omni_trampolino_inizio
.global omni_trampolino_fine
.global omni_tr_cr3
.global omni_tr_stack
.global omni_tr_ingresso
.global omni_tr_indice
.code16
omni_trampolino_inizio:
    cli
    cld
    xorw %ax, %ax
    movw %ax, %ds
    lgdtl (omni_tr_gdtr - omni_trampolino_inizio + 0x8000)
    movl %cr4, %eax
    orl $0x20, %eax
    movl %eax, %cr4
    movl (omni_tr_cr3 - omni_trampolino_inizio + 0x8000), %eax
    movl %eax, %cr3
    movl $0xC0000080, %ecx
    rdmsr
    orl $0x900, %eax
    wrmsr
    movl %cr0, %eax
    orl $0x80010001, %eax
    movl %eax, %cr0
    ljmpl $0x08, $(omni_tr_lungo - omni_trampolino_inizio + 0x8000)
.code64
omni_tr_lungo:
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movq (omni_tr_stack - omni_trampolino_inizio + 0x8000), %rsp
    movq (omni_tr_indice - omni_trampolino_inizio + 0x8000), %rdi
    movq (omni_tr_ingresso - omni_trampolino_inizio + 0x8000), %rax
    jmpq *%rax
.balign 8
omni_tr_gdt:
    // bit "accessed" già impostato (0x9b/0x93): la CPU non deve scrivere nella GDT del
    // trampolino, mappata in sola lettura
    .quad 0
    .quad 0x00af9b000000ffff
    .quad 0x00cf93000000ffff
omni_tr_gdtr:
    .word 23
    .long omni_tr_gdt - omni_trampolino_inizio + 0x8000
.balign 8
omni_tr_cr3:
    .quad 0
omni_tr_stack:
    .quad 0
omni_tr_ingresso:
    .quad 0
omni_tr_indice:
    .quad 0
omni_trampolino_fine:
.text
"#,
    options(att_syntax)
);

extern "C" {
    static omni_trampolino_inizio: u8;
    static omni_trampolino_fine: u8;
    static omni_tr_cr3: u8;
    static omni_tr_stack: u8;
    static omni_tr_ingresso: u8;
    static omni_tr_indice: u8;
}

/// Indice della CPU per ciascun ID APIC (0xff = sconosciuto).
static INDICE_DA_APIC: [AtomicU8; 256] = [const { AtomicU8::new(0xff) }; 256];
static IN_LINEA: [AtomicBool; MAX_CPU] = [const { AtomicBool::new(false) }; MAX_CPU];
static NUMERO_IN_LINEA: AtomicU32 = AtomicU32::new(1);
static SMP_ATTIVO: AtomicBool = AtomicBool::new(false);

/// Indice della CPU corrente (0 = CPU di avvio).
pub fn indice() -> usize {
    let i = INDICE_DA_APIC[(tempo::id_apic() & 0xff) as usize].load(Ordering::Relaxed);
    if i == 0xff {
        0
    } else {
        i as usize
    }
}

pub fn in_linea() -> u32 {
    NUMERO_IN_LINEA.load(Ordering::Acquire)
}

pub fn cpu_in_linea(i: usize) -> bool {
    IN_LINEA.get(i).is_some_and(|c| c.load(Ordering::Acquire))
}

fn scrivi_campo(campo: &u8, valore: u64) {
    // SAFETY: il campo è dentro la copia del trampolino a 0x8000 (mappa diretta); l'offset
    // deriva dai simboli dello stesso blocco assembly
    unsafe {
        let off = campo as *const u8 as u64 - &omni_trampolino_inizio as *const u8 as u64;
        core::ptr::write_volatile(frame::virtuale(TRAMPOLINO + off) as *mut u64, valore);
    }
}

pub struct EsitoAvvio {
    pub attese: u32,
    pub in_linea: u32,
    pub tempo_ms: u64,
}

/// Avvia tutte le CPU della MADT diverse da quella corrente.
pub fn avvia(madt: &Madt) -> EsitoAvvio {
    let t0 = tempo::ns();
    let mio = tempo::id_apic();
    INDICE_DA_APIC[(mio & 0xff) as usize].store(0, Ordering::Relaxed);
    IN_LINEA[0].store(true, Ordering::Release);
    let attese = madt.cpu_abilitate.min(MAX_CPU as u32);
    if attese <= 1 {
        return EsitoAvvio { attese, in_linea: 1, tempo_ms: 0 };
    }
    // copia del trampolino e pagina d'identità (eseguibile) per il passaggio alla paginazione
    // SAFETY: simboli dello stesso blocco assembly
    let (inizio, fine) = unsafe { (&omni_trampolino_inizio as *const u8, &omni_trampolino_fine as *const u8) };
    let n = fine as usize - inizio as usize;
    assert!(n <= 4096, "trampolino troppo grande");
    // SAFETY: la pagina 0x8000 è nel primo MiB, riservato dal kernel e mai assegnato
    unsafe { core::ptr::copy_nonoverlapping(inizio, frame::virtuale(TRAMPOLINO) as *mut u8, n) };
    pagine::mappa(TRAMPOLINO, TRAMPOLINO, 0);
    let cr3 = cpu::cr3();
    assert!(cr3 < 1 << 32, "la PML4 deve stare sotto 4 GiB per il trampolino a 32 bit");
    // SAFETY: simboli dello stesso blocco assembly
    unsafe {
        scrivi_campo(&omni_tr_cr3, cr3);
        scrivi_campo(&omni_tr_ingresso, omni_ap_ingresso as extern "C" fn(u64) -> ! as usize as u64);
    }
    let vettore_sipi = (TRAMPOLINO >> 12) as u32;
    for (i, &id) in madt.id_apic.iter().take(attese as usize).enumerate() {
        if id as u32 == mio {
            continue;
        }
        let indice = NUMERO_IN_LINEA.load(Ordering::Relaxed) as usize;
        INDICE_DA_APIC[id as usize].store(indice as u8, Ordering::Relaxed);
        let stack = heap::nuovo_stack(8);
        // SAFETY: simboli dello stesso blocco assembly
        unsafe {
            scrivi_campo(&omni_tr_stack, stack);
            scrivi_campo(&omni_tr_indice, indice as u64);
        }
        tempo::invia_ipi(id as u32, 0x4500, 0); // INIT, livello asserito
        tempo::attendi_ns(10_000_000);
        for _ in 0..2 {
            tempo::invia_ipi(id as u32, 0x4600 | vettore_sipi, 0); // STARTUP
            tempo::attendi_ns(200_000);
            if IN_LINEA[indice].load(Ordering::Acquire) {
                break;
            }
        }
        let t = tempo::ns();
        while !IN_LINEA[indice].load(Ordering::Acquire) && tempo::ns() < t + 1_000_000_000 {
            core::hint::spin_loop();
        }
        if IN_LINEA[indice].load(Ordering::Acquire) {
            NUMERO_IN_LINEA.fetch_add(1, Ordering::AcqRel);
        } else {
            kprintln!("[K2] CPU con ID APIC {} (voce MADT {}) NON partita", id, i);
            INDICE_DA_APIC[id as usize].store(0xff, Ordering::Relaxed);
        }
    }
    if let Some(f) = pagine::rimuovi(TRAMPOLINO) {
        let _ = f; // pagina d'identità tolta: il primo MiB resta riservato
    }
    SMP_ATTIVO.store(true, Ordering::Release);
    EsitoAvvio { attese, in_linea: in_linea(), tempo_ms: (tempo::ns() - t0) / 1_000_000 }
}

/// Primo codice Rust di una CPU secondaria (dal trampolino, già in modalità lunga con le
/// tabelle di pagine del kernel e lo stack dedicato).
extern "C" fn omni_ap_ingresso(indice: u64) -> ! {
    let i = indice as usize;
    gdt::inizializza(i);
    idt::carica();
    tempo::attiva_apic_secondaria();
    sched::registra_cpu(i);
    kprintln!("[K2] CPU {} in linea (ID APIC {})", i, tempo::id_apic());
    IN_LINEA[i].store(true, Ordering::Release);
    cpu::attiva_interruzioni();
    loop {
        cpu::attendi(); // il timer fa girare lo scheduler di questa CPU
    }
}

// --------------------------------------------------------------------- shootdown del TLB

static RICHIESTA: [AtomicBool; MAX_CPU] = [const { AtomicBool::new(false) }; MAX_CPU];
static INDIRIZZO: AtomicU64 = AtomicU64::new(0);
static OCCUPATO: AtomicBool = AtomicBool::new(false);
pub static SHOOTDOWN: AtomicU64 = AtomicU64::new(0);

/// Esegue una richiesta d'invalidazione pendente per questa CPU. Chiamata dal gestore
/// dell'IPI e da ogni attesa attiva del kernel (anche a interruzioni disattivate): una CPU che
/// aspetta un blocco non lascia mai in attesa chi esegue lo shootdown.
pub fn servi_richieste() {
    if !SMP_ATTIVO.load(Ordering::Relaxed) {
        return;
    }
    let i = indice();
    if RICHIESTA[i].load(Ordering::Acquire) {
        cpu::invlpg(INDIRIZZO.load(Ordering::Acquire));
        RICHIESTA[i].store(false, Ordering::Release);
    }
}

/// Invalida `virt` nel TLB di tutte le CPU in linea (dopo averla rimossa dalle tabelle).
pub fn shootdown(virt: u64) {
    if !SMP_ATTIVO.load(Ordering::Acquire) || in_linea() < 2 {
        return;
    }
    while OCCUPATO.compare_exchange_weak(false, true, Ordering::Acquire, Ordering::Relaxed).is_err() {
        servi_richieste();
        core::hint::spin_loop();
    }
    let me = indice();
    INDIRIZZO.store(virt, Ordering::Release);
    for (i, r) in RICHIESTA.iter().enumerate() {
        if i != me && cpu_in_linea(i) {
            r.store(true, Ordering::Release);
        }
    }
    tempo::invia_ipi(0, 0x4000 | idt::VETTORE_SHOOTDOWN as u32, 3); // a tutte le altre CPU
    for r in RICHIESTA.iter() {
        while r.load(Ordering::Acquire) {
            core::hint::spin_loop();
        }
    }
    SHOOTDOWN.fetch_add(1, Ordering::Relaxed);
    OCCUPATO.store(false, Ordering::Release);
}
