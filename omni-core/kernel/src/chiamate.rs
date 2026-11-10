// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Smistamento delle chiamate di sistema (K3). WIP: per ora ogni chiamata risponde
//! `E_NUMERO`; le chiamate vere arrivano con il modulo dei processi.

use omni_comune::abi;

#[no_mangle]
extern "C" fn omni_chiamata_sistema(_numero: u64, _a: u64, _b: u64, _c: u64, _d: u64, _e: u64) -> i64 {
    crate::arch::anelli::CHIAMATE.fetch_add(1, core::sync::atomic::Ordering::Relaxed);
    abi::E_NUMERO
}
