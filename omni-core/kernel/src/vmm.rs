// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Memoria virtuale con allocazione su richiesta e copy-on-write (K2).
//!
//! Una regione riservata non ha frame finché non viene toccata: il page fault su una sua
//! pagina assente assegna un frame azzerato. Una regione clonata condivide i frame della
//! sorgente in sola lettura (bit software COW nella voce di pagina); la prima scrittura su
//! una pagina condivisa ne fa una copia privata. I frame condivisi hanno un contatore di
//! riferimenti. In K2 le regioni stanno nello spazio del kernel; con K3 diventano parte degli
//! spazi d'indirizzi dei processi.

use crate::mem::{frame, pagine};
use crate::sync::Blocco;
use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use core::sync::atomic::{AtomicU64, Ordering};
use omni_comune::bootinfo::PAGINA;

const BASE: u64 = 0xffff_d000_0000_0000;
/// Bit 9 della voce di pagina (disponibile al sistema operativo): pagina copy-on-write.
const COW: u64 = 1 << 9;

#[derive(Clone, Copy)]
struct Regione {
    inizio: u64,
    pagine: u64,
}

struct Stato {
    regioni: Vec<Regione>,
    prossimo: u64,
    /// riferimenti dei frame condivisi (assenti = 1 riferimento)
    riferimenti: BTreeMap<u64, u32>,
}

static STATO: Blocco<Stato> = Blocco::new(Stato { regioni: Vec::new(), prossimo: BASE, riferimenti: BTreeMap::new() });
pub static FAULT_SU_RICHIESTA: AtomicU64 = AtomicU64::new(0);
pub static COPIE_COW: AtomicU64 = AtomicU64::new(0);

/// Riserva `pagine` pagine virtuali senza assegnare frame.
pub fn riserva(pagine_n: u64) -> u64 {
    let mut s = STATO.prendi();
    let inizio = s.prossimo;
    s.prossimo += (pagine_n + 1) * PAGINA; // una pagina vuota fra due regioni
    s.regioni.push(Regione { inizio, pagine: pagine_n });
    inizio
}

fn regione_di(s: &Stato, ind: u64) -> Option<Regione> {
    s.regioni.iter().copied().find(|r| ind >= r.inizio && ind < r.inizio + r.pagine * PAGINA)
}

/// Gestore dei page fault nelle regioni: true se il fault è stato risolto.
pub fn gestisci_fault(ind: u64, errore: u64) -> bool {
    let mut s = STATO.prendi();
    if regione_di(&s, ind).is_none() {
        return false;
    }
    let pagina = ind & !(PAGINA - 1);
    let presente = errore & 1 != 0;
    let scrittura = errore & 2 != 0;
    if !presente {
        // prima pagina toccata: frame azzerato privato
        let Some(f) = frame::alloca() else { return false };
        pagine::mappa(pagina, f, pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE);
        FAULT_SU_RICHIESTA.fetch_add(1, Ordering::Relaxed);
        return true;
    }
    let Some((f, flag)) = pagine::traduci(pagina) else { return false };
    let f = f & !(PAGINA - 1);
    if !scrittura || flag & COW == 0 {
        return false; // violazione vera: non è una pagina copy-on-write
    }
    let rif = s.riferimenti.get(&f).copied().unwrap_or(1);
    if rif > 1 {
        // pagina condivisa: copia privata
        let Some(nuovo) = frame::alloca() else { return false };
        // SAFETY: entrambi i frame sono raggiungibili dalla mappa diretta; il nuovo è appena assegnato
        unsafe { core::ptr::copy_nonoverlapping(frame::virtuale(f) as *const u8, frame::virtuale(nuovo) as *mut u8, PAGINA as usize) };
        pagine::rimuovi(pagina);
        pagine::mappa(pagina, nuovo, pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE);
        if rif - 1 == 1 {
            s.riferimenti.remove(&f);
        } else {
            s.riferimenti.insert(f, rif - 1);
        }
        COPIE_COW.fetch_add(1, Ordering::Relaxed);
    } else {
        // ultimo riferimento: la pagina torna scrivibile senza copia
        pagine::imposta_flag(pagina, pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE);
    }
    true
}

/// Clona una regione in copy-on-write: le pagine presenti diventano condivise in sola
/// lettura in entrambe le regioni. Restituisce l'inizio della nuova regione.
pub fn clona_cow(sorgente: u64) -> Option<u64> {
    let r = {
        let s = STATO.prendi();
        regione_di(&s, sorgente)?
    };
    let nuova = riserva(r.pagine);
    let mut s = STATO.prendi();
    for p in 0..r.pagine {
        let v = r.inizio + p * PAGINA;
        let Some((f, _)) = pagine::traduci(v) else { continue };
        let f = f & !(PAGINA - 1);
        pagine::imposta_flag(v, COW | pagine::NON_ESEGUIBILE);
        pagine::mappa(nuova + p * PAGINA, f, COW | pagine::NON_ESEGUIBILE);
        let rif = s.riferimenti.get(&f).copied().unwrap_or(1);
        s.riferimenti.insert(f, rif + 1);
    }
    Some(nuova)
}

/// Pagine presenti e frame distinti di una regione.
pub fn presenti(inizio: u64) -> u64 {
    let r = {
        let s = STATO.prendi();
        match regione_di(&s, inizio) {
            Some(r) => r,
            None => return 0,
        }
    };
    (0..r.pagine).filter(|p| pagine::traduci(r.inizio + p * PAGINA).is_some()).count() as u64
}

pub fn frame_di(virt: u64) -> Option<u64> {
    pagine::traduci(virt).map(|(f, _)| f & !(PAGINA - 1))
}

pub fn riferimenti(f: u64) -> u32 {
    STATO.prendi().riferimenti.get(&f).copied().unwrap_or(1)
}

/// Rilascia una regione: le pagine vengono rimosse (su tutte le CPU) e i frame non più
/// condivisi tornano liberi.
pub fn rilascia(inizio: u64) {
    let mut s = STATO.prendi();
    let Some(pos) = s.regioni.iter().position(|r| r.inizio == inizio) else { return };
    let r = s.regioni.remove(pos);
    for p in 0..r.pagine {
        let Some(f) = pagine::rimuovi(r.inizio + p * PAGINA) else { continue };
        let rif = s.riferimenti.get(&f).copied().unwrap_or(1);
        if rif > 1 {
            if rif - 1 == 1 {
                s.riferimenti.remove(&f);
            } else {
                s.riferimenti.insert(f, rif - 1);
            }
        } else {
            frame::libera(f);
        }
    }
}
