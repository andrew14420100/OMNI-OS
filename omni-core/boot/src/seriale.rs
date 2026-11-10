// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Porta seriale COM1 (UART 16550, porte I/O 0x3F8-0x3FF), 115200 baud, 8N1.

const BASE: u16 = 0x3f8;

fn scrivi_porta(p: u16, v: u8) {
    // SAFETY: porte della UART COM1, accessibili in ring 0
    unsafe { core::arch::asm!("out dx, al", in("dx") p, in("al") v, options(nomem, nostack, preserves_flags)) };
}
fn leggi_porta(p: u16) -> u8 {
    let v: u8;
    // SAFETY: come sopra
    unsafe { core::arch::asm!("in al, dx", out("al") v, in("dx") p, options(nomem, nostack, preserves_flags)) };
    v
}

pub fn inizializza() {
    scrivi_porta(BASE + 1, 0x00); // nessuna interruzione
    scrivi_porta(BASE + 3, 0x80); // DLAB
    scrivi_porta(BASE, 0x01); // divisore 1 = 115200
    scrivi_porta(BASE + 1, 0x00);
    scrivi_porta(BASE + 3, 0x03); // 8N1
    scrivi_porta(BASE + 2, 0xc7); // FIFO
    scrivi_porta(BASE + 4, 0x03);
}

fn byte(b: u8) {
    for _ in 0..100_000 {
        if leggi_porta(BASE + 5) & 0x20 != 0 {
            break;
        }
    }
    scrivi_porta(BASE, b);
}

pub struct Seriale;

impl core::fmt::Write for Seriale {
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
