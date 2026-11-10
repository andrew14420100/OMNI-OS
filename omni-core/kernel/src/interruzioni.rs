// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Smistamento delle interruzioni ed eccezioni.
//!
//! Per le prove nel kernel esiste un "recupero atteso": prima di provocare di proposito un
//! page fault, il test registra l'indirizzo da cui riprendere. Il gestore verifica che
//! l'eccezione sia quella attesa, ne registra CR2 e codice d'errore e riprende da lì.

use crate::arch::cpu;
use crate::arch::idt::{self, Cornice};
use crate::{kprintln, sched, tastiera, tempo};
use core::sync::atomic::{AtomicU64, Ordering};
use omni_comune::acpi::MAX_CPU;

/// Indirizzo da cui riprendere dopo un page fault atteso, per CPU.
pub static RECUPERO: [AtomicU64; MAX_CPU] = [const { AtomicU64::new(0) }; MAX_CPU];
/// Page fault attesi gestiti, per CPU (prova dello shootdown K2-03).
pub static FAULT_ATTESI: [AtomicU64; MAX_CPU] = [const { AtomicU64::new(0) }; MAX_CPU];
pub static ULTIMO_CR2: AtomicU64 = AtomicU64::new(0);
pub static ULTIMO_ERRORE: AtomicU64 = AtomicU64::new(0);
pub static BREAKPOINT: AtomicU64 = AtomicU64::new(0);
pub static PAGE_FAULT: AtomicU64 = AtomicU64::new(0);
pub static TASTI: AtomicU64 = AtomicU64::new(0);

#[no_mangle]
extern "C" fn omni_interruzione(c: &mut Cornice) {
    match c.vettore {
        3 => {
            BREAKPOINT.fetch_add(1, Ordering::Relaxed);
            kprintln!("[int] breakpoint a {:#x}: gestito, esecuzione ripresa", c.rip);
        }
        14 => {
            let cr2 = cpu::cr2();
            PAGE_FAULT.fetch_add(1, Ordering::Relaxed);
            ULTIMO_CR2.store(cr2, Ordering::Relaxed);
            ULTIMO_ERRORE.store(c.errore, Ordering::Relaxed);
            let i = crate::smp::indice();
            let r = RECUPERO[i].swap(0, Ordering::Relaxed);
            if r != 0 {
                FAULT_ATTESI[i].fetch_add(1, Ordering::Relaxed);
                c.rip = r;
                return;
            }
            // memoria virtuale su richiesta e copy-on-write (K2-04, K2-05)
            if crate::vmm::gestisci_fault(cr2, c.errore) {
                return;
            }
            eccezione_fatale(c, cr2);
        }
        8 => doppio_errore(c),
        v if v < 32 => eccezione_fatale(c, cpu::cr2()),
        v if v == idt::VETTORE_TIMER as u64 => {
            tempo::tick();
            tempo::fine_interruzione();
            sched::tick();
        }
        v if v == idt::VETTORE_TASTIERA as u64 => {
            TASTI.fetch_add(1, Ordering::Relaxed);
            tastiera::interruzione();
            tempo::fine_interruzione();
        }
        v if v == idt::VETTORE_SHOOTDOWN as u64 => {
            crate::smp::servi_richieste();
            tempo::fine_interruzione();
        }
        v if v == idt::VETTORE_SPURIO as u64 => {}
        _ => tempo::fine_interruzione(), // IRQ inattese del PIC (spurie): ignorate
    }
}

fn eccezione_fatale(c: &Cornice, cr2: u64) -> ! {
    panic!("eccezione {} ({}) a rip={:#x} errore={:#x} cr2={:#x} rsp={:#x}", c.vettore, idt::nome_eccezione(c.vettore), c.rip, c.errore, cr2, c.rsp);
}

fn doppio_errore(c: &Cornice) -> ! {
    let cr2 = cpu::cr2();
    let guardia = crate::mem::heap::in_guardia(cr2);
    kprintln!(
        "DOUBLE FAULT (stack IST1 dedicato): rip={:#x} rsp={:#x} cr2={:#x}{}",
        c.rip,
        c.rsp,
        cr2,
        if guardia { " - pagina di guardia dello stack: overflow dello stack" } else { "" }
    );
    crate::video::riga("DOUBLE FAULT: overflow dello stack rilevato dalla pagina di guardia", crate::video::ROSSO);
    #[cfg(feature = "prova-doppio-errore")]
    {
        if guardia {
            kprintln!("PROVA K1-03 doppio errore: SUPERATA (rapporto prodotto, nessun riavvio)");
            cpu::esci_qemu(0x10);
        }
        cpu::esci_qemu(0x11);
    }
    #[allow(unreachable_code)]
    {
        #[cfg(feature = "ktest")]
        cpu::esci_qemu(0x11);
        cpu::ferma()
    }
}
