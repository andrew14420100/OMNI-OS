// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Spazi d'indirizzi separati (K3-03): più istanze dello stesso programma usano lo stesso
//! indirizzo virtuale per una variabile, ognuna con il proprio valore.
#![no_std]
#![no_main]

use omni_std::{cedi, stampa};

omni_std::principale!(principale);

static mut VALORE: u64 = 0;

fn principale(argomento: u64) -> i64 {
    let p = &raw mut VALORE;
    // SAFETY: variabile del programma, un solo thread
    unsafe { p.write_volatile(argomento) };
    let mut invariata = true;
    for _ in 0..300 {
        cedi();
        // SAFETY: come sopra
        if unsafe { p.read_volatile() } != argomento {
            invariata = false;
        }
    }
    // SAFETY: come sopra
    let v = unsafe { p.read_volatile() };
    stampa!("variabile a {:#x} = {} dopo 300 cessioni della CPU ({})", p as u64, v, if invariata { "invariata" } else { "ALTERATA" });
    if invariata {
        argomento as i64
    } else {
        1
    }
}
