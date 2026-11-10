// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Kernel OMNI — milestone K1.
//!
//! Ingresso da OMNI Boot con l'indirizzo di `BootInfo` in RDI, interruzioni disattivate e le
//! tabelle di pagine del caricatore. Il kernel imposta il proprio stack, poi esegue le fasi
//! di inizializzazione, ciascuna verificata da una prova (modulo `prove`).
#![no_std]
#![no_main]

extern crate alloc;

mod acpi;
mod arch;
mod chiamate;
mod interruzioni;
mod mem;
mod potenza;
mod prove;
mod prove_k2;
mod sched;
mod seriale;
mod smp;
mod sync;
mod tastiera;
mod tempo;
mod video;
mod vmm;

use arch::cpu;
use core::fmt::Write;

core::arch::global_asm!(
    r#"
.section .text.ingresso, "ax"
.global _start
_start:
    lea rsp, [rip + omni_stack_avvio_cima]
    xor ebp, ebp
    call omni_kmain
    ud2

.section .bss
.balign 16
omni_stack_avvio:
    .skip 131072
omni_stack_avvio_cima:
.text
"#
);

#[no_mangle]
extern "C" fn omni_kmain(boot_info: u64) -> ! {
    seriale::inizializza();
    prove::esegui(boot_info)
}

/// Testo formattato in un buffer fisso (usabile prima dell'heap e nel panico).
pub struct Buf {
    b: [u8; 400],
    n: usize,
}

impl Buf {
    pub const fn new() -> Self {
        Self { b: [0; 400], n: 0 }
    }
    pub fn as_str(&self) -> &str {
        core::str::from_utf8(&self.b[..self.n]).unwrap_or("?")
    }
}

impl Default for Buf {
    fn default() -> Self {
        Self::new()
    }
}

impl Write for Buf {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        for &c in s.as_bytes() {
            if self.n < self.b.len() {
                self.b[self.n] = c;
                self.n += 1;
            }
        }
        Ok(())
    }
}

#[macro_export]
macro_rules! testo {
    ($($a:tt)*) => {{
        use core::fmt::Write as _;
        let mut b = $crate::Buf::new();
        let _ = write!(b, $($a)*);
        b
    }};
}

#[panic_handler]
fn panico(info: &core::panic::PanicInfo) -> ! {
    cpu::disattiva_interruzioni();
    // SAFETY: la CPU si ferma dopo il rapporto: nessun altro userà più questi blocchi
    let mut r = unsafe { seriale::REGISTRO.forza() };
    let messaggio = testo!("{}", info.message());
    let posizione = info.location().map(|l| testo!("{}:{}", l.file(), l.line())).unwrap_or_else(Buf::new);
    let _ = writeln!(r, "KERNEL PANIC: {}", messaggio.as_str());
    let _ = writeln!(r, "KERNEL PANIC: posizione {}", posizione.as_str());
    drop(r);
    // SAFETY: come sopra
    if let Some(s) = unsafe { video::SCHERMO.forza() }.as_mut() {
        s.scrivi_riga("KERNEL PANIC - sistema fermato", video::ROSSO);
        s.scrivi_riga(messaggio.as_str(), video::ROSSO);
        s.scrivi_riga(posizione.as_str(), video::TESTO_2);
    }
    #[cfg(feature = "prova-panico")]
    if messaggio.as_str().contains("prova di panico controllata") {
        // SAFETY: come sopra
        let _ = writeln!(unsafe { seriale::REGISTRO.forza() }, "PROVA K1-12 panico: SUPERATA (rapporto su seriale e schermo)");
        cpu::esci_qemu(0x10);
    }
    #[cfg(feature = "ktest")]
    cpu::esci_qemu(0x11);
    #[allow(unreachable_code)]
    cpu::ferma()
}
