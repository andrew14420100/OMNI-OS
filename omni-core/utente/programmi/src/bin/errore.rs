// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Errori deliberati (K3-05): ogni caso deve terminare soltanto questo processo, con
//! l'eccezione attesa, senza toccare il kernel né gli altri processi. Il caso 11 verifica
//! invece che il kernel rifiuti con un errore gli argomenti non validi.
#![no_std]
#![no_main]

use core::arch::asm;
use omni_std::{abi, chiamata, stampa};

omni_std::principale!(principale);

static mut CODICE_IN_DATI: [u8; 16] = [0xc3; 16]; // `ret`, ma in una pagina non eseguibile

#[allow(unconditional_recursion)]
fn ricorsione(n: u64) -> u64 {
    let spazio = core::hint::black_box([n; 64]);
    ricorsione(spazio[(n % 64) as usize] + 1) + 1
}

fn descrizione(caso: u64) -> &'static str {
    match caso {
        1 => "lettura della memoria del kernel",
        2 => "scrittura nella mappa diretta del kernel",
        3 => "istruzione privilegiata cli",
        4 => "istruzione privilegiata hlt",
        5 => "puntatore nullo",
        6 => "istruzione non valida (ud2)",
        7 => "divisione per zero",
        8 => "scrittura nel proprio codice (W^X)",
        9 => "esecuzione di dati (NX)",
        10 => "overflow dello stack",
        11 => "argomenti non validi alle chiamate di sistema",
        12 => "porta di I/O (uscita di QEMU)",
        13 => "lettura di CR4",
        _ => "caso sconosciuto",
    }
}

fn principale(caso: u64) -> i64 {
    stampa!("errore {}: {}", caso, descrizione(caso));
    // SAFETY: ogni caso è un errore deliberato che il kernel deve intercettare (o rifiutare)
    unsafe {
        match caso {
            1 => {
                let v = (0xffff_ffff_8000_0000u64 as *const u64).read_volatile();
                stampa!("letto {:#x}", v);
            }
            2 => (0xffff_8000_0010_0000u64 as *mut u64).write_volatile(1),
            3 => asm!("cli"),
            4 => asm!("hlt"),
            5 => {
                let v: u64;
                asm!("mov {}, qword ptr [0]", out(reg) v);
                stampa!("letto {:#x}", v);
            }
            6 => asm!("ud2"),
            7 => asm!("div {d}", d = in(reg) 0u64, inout("rax") 1u64 => _, inout("rdx") 0u64 => _),
            8 => (principale as fn(u64) -> i64 as *const u8 as *mut u8).write_volatile(0x90),
            9 => {
                let f: extern "C" fn() = core::mem::transmute((&raw const CODICE_IN_DATI) as *const u8);
                f();
            }
            10 => {
                stampa!("{}", ricorsione(1));
            }
            11 => {
                let kernel = chiamata(abi::SC_SCRIVI, 0xffff_ffff_8000_0000, 16, 0, 0, 0);
                let non_mappato = chiamata(abi::SC_SCRIVI, 0x5000_0000, 16, 0, 0, 0);
                let traboccamento = chiamata(abi::SC_SCRIVI, 0x40_0000, u64::MAX, 0, 0, 0);
                let numero = chiamata(999, 0, 0, 0, 0, 0);
                let thread = chiamata(abi::SC_THREAD, 0xffff_ffff_8000_0000, 0x7000_0000, 0, 0, 0);
                let attesa = chiamata(abi::SC_ATTENDI, 1, 0, 0, 0, 0);
                stampa!(
                    "rifiuti: buffer nel kernel {}, buffer non mappato {}, lunghezza enorme {}, numero 999 {}, thread nel kernel {}, attesa di un non figlio {}",
                    kernel,
                    non_mappato,
                    traboccamento,
                    numero,
                    thread,
                    attesa
                );
                let ok = kernel == abi::E_INDIRIZZO
                    && non_mappato == abi::E_INDIRIZZO
                    && traboccamento == abi::E_INDIRIZZO
                    && numero == abi::E_NUMERO
                    && thread == abi::E_INDIRIZZO
                    && attesa == abi::E_NON_TROVATO;
                return if ok { 0 } else { 1 };
            }
            12 => asm!("out dx, al", in("dx") 0xf4u16, in("al") 0x11u8),
            13 => {
                let v: u64;
                asm!("mov {}, cr4", out(reg) v);
                stampa!("CR4 = {:#x}", v);
            }
            _ => return 2,
        }
    }
    stampa!("errore {} NON intercettato", caso);
    99
}
