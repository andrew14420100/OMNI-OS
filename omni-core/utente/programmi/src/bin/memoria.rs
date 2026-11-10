// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Memoria del processo (K3-04): Vec, Box e String sopra l'allocatore di omni-std.
#![no_std]
#![no_main]

extern crate alloc;

use alloc::boxed::Box;
use alloc::string::String;
use alloc::vec::Vec;
use core::fmt::Write;
use omni_std::{mappa, stampa};

omni_std::principale!(principale);

fn principale(argomento: u64) -> i64 {
    let n = 1usize << 20;
    let mut v: Vec<u8> = Vec::with_capacity(n);
    for i in 0..n {
        v.push((i * 7 + argomento as usize) as u8);
    }
    let ok_vec = v.iter().enumerate().all(|(i, &b)| b == (i * 7 + argomento as usize) as u8);
    let b = Box::new([0x5au8; 4096]);
    let ok_box = b.iter().all(|&x| x == 0x5a);
    let mut s = String::new();
    for i in 0..100 {
        let _ = write!(s, "{i} ");
    }
    let ok_string = s.len() == 290;
    let eccessiva = mappa(1 << 40);
    let ok_rifiuto = eccessiva.is_err();
    stampa!(
        "memoria: Vec di {} KiB scritto e verificato ({}), Box di 4 KiB ({}), String di {} byte ({}), richiesta di 4 PiB rifiutata ({:?})",
        n >> 10,
        ok_vec,
        ok_box,
        s.len(),
        ok_string,
        eccessiva.err()
    );
    if ok_vec && ok_box && ok_string && ok_rifiuto {
        0
    } else {
        1
    }
}
