// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Spazi d'indirizzi dei processi (K3).
//!
//! Ogni processo ha una PML4 propria: le voci 0..256 (metà bassa) descrivono solo la sua
//! memoria utente, le voci 256..512 sono copiate dalla PML4 del kernel (stesse tabelle,
//! preparate tutte in anticipo da `pagine::prepara_meta_alta`) e non hanno il bit "utente":
//! dal ring 3 il kernel è inaccessibile.
//!
//! Le pagine utente appartengono a un solo processo (nessuna condivisione in K3): alla
//! distruzione dello spazio tutte le pagine e tutte le tabelle della metà bassa tornano
//! all'allocatore di frame. La distruzione avviene solo quando nessun thread del processo è
//! più in esecuzione: ogni cambio di thread ricarica CR3, quindi nessuna CPU conserva voci
//! del TLB di quello spazio.

use super::{frame, pagine};
use core::sync::atomic::{AtomicU64, Ordering};
use omni_comune::abi;
use omni_comune::bootinfo::PAGINA;

pub const PRESENTE: u64 = 1;
pub const SCRIVIBILE: u64 = 1 << 1;
pub const UTENTE: u64 = 1 << 2;
pub const NON_ESEGUIBILE: u64 = 1 << 63;
const GRANDE: u64 = 1 << 7;
const INDIRIZZO: u64 = 0x000f_ffff_ffff_f000;

/// Frame assegnati e restituiti dagli spazi dei processi (per il conto delle risorse).
pub static FRAME_ASSEGNATI: AtomicU64 = AtomicU64::new(0);
pub static FRAME_RESTITUITI: AtomicU64 = AtomicU64::new(0);

fn tabella(fisico: u64) -> &'static mut [u64; 512] {
    // SAFETY: tabelle di pagine dello spazio, frame assegnati da questo modulo (o dal kernel per
    // la metà alta), raggiunti tramite la mappa diretta
    unsafe { &mut *(frame::virtuale(fisico) as *mut [u64; 512]) }
}

fn nuovo_frame() -> Option<u64> {
    let f = frame::alloca()?;
    FRAME_ASSEGNATI.fetch_add(1, Ordering::Relaxed);
    Some(f)
}

fn rendi_frame(f: u64) {
    if frame::libera(f) {
        FRAME_RESTITUITI.fetch_add(1, Ordering::Relaxed);
    }
}

/// Nuovo spazio: PML4 con la metà alta del kernel e la metà bassa vuota.
pub fn nuovo() -> Option<u64> {
    let pml4 = nuovo_frame()?;
    let k = tabella(pagine::pml4_kernel());
    let t = tabella(pml4);
    t[256..512].copy_from_slice(&k[256..512]);
    Some(pml4)
}

fn indici(v: u64) -> [usize; 4] {
    [((v >> 39) & 511) as usize, ((v >> 30) & 511) as usize, ((v >> 21) & 511) as usize, ((v >> 12) & 511) as usize]
}

fn successiva(t: &mut [u64; 512], i: usize, crea: bool) -> Option<u64> {
    if t[i] & PRESENTE != 0 {
        if t[i] & GRANDE != 0 {
            return None;
        }
        return Some(t[i] & INDIRIZZO);
    }
    if !crea {
        return None;
    }
    let f = nuovo_frame()?;
    // tabelle intermedie: utente e scrivibili; i permessi veri sono nella voce finale
    t[i] = f | PRESENTE | SCRIVIBILE | UTENTE;
    Some(f)
}

/// Mappa una pagina utente. Rifiuta indirizzi fuori dallo spazio utente, pagine già
/// presenti e combinazioni scrivibile+eseguibile (W^X).
pub fn mappa(pml4: u64, virt: u64, fis: u64, flag: u64) -> Result<(), &'static str> {
    if virt & (PAGINA - 1) != 0 || !abi::intervallo_utente(virt, PAGINA) {
        return Err("indirizzo fuori dallo spazio utente");
    }
    if flag & SCRIVIBILE != 0 && flag & NON_ESEGUIBILE == 0 {
        return Err("pagina scrivibile ed eseguibile (W^X)");
    }
    let [a, b, c, d] = indici(virt);
    let pdpt = successiva(tabella(pml4), a, true).ok_or("memoria esaurita")?;
    let pd = successiva(tabella(pdpt), b, true).ok_or("memoria esaurita")?;
    let pt = successiva(tabella(pd), c, true).ok_or("memoria esaurita")?;
    let t = tabella(pt);
    if t[d] & PRESENTE != 0 {
        return Err("pagina già mappata");
    }
    t[d] = (fis & INDIRIZZO) | (flag & (SCRIVIBILE | NON_ESEGUIBILE)) | UTENTE | PRESENTE;
    Ok(())
}

/// Assegna un frame azzerato e lo mappa; restituisce il frame.
pub fn mappa_nuova(pml4: u64, virt: u64, flag: u64) -> Result<u64, &'static str> {
    let f = nuovo_frame().ok_or("memoria esaurita")?;
    if let Err(e) = mappa(pml4, virt, f, flag) {
        rendi_frame(f);
        return Err(e);
    }
    Ok(f)
}

/// Voce finale di una pagina utente (frame e flag), se presente.
pub fn traduci(pml4: u64, virt: u64) -> Option<(u64, u64)> {
    if !abi::intervallo_utente(virt & !(PAGINA - 1), PAGINA) {
        return None;
    }
    let [a, b, c, d] = indici(virt);
    let pdpt = successiva(tabella(pml4), a, false)?;
    let pd = successiva(tabella(pdpt), b, false)?;
    let pt = successiva(tabella(pd), c, false)?;
    let e = tabella(pt)[d];
    (e & PRESENTE != 0).then_some((e & INDIRIZZO, e))
}

/// true se ogni pagina di [inizio, inizio+lunghezza) è presente, utente e (se richiesto)
/// scrivibile nello spazio indicato.
pub fn accessibile(pml4: u64, inizio: u64, lunghezza: u64, scrittura: bool) -> bool {
    if !abi::intervallo_utente(inizio, lunghezza) {
        return false;
    }
    if lunghezza == 0 {
        return true;
    }
    let mut p = inizio & !(PAGINA - 1);
    while p < inizio + lunghezza {
        match traduci(pml4, p) {
            Some((_, e)) if e & UTENTE != 0 && (!scrittura || e & SCRIVIBILE != 0) => {}
            _ => return false,
        }
        p += PAGINA;
    }
    true
}

/// Copia `dati` nella memoria utente di uno spazio (anche non attivo) tramite la mappa diretta.
pub fn scrivi(pml4: u64, virt: u64, dati: &[u8]) -> Result<(), &'static str> {
    let mut fatto = 0usize;
    while fatto < dati.len() {
        let v = virt + fatto as u64;
        let (f, _) = traduci(pml4, v).ok_or("pagina non mappata")?;
        let off = (v & (PAGINA - 1)) as usize;
        let n = (PAGINA as usize - off).min(dati.len() - fatto);
        // SAFETY: frame della pagina utente appena tradotta, raggiunto con la mappa diretta;
        // n non supera la fine della pagina
        unsafe { core::ptr::copy_nonoverlapping(dati[fatto..].as_ptr(), (frame::virtuale(f) + off as u64) as *mut u8, n) };
        fatto += n;
    }
    Ok(())
}

/// Esito della distruzione di uno spazio.
pub struct Rilascio {
    pub pagine: u64,
    pub tabelle: u64,
}

/// Restituisce tutte le pagine, le tabelle della metà bassa e la PML4.
pub fn distruggi(pml4: u64) -> Rilascio {
    let mut r = Rilascio { pagine: 0, tabelle: 0 };
    let t4 = tabella(pml4);
    for e4 in t4[..256].iter_mut().filter(|e| **e & PRESENTE != 0) {
        let t3 = tabella(*e4 & INDIRIZZO);
        for e3 in t3.iter_mut().filter(|e| **e & PRESENTE != 0) {
            let t2 = tabella(*e3 & INDIRIZZO);
            for e2 in t2.iter_mut().filter(|e| **e & PRESENTE != 0) {
                let t1 = tabella(*e2 & INDIRIZZO);
                for e1 in t1.iter_mut().filter(|e| **e & PRESENTE != 0) {
                    rendi_frame(*e1 & INDIRIZZO);
                    *e1 = 0;
                    r.pagine += 1;
                }
                rendi_frame(*e2 & INDIRIZZO);
                *e2 = 0;
                r.tabelle += 1;
            }
            rendi_frame(*e3 & INDIRIZZO);
            *e3 = 0;
            r.tabelle += 1;
        }
        rendi_frame(*e4 & INDIRIZZO);
        *e4 = 0;
        r.tabelle += 1;
    }
    rendi_frame(pml4);
    r.tabelle += 1;
    r
}
