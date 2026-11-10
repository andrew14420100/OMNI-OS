// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Processi che creano processi e thread (K3-08): figli che terminano bene, con un errore o
//! per volontà del genitore; thread che condividono la memoria del processo.
#![no_std]
#![no_main]

extern crate alloc;

use alloc::vec::Vec;
use core::sync::atomic::{AtomicU64, Ordering};
use omni_std::{abi, attendi, attendi_thread, avvia, cedi, cpu, stampa, termina, thread};

omni_std::principale!(principale);

static CONTATORE: AtomicU64 = AtomicU64::new(0);
static CPU_USATE: AtomicU64 = AtomicU64::new(0);
const THREAD: u64 = 4;
const INCREMENTI: u64 = 50_000;

fn principale(_argomento: u64) -> i64 {
    let mut ok = true;

    let f = avvia("figlio", 5, abi::PRIORITA_NORMALE);
    let c = f.map(attendi).unwrap_or(-1);
    stampa!("genitore: figlio {:?} terminato con codice {} (atteso 11)", f, c);
    ok &= c == 11;

    let e = avvia("errore", 6, abi::PRIORITA_NORMALE);
    let c = e.map(attendi).unwrap_or(-1);
    stampa!("genitore: figlio con ud2 {:?} terminato con codice {} (atteso {})", e, c, abi::CODICE_ECCEZIONE - 6);
    ok &= c == abi::CODICE_ECCEZIONE - 6;

    let g = avvia("ciclo", 7, abi::PRIORITA_BASSA);
    for _ in 0..20 {
        cedi();
    }
    let t = g.map(termina).unwrap_or(-1);
    let c = g.map(attendi).unwrap_or(-1);
    stampa!("genitore: ciclo {:?} terminato dal genitore ({}) con codice {} (atteso {})", g, t, c, abi::CODICE_TERMINATO);
    ok &= t == 0 && c == abi::CODICE_TERMINATO;

    let n = avvia("inesistente", 0, abi::PRIORITA_NORMALE);
    stampa!("genitore: programma inesistente: {:?}", n);
    ok &= n == Err(abi::E_NON_TROVATO);

    let id: Vec<_> = (0..THREAD)
        .map(|_| {
            thread(|| {
                for i in 0..INCREMENTI {
                    CONTATORE.fetch_add(1, Ordering::Relaxed);
                    if i % 5000 == 0 {
                        CPU_USATE.fetch_or(1 << cpu(), Ordering::Relaxed);
                        cedi();
                    }
                }
            })
        })
        .collect();
    let creati = id.iter().filter(|t| t.is_ok()).count() as u64;
    for t in id.iter().flatten() {
        attendi_thread(*t);
    }
    let totale = CONTATORE.load(Ordering::Relaxed);
    stampa!(
        "genitore: {} thread nello stesso spazio: {} incrementi atomici (attesi {}), CPU usate {:#b}",
        creati,
        totale,
        THREAD * INCREMENTI,
        CPU_USATE.load(Ordering::Relaxed)
    );
    ok &= creati == THREAD && totale == THREAD * INCREMENTI;

    if ok {
        0
    } else {
        1
    }
}
