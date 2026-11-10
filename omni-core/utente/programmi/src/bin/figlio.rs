// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Processo figlio avviato da `genitore` (K3-08): restituisce 2 × argomento + 1.
#![no_std]
#![no_main]

use omni_std::{pid, stampa};

omni_std::principale!(principale);

fn principale(argomento: u64) -> i64 {
    stampa!("figlio: processo {} con argomento {}", pid(), argomento);
    2 * argomento as i64 + 1
}
