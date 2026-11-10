// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Spegnimento e riavvio tramite ACPI (K2-07, K2-08):
//! - spegnimento: SLP_TYPa/b dal pacchetto `\_S5` della DSDT, scritti con SLP_EN nei
//!   registri PM1a/PM1b_CNT indicati dalla FADT (ACPI 6.5, 4.8.3 e 7.4.2);
//! - riavvio: registro di reset della FADT; in mancanza, comando 0xFE al controller 8042.
//!
//! Un byte della CMOS (registro 0x7D) ricorda che il riavvio è stato chiesto dal kernel, così
//! l'avvio successivo può riconoscerlo (prova automatica del riavvio).

use crate::arch::cpu::{inb, outb, outw};
use crate::tempo;
use omni_comune::acpi::Fadt;

const REGISTRO_CMOS: u8 = 0x7d;
const SEGNO_RIAVVIO: u8 = 0x4b;

fn cmos_leggi(r: u8) -> u8 {
    outb(0x70, 0x80 | r); // bit 7: NMI disattivate durante l'accesso
    inb(0x71)
}

fn cmos_scrivi(r: u8, v: u8) {
    outb(0x70, 0x80 | r);
    outb(0x71, v);
}

/// true se questo avvio segue un riavvio chiesto dal kernel (il segno viene cancellato).
pub fn dopo_riavvio() -> bool {
    let s = cmos_leggi(REGISTRO_CMOS) == SEGNO_RIAVVIO;
    if s {
        cmos_scrivi(REGISTRO_CMOS, 0);
    }
    s
}

pub struct InfoPotenza {
    pub fadt: Fadt,
    pub s5: Option<(u8, u8)>,
}

/// Spegne la macchina. Ritorna solo se lo spegnimento non è avvenuto entro 3 secondi.
pub fn spegni(p: &InfoPotenza) -> &'static str {
    let Some((a, b)) = p.s5 else { return "pacchetto \\_S5 assente" };
    if p.fadt.pm1a_cnt == 0 {
        return "registro PM1a_CNT assente";
    }
    outw(p.fadt.pm1a_cnt as u16, ((a as u16) << 10) | (1 << 13));
    if p.fadt.pm1b_cnt != 0 {
        outw(p.fadt.pm1b_cnt as u16, ((b as u16) << 10) | (1 << 13));
    }
    tempo::attendi_ns(3_000_000_000);
    "la macchina non si è spenta"
}

/// Riavvia la macchina. Ritorna solo se il riavvio non è avvenuto.
pub fn riavvia(p: &InfoPotenza) -> &'static str {
    cmos_scrivi(REGISTRO_CMOS, SEGNO_RIAVVIO);
    if let Some((1, indirizzo, valore)) = p.fadt.reset {
        outb(indirizzo as u16, valore);
        tempo::attendi_ns(500_000_000);
    }
    // ripiego: impulso di reset dal controller della tastiera
    for _ in 0..1000 {
        if inb(0x64) & 2 == 0 {
            break;
        }
    }
    outb(0x64, 0xfe);
    tempo::attendi_ns(2_000_000_000);
    cmos_scrivi(REGISTRO_CMOS, 0);
    "la macchina non si è riavviata"
}
