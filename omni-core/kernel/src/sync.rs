// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Blocco a rotazione che disattiva le interruzioni mentre è tenuto (nessuno stallo fra
//! codice normale e gestori di interruzione sulla stessa CPU).

use crate::arch::cpu;
use core::cell::UnsafeCell;
use core::ops::{Deref, DerefMut};
use core::sync::atomic::{AtomicBool, Ordering};

pub struct Blocco<T> {
    occupato: AtomicBool,
    dato: UnsafeCell<T>,
}

// SAFETY: l'accesso a `dato` avviene solo tramite la guardia, con esclusione garantita da `occupato`
unsafe impl<T: Send> Sync for Blocco<T> {}

impl<T> Blocco<T> {
    pub const fn new(dato: T) -> Self {
        Self { occupato: AtomicBool::new(false), dato: UnsafeCell::new(dato) }
    }

    pub fn prendi(&self) -> Guardia<'_, T> {
        let interruzioni = cpu::interruzioni_attive();
        cpu::disattiva_interruzioni();
        while self.occupato.compare_exchange_weak(false, true, Ordering::Acquire, Ordering::Relaxed).is_err() {
            // chi aspetta un blocco a interruzioni disattivate serve comunque le richieste
            // d'invalidazione del TLB delle altre CPU (nessuno stallo con lo shootdown)
            crate::smp::servi_richieste();
            core::hint::spin_loop();
        }
        Guardia { blocco: self, interruzioni }
    }

    /// Per il gestore del panico: prende il blocco anche se è rimasto occupato.
    ///
    /// # Safety
    /// Solo quando nessun altro codice potrà più usare il blocco (CPU che si ferma).
    pub unsafe fn forza(&self) -> Guardia<'_, T> {
        cpu::disattiva_interruzioni();
        self.occupato.store(true, Ordering::Relaxed);
        Guardia { blocco: self, interruzioni: false }
    }
}

pub struct Guardia<'a, T> {
    blocco: &'a Blocco<T>,
    interruzioni: bool,
}

impl<T> Deref for Guardia<'_, T> {
    type Target = T;
    fn deref(&self) -> &T {
        // SAFETY: la guardia esiste solo con il blocco preso
        unsafe { &*self.blocco.dato.get() }
    }
}

impl<T> DerefMut for Guardia<'_, T> {
    fn deref_mut(&mut self) -> &mut T {
        // SAFETY: come sopra, accesso esclusivo
        unsafe { &mut *self.blocco.dato.get() }
    }
}

impl<T> Drop for Guardia<'_, T> {
    fn drop(&mut self) {
        self.blocco.occupato.store(false, Ordering::Release);
        if self.interruzioni {
            cpu::attiva_interruzioni();
        }
    }
}
