// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Istruzioni privilegiate x86-64 usate dal kernel. Ogni funzione è sicura da chiamare in
//! ring 0; le precondizioni sono documentate dove servono.

use core::arch::asm;

pub fn outb(porta: u16, v: u8) {
    // SAFETY: accesso a porte I/O in ring 0; le porte usate sono documentate dai chiamanti
    unsafe { asm!("out dx, al", in("dx") porta, in("al") v, options(nomem, nostack, preserves_flags)) };
}

pub fn outw(porta: u16, v: u16) {
    // SAFETY: come outb (registri ACPI PM1x_CNT a 16 bit)
    unsafe { asm!("out dx, ax", in("dx") porta, in("ax") v, options(nomem, nostack, preserves_flags)) };
}

pub fn inb(porta: u16) -> u8 {
    let v: u8;
    // SAFETY: come outb
    unsafe { asm!("in al, dx", out("al") v, in("dx") porta, options(nomem, nostack, preserves_flags)) };
    v
}

pub fn interruzioni_attive() -> bool {
    let f: u64;
    // SAFETY: lettura di RFLAGS
    unsafe { asm!("pushfq", "pop {}", out(reg) f, options(nomem, preserves_flags)) };
    f & (1 << 9) != 0
}

pub fn disattiva_interruzioni() {
    // SAFETY: cli in ring 0
    unsafe { asm!("cli", options(nomem, nostack)) };
}

pub fn attiva_interruzioni() {
    // SAFETY: sti in ring 0; chiamata solo dopo l'installazione della IDT
    unsafe { asm!("sti", options(nomem, nostack)) };
}

/// Attende la prossima interruzione (o ferma la CPU se le interruzioni sono disattivate).
pub fn attendi() {
    // SAFETY: hlt in ring 0
    unsafe { asm!("hlt", options(nomem, nostack, preserves_flags)) };
}

pub fn ferma() -> ! {
    loop {
        disattiva_interruzioni();
        attendi();
    }
}

pub fn cr2() -> u64 {
    let v: u64;
    // SAFETY: lettura di CR2
    unsafe { asm!("mov {}, cr2", out(reg) v, options(nomem, nostack, preserves_flags)) };
    v
}

pub fn cr3() -> u64 {
    let v: u64;
    // SAFETY: lettura di CR3
    unsafe { asm!("mov {}, cr3", out(reg) v, options(nomem, nostack, preserves_flags)) };
    v
}

/// # Safety
/// `pml4` deve essere una tabella valida che mappa il codice, lo stack e i dati in uso.
pub unsafe fn imposta_cr3(pml4: u64) {
    // SAFETY: garantito dal chiamante
    unsafe { asm!("mov cr3, {}", in(reg) pml4, options(nostack, preserves_flags)) };
}

pub fn invlpg(ind: u64) {
    // SAFETY: invalida una voce del TLB, nessun effetto sulla memoria
    unsafe { asm!("invlpg [{}]", in(reg) ind, options(nostack, preserves_flags)) };
}

/// # Safety
/// `msr` deve esistere su questa CPU e il valore deve essere valido per esso.
#[allow(dead_code)] // K3-WIP: collegato nei passi successivi di K3
pub unsafe fn scrivi_msr(msr: u32, v: u64) {
    // SAFETY: garantito dal chiamante
    unsafe { asm!("wrmsr", in("ecx") msr, in("eax") v as u32, in("edx") (v >> 32) as u32, options(nostack, preserves_flags)) };
}

#[allow(dead_code)] // K3-WIP: collegato nei passi successivi di K3
pub fn leggi_msr(msr: u32) -> u64 {
    let (a, d): (u32, u32);
    // SAFETY: usata solo per MSR architetturali presenti su ogni CPU x86-64 (EFER, STAR, ...)
    unsafe { asm!("rdmsr", in("ecx") msr, out("eax") a, out("edx") d, options(nomem, nostack, preserves_flags)) };
    ((d as u64) << 32) | a as u64
}

#[allow(dead_code)] // K3-WIP: collegato nei passi successivi di K3
pub fn cr4() -> u64 {
    let v: u64;
    // SAFETY: lettura di CR4
    unsafe { asm!("mov {}, cr4", out(reg) v, options(nomem, nostack, preserves_flags)) };
    v
}

/// # Safety
/// Il valore deve attivare solo funzioni supportate dalla CPU e compatibili con lo stato.
#[allow(dead_code)] // K3-WIP: collegato nei passi successivi di K3
pub unsafe fn imposta_cr4(v: u64) {
    // SAFETY: garantito dal chiamante
    unsafe { asm!("mov cr4, {}", in(reg) v, options(nostack, preserves_flags)) };
}

/// CPUID (foglia, sottofoglia) → (eax, ebx, ecx, edx).
#[allow(dead_code)] // K3-WIP: collegato nei passi successivi di K3
pub fn cpuid(foglia: u32, sotto: u32) -> (u32, u32, u32, u32) {
    let r = core::arch::x86_64::__cpuid_count(foglia, sotto);
    (r.eax, r.ebx, r.ecx, r.edx)
}

/// Uscita da QEMU tramite il dispositivo isa-debug-exit (solo nelle build di prova).
#[cfg(feature = "ktest")]
pub fn esci_qemu(codice: u8) -> ! {
    outb(0xf4, codice);
    ferma()
}
