// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Istruzioni privilegiate x86-64 usate dal kernel. Ogni funzione è sicura da chiamare in
//! ring 0; le precondizioni sono documentate dove servono.

use core::arch::asm;

pub fn outb(porta: u16, v: u8) {
    // SAFETY: accesso a porte I/O in ring 0; le porte usate sono documentate dai chiamanti
    unsafe { asm!("out dx, al", in("dx") porta, in("al") v, options(nomem, nostack, preserves_flags)) };
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

/// Uscita da QEMU tramite il dispositivo isa-debug-exit (solo nelle build di prova).
#[cfg(feature = "ktest")]
pub fn esci_qemu(codice: u8) -> ! {
    outb(0xf4, codice);
    ferma()
}
