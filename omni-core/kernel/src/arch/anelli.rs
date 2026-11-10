// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Passaggi fra ring 0 e ring 3 (K3).
//!
//! - `syscall`/`sysret` (Intel SDM vol. 3, 5.8.8; AMD APM vol. 2, 6.1): STAR con i selettori,
//!   LSTAR con l'ingresso, SFMASK che azzera IF, TF, DF, NT e AC all'ingresso.
//! - Dati per CPU raggiunti con `swapgs` solo nel prologo della chiamata: il kernel lavora
//!   sempre con la base GS "utente" (zero) e KERNEL_GS_BASE punta ai dati della CPU; così lo
//!   stato di GS è identico in ogni punto del kernel (anche dopo un cambio di thread).
//! - Stack: ogni thread ha il proprio stack del kernel; lo scheduler ne scrive la cima in
//!   RSP0 del TSS (interruzioni da ring 3) e nei dati per CPU (chiamate di sistema).
//! - SMEP/SMAP (CR4.20/21), se la CPU li offre: il kernel non esegue mai codice utente e
//!   tocca la memoria utente solo dentro `con_accesso_utente` (`stac`/`clac`).
// K3-WIP: modulo non ancora collegato (tolto quando lo usano i processi)
#![allow(dead_code)]

use super::{cpu, gdt};
use core::arch::global_asm;
use core::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use omni_comune::acpi::MAX_CPU;

const EFER: u32 = 0xC000_0080;
const STAR: u32 = 0xC000_0081;
const LSTAR: u32 = 0xC000_0082;
const SFMASK: u32 = 0xC000_0084;
const KERNEL_GS_BASE: u32 = 0xC000_0102;
const CR4_SMEP: u64 = 1 << 20;
const CR4_SMAP: u64 = 1 << 21;

/// Dati per CPU letti dal prologo della chiamata di sistema (offset fissi nell'assembly).
#[repr(C, align(64))]
pub struct DatiAnello {
    /// cima dello stack del kernel del thread corrente
    pub pila_kernel: u64,
    /// RSP utente salvato durante il prologo
    pub pila_utente: u64,
}

static mut DATI: [DatiAnello; MAX_CPU] = [const { DatiAnello { pila_kernel: 0, pila_utente: 0 } }; MAX_CPU];

pub static SMEP: AtomicBool = AtomicBool::new(false);
pub static SMAP: AtomicBool = AtomicBool::new(false);
/// CR4 di ciascuna CPU dopo l'inizializzazione (per la prova K3-09).
pub static CR4_CPU: [AtomicU64; MAX_CPU] = [const { AtomicU64::new(0) }; MAX_CPU];
pub static CHIAMATE: AtomicU64 = AtomicU64::new(0);

global_asm!(
    r#"
.global omni_ingresso_chiamata
// ingresso di `syscall`: rcx = rip utente, r11 = rflags utente, rsp = stack utente,
// interruzioni disattivate da SFMASK
omni_ingresso_chiamata:
    swapgs
    mov gs:[8], rsp
    mov rsp, gs:[0]
    push qword ptr gs:[8]
    swapgs
    push rcx
    push r11
    push rdi
    push rsi
    push rdx
    push r10
    push r8
    push r9
    push rax
    sti
    mov r9, r8
    mov r8, r10
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, rax
    cld
    call omni_chiamata_sistema
    cli
    add rsp, 8
    pop r9
    pop r8
    pop r10
    pop rdx
    pop rsi
    pop rdi
    pop r11
    pop rcx
    pop rsp
    sysretq

.global omni_entra_utente
// primo ingresso in ring 3: rdi = rip, rsi = rsp, rdx = argomento (in rdi del programma)
omni_entra_utente:
    cli
    push {ds_utente}
    push rsi
    push 0x202
    push {cs_utente}
    push rdi
    mov rdi, rdx
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor ebp, ebp
    xor r8d, r8d
    xor r9d, r9d
    xor r10d, r10d
    xor r11d, r11d
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
    iretq
"#,
    ds_utente = const gdt::DATI_UTENTE as u64,
    cs_utente = const gdt::CODICE_UTENTE as u64,
);

extern "C" {
    fn omni_ingresso_chiamata();
    fn omni_entra_utente(rip: u64, rsp: u64, argomento: u64) -> !;
}

/// Prepara `syscall`/`sysret`, i dati per CPU e SMEP/SMAP sulla CPU `indice` (su ogni CPU,
/// dopo `gdt::inizializza`).
pub fn inizializza_cpu(indice: usize) {
    let (_, ebx, _, _) = cpu::cpuid(7, 0);
    let smep = ebx & (1 << 7) != 0;
    let smap = ebx & (1 << 20) != 0;
    if indice == 0 {
        SMEP.store(smep, Ordering::Relaxed);
        SMAP.store(smap, Ordering::Relaxed);
    }
    // SAFETY: MSR architetturali di x86-64. STAR: syscall carica CS=0x08/SS=0x10; sysret
    // carica SS=0x18|3 e CS=0x20|3 (base 0x10 + 8 e + 16), come nella GDT. SFMASK azzera
    // TF(8), IF(9), DF(10), NT(14), AC(18). KERNEL_GS_BASE punta ai dati di questa CPU,
    // usati solo dal prologo di omni_ingresso_chiamata
    unsafe {
        cpu::scrivi_msr(EFER, cpu::leggi_msr(EFER) | 1); // SCE
        cpu::scrivi_msr(STAR, ((gdt::CODICE_KERNEL as u64) << 32) | (0x10u64 << 48));
        cpu::scrivi_msr(LSTAR, omni_ingresso_chiamata as unsafe extern "C" fn() as usize as u64);
        cpu::scrivi_msr(SFMASK, (1 << 8) | (1 << 9) | (1 << 10) | (1 << 14) | (1 << 18));
        cpu::scrivi_msr(KERNEL_GS_BASE, (&raw const DATI[indice]) as u64);
        let mut cr4 = cpu::cr4();
        if smep {
            cr4 |= CR4_SMEP;
        }
        if smap {
            cr4 |= CR4_SMAP;
        }
        cpu::imposta_cr4(cr4);
    }
    CR4_CPU[indice].store(cpu::cr4(), Ordering::Relaxed);
}

/// Cima dello stack del kernel del thread che sta per girare sulla CPU `indice`.
pub fn imposta_pila_kernel(indice: usize, cima: u64) {
    gdt::imposta_rsp0(indice, cima);
    // SAFETY: scritto solo dalla CPU stessa a interruzioni disattivate (scheduler), letto solo
    // dal prologo della chiamata di sistema della stessa CPU
    unsafe { core::ptr::write_volatile(&raw mut DATI[indice].pila_kernel, cima) };
}

/// Passa in ring 3 all'indirizzo `rip` con lo stack `rsp`; non ritorna.
pub fn entra(rip: u64, rsp: u64, argomento: u64) -> ! {
    // SAFETY: rip e rsp appartengono allo spazio utente del processo (verificati dal
    // caricatore); RSP0 e i dati per CPU puntano già allo stack del kernel di questo thread
    unsafe { omni_entra_utente(rip, rsp, argomento) }
}

/// Esegue `f` con l'accesso alla memoria utente consentito (SMAP sospeso con `stac`).
pub fn con_accesso_utente<R>(f: impl FnOnce() -> R) -> R {
    let smap = SMAP.load(Ordering::Relaxed);
    if smap {
        // SAFETY: stac esiste se la CPU offre SMAP; consente gli accessi fino a clac
        unsafe { core::arch::asm!("stac", options(nomem, nostack)) };
    }
    let r = f();
    if smap {
        // SAFETY: come sopra
        unsafe { core::arch::asm!("clac", options(nomem, nostack)) };
    }
    r
}
