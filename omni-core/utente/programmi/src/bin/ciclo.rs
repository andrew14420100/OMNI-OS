// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Calcolo senza fine, senza chiamate di sistema (K3-06): solo la prelazione del timer
//! restituisce la CPU agli altri.
#![no_std]
#![no_main]

use omni_std::{cpu, stampa};

omni_std::principale!(principale);

fn principale(argomento: u64) -> i64 {
    stampa!("ciclo {}: calcolo senza fine sulla CPU {}", argomento, cpu());
    let mut x = argomento;
    loop {
        x = core::hint::black_box(x.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407));
    }
}
