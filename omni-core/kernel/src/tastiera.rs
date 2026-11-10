// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Tastiera PS/2 (controller i8042, codici di scansione set 1 con traduzione attiva, come
//! fornito dal firmware). Solo lettere, cifre, spazio, Invio e Backspace in K1.

use crate::arch::cpu::inb;
use crate::sync::Blocco;

const MAX: usize = 64;

pub struct Riga {
    pub testo: [u8; MAX],
    pub lunghezza: usize,
    pub inviate: u32,
    pub ultima_inviata: [u8; MAX],
    pub lunghezza_inviata: usize,
}

pub static RIGA: Blocco<Riga> = Blocco::new(Riga { testo: [0; MAX], lunghezza: 0, inviate: 0, ultima_inviata: [0; MAX], lunghezza_inviata: 0 });

fn carattere(codice: u8) -> Option<u8> {
    const RIGA1: &[u8] = b"qwertyuiop";
    const RIGA2: &[u8] = b"asdfghjkl";
    const RIGA3: &[u8] = b"zxcvbnm";
    match codice {
        0x02..=0x0a => Some(b'1' + codice - 0x02),
        0x0b => Some(b'0'),
        0x10..=0x19 => Some(RIGA1[(codice - 0x10) as usize]),
        0x1e..=0x26 => Some(RIGA2[(codice - 0x1e) as usize]),
        0x2c..=0x32 => Some(RIGA3[(codice - 0x2c) as usize]),
        0x39 => Some(b' '),
        _ => None,
    }
}

/// Chiamata dal gestore della IRQ 1.
pub fn interruzione() {
    let codice = inb(0x60);
    if codice & 0x80 != 0 {
        return; // rilascio del tasto
    }
    let mut r = RIGA.prendi();
    match codice {
        0x1c => {
            // Invio: la riga viene "inviata"
            let n = r.lunghezza;
            let t = r.testo;
            r.ultima_inviata = t;
            r.lunghezza_inviata = n;
            r.inviate += 1;
            r.lunghezza = 0;
        }
        0x0e => r.lunghezza = r.lunghezza.saturating_sub(1),
        c => {
            if let Some(ch) = carattere(c) {
                if r.lunghezza < MAX {
                    let n = r.lunghezza;
                    r.testo[n] = ch;
                    r.lunghezza += 1;
                }
            }
        }
    }
}
