// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Registro del kernel su COM1 (UART 16550) e, quando disponibile, sullo schermo.

use crate::arch::cpu::{inb, outb};
use crate::sync::Blocco;
use core::fmt::Write;

const BASE: u16 = 0x3f8;

pub fn inizializza() {
    outb(BASE + 1, 0x00);
    outb(BASE + 3, 0x80);
    outb(BASE, 0x01);
    outb(BASE + 1, 0x00);
    outb(BASE + 3, 0x03);
    outb(BASE + 2, 0xc7);
    outb(BASE + 4, 0x03);
}

fn byte(b: u8) {
    for _ in 0..100_000 {
        if inb(BASE + 5) & 0x20 != 0 {
            break;
        }
    }
    outb(BASE, b);
}

pub struct Uart;

impl Write for Uart {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        for b in s.bytes() {
            if b == b'\n' {
                byte(b'\r');
            }
            byte(b);
        }
        Ok(())
    }
}

pub static REGISTRO: Blocco<Uart> = Blocco::new(Uart);

#[macro_export]
macro_rules! kprintln {
    ($($a:tt)*) => {{
        use core::fmt::Write as _;
        let _ = writeln!($crate::seriale::REGISTRO.prendi(), $($a)*);
    }};
}
