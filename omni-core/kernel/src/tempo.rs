// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Tempo e interruzioni del sistema:
//! - PIC 8259 rimappato e mascherato (si usano APIC e IOAPIC);
//! - HPET come orologio di riferimento (IA-PC HPET 1.0a);
//! - APIC locale in modalità xAPIC con timer periodico calibrato sull'HPET (100 Hz);
//! - IOAPIC per la IRQ della tastiera (Intel 82093AA).

use crate::arch::cpu::{inb, outb};
use crate::arch::idt;
use crate::mem::pagine;
use core::sync::atomic::{AtomicU64, Ordering};
use omni_comune::acpi::Madt;

pub const FREQUENZA_HZ: u64 = 100;

static APIC: AtomicU64 = AtomicU64::new(0);
static HPET: AtomicU64 = AtomicU64::new(0);
static HPET_FEMTOSECONDI: AtomicU64 = AtomicU64::new(0);
static IOAPIC: AtomicU64 = AtomicU64::new(0);
pub static TICK: AtomicU64 = AtomicU64::new(0);

fn leggi32(base: u64, reg: u64) -> u32 {
    // SAFETY: registro di un dispositivo mappato non in cache da `pagine::mappa_dispositivo`
    unsafe { core::ptr::read_volatile((base + reg) as *const u32) }
}
fn scrivi32(base: u64, reg: u64, v: u32) {
    // SAFETY: come sopra
    unsafe { core::ptr::write_volatile((base + reg) as *mut u32, v) }
}
fn leggi64(base: u64, reg: u64) -> u64 {
    // SAFETY: come sopra (registri HPET a 64 bit, allineati)
    unsafe { core::ptr::read_volatile((base + reg) as *const u64) }
}
fn scrivi64(base: u64, reg: u64, v: u64) {
    // SAFETY: come sopra
    unsafe { core::ptr::write_volatile((base + reg) as *mut u64, v) }
}

/// Rimappa il PIC a 0x20-0x2F (le interruzioni spurie non cadono sulle eccezioni) e lo
/// maschera completamente.
pub fn disattiva_pic() {
    outb(0x20, 0x11);
    outb(0xa0, 0x11);
    outb(0x21, 0x20);
    outb(0xa1, 0x28);
    outb(0x21, 4);
    outb(0xa1, 2);
    outb(0x21, 1);
    outb(0xa1, 1);
    outb(0x21, 0xff);
    outb(0xa1, 0xff);
}

pub fn inizializza_hpet(fisico: u64) -> Result<u64, &'static str> {
    if fisico == 0 {
        return Err("HPET assente");
    }
    let b = pagine::mappa_dispositivo(fisico, 0x400);
    let cap = leggi64(b, 0);
    let periodo = cap >> 32;
    if periodo == 0 || periodo > 100_000_000 {
        return Err("periodo HPET non valido");
    }
    scrivi64(b, 0x10, leggi64(b, 0x10) | 1); // avvio del contatore principale
    HPET.store(b, Ordering::Relaxed);
    HPET_FEMTOSECONDI.store(periodo, Ordering::Relaxed);
    Ok(1_000_000_000_000_000 / periodo)
}

/// Nanosecondi dall'avvio dell'HPET.
pub fn ns() -> u64 {
    let b = HPET.load(Ordering::Relaxed);
    if b == 0 {
        return 0;
    }
    (leggi64(b, 0xf0) as u128 * HPET_FEMTOSECONDI.load(Ordering::Relaxed) as u128 / 1_000_000) as u64
}

pub fn attendi_ns(n: u64) {
    let fine = ns() + n;
    while ns() < fine {
        core::hint::spin_loop();
    }
}

pub struct InfoApic {
    pub id: u32,
    pub versione: u32,
    pub conteggi_per_tick: u32,
}

/// APIC locale e timer periodico a FREQUENZA_HZ, calibrato con l'HPET.
pub fn inizializza_apic(madt: &Madt) -> InfoApic {
    let b = pagine::mappa_dispositivo(madt.apic_locale, 0x1000);
    APIC.store(b, Ordering::Relaxed);
    scrivi32(b, 0x80, 0); // priorità dei compiti: accetta tutto
    scrivi32(b, 0xf0, 0x100 | idt::VETTORE_SPURIO as u32); // abilita, vettore spurio
    scrivi32(b, 0x3e0, 0x3); // divisore 16
    scrivi32(b, 0x320, 1 << 16); // timer mascherato durante la calibrazione
    scrivi32(b, 0x380, u32::MAX);
    attendi_ns(10_000_000);
    let trascorsi = u32::MAX - leggi32(b, 0x390);
    let per_tick = (trascorsi as u64 * (100 / FREQUENZA_HZ)) as u32;
    scrivi32(b, 0x320, idt::VETTORE_TIMER as u32 | (1 << 17)); // periodico
    scrivi32(b, 0x380, per_tick.max(1));
    CONTEGGI_PER_TICK.store(per_tick.max(1) as u64, Ordering::Relaxed);
    InfoApic { id: leggi32(b, 0x20) >> 24, versione: leggi32(b, 0x30) & 0xff, conteggi_per_tick: per_tick }
}

static CONTEGGI_PER_TICK: AtomicU64 = AtomicU64::new(0);

/// APIC locale di una CPU secondaria: stessi registri (indirizzo uguale per tutte le CPU),
/// timer periodico con la calibrazione fatta dalla CPU di avvio (stessa frequenza del bus).
pub fn attiva_apic_secondaria() {
    let b = APIC.load(Ordering::Relaxed);
    scrivi32(b, 0x80, 0);
    scrivi32(b, 0xf0, 0x100 | idt::VETTORE_SPURIO as u32);
    scrivi32(b, 0x3e0, 0x3);
    scrivi32(b, 0x320, idt::VETTORE_TIMER as u32 | (1 << 17));
    scrivi32(b, 0x380, CONTEGGI_PER_TICK.load(Ordering::Relaxed) as u32);
}

/// ID APIC della CPU che esegue (0 prima dell'inizializzazione dell'APIC).
pub fn id_apic() -> u32 {
    let b = APIC.load(Ordering::Relaxed);
    if b == 0 {
        return 0;
    }
    leggi32(b, 0x20) >> 24
}

/// Invia un'interruzione fra processori (ICR, Intel SDM vol. 3, 11.6). `destinazione` è un ID
/// APIC; `abbreviazione` 0 = nessuna, 3 = tutte le CPU tranne questa.
pub fn invia_ipi(destinazione: u32, basso: u32, abbreviazione: u32) {
    let b = APIC.load(Ordering::Relaxed);
    while leggi32(b, 0x300) & (1 << 12) != 0 {
        core::hint::spin_loop(); // consegna precedente in corso
    }
    scrivi32(b, 0x310, destinazione << 24);
    scrivi32(b, 0x300, basso | (abbreviazione << 18));
    while leggi32(b, 0x300) & (1 << 12) != 0 {
        core::hint::spin_loop();
    }
}

pub fn fine_interruzione() {
    let b = APIC.load(Ordering::Relaxed);
    if b != 0 {
        scrivi32(b, 0xb0, 0);
    }
}

/// Instrada una IRQ ISA verso un vettore della CPU di avvio tramite l'IOAPIC.
pub fn instrada_irq(madt: &Madt, irq: usize, vettore: u8, apic_id: u32) -> u32 {
    let mut b = IOAPIC.load(Ordering::Relaxed);
    if b == 0 {
        b = pagine::mappa_dispositivo(madt.ioapic, 0x20);
        IOAPIC.store(b, Ordering::Relaxed);
    }
    let gsi = madt.gsi_irq[irq];
    let ingresso = gsi - madt.ioapic_gsi_base;
    let flag = madt.flag_irq[irq];
    let mut basso = vettore as u32;
    if flag & 0b11 == 0b11 {
        basso |= 1 << 13; // attivo basso
    }
    if (flag >> 2) & 0b11 == 0b11 {
        basso |= 1 << 15; // a livello
    }
    scrivi32(b, 0, 0x10 + 2 * ingresso + 1);
    scrivi32(b, 0x10, apic_id << 24);
    scrivi32(b, 0, 0x10 + 2 * ingresso);
    scrivi32(b, 0x10, basso);
    gsi
}

pub fn tick() {
    TICK.fetch_add(1, Ordering::Relaxed);
}

/// Svuota il buffer del controller PS/2 (byte rimasti dal firmware).
pub fn svuota_ps2() {
    for _ in 0..32 {
        if inb(0x64) & 1 == 0 {
            break;
        }
        let _ = inb(0x60);
    }
}
