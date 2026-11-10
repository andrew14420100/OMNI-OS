// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Primo programma utente (K3-02): stampa da ring 3 e verifica che la chiamata di sistema
//! conservi i registri.
#![no_std]
#![no_main]

use core::arch::asm;
use omni_std::{abi, cpu, pid, stampa};

omni_std::principale!(principale);

fn registri_conservati() -> bool {
    let (mut a, mut b, mut c, mut d, mut e, mut f) = (0x1111u64, 0x2222u64, 0x3333u64, 0x4444u64, 0x5555u64, 0x6666u64);
    // SAFETY: SC_CEDI ignora gli argomenti; i registri dichiarati inout tornano al programma
    unsafe {
        asm!(
            "syscall",
            inlateout("rax") abi::SC_CEDI => _,
            inout("rdi") a,
            inout("rsi") b,
            inout("rdx") c,
            inout("r8") d,
            inout("r9") e,
            inout("r10") f,
            lateout("rcx") _,
            lateout("r11") _,
        );
    }
    a = a.wrapping_add(0);
    b = b.wrapping_add(0);
    c = c.wrapping_add(0);
    d = d.wrapping_add(0);
    e = e.wrapping_add(0);
    f = f.wrapping_add(0);
    (a, b, c, d, e, f) == (0x1111, 0x2222, 0x3333, 0x4444, 0x5555, 0x6666)
}

fn principale(_argomento: u64) -> i64 {
    let cs: u16;
    // SAFETY: lettura del selettore di codice corrente (consentita in ring 3)
    unsafe { asm!("mov {0:x}, cs", out(reg) cs) };
    stampa!("ciao da OMNI: processo {} in modalita' utente (CPL {}) sulla CPU {}", pid(), cs & 3, cpu());
    let ok = registri_conservati();
    stampa!("registri conservati dalla chiamata di sistema: {}", if ok { "si'" } else { "NO" });
    if cs & 3 == 3 && ok {
        0
    } else {
        1
    }
}
