// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Allocatore di frame fisici (4 KiB) basato sulla mappa di memoria di OMNI Boot.
//! Sono liberi solo i frame segnati `Libera`; il primo MiB resta riservato.

use crate::sync::Blocco;
use omni_comune::bitmap::Bitmap;
use omni_comune::bootinfo::{BootInfo, TipoMemoria, PAGINA};

static ALLOCATORE: Blocco<Option<Bitmap<'static>>> = Blocco::new(None);
static mut OFFSET: u64 = 0;

pub struct Riepilogo {
    pub frame_totali: usize,
    pub frame_liberi: usize,
    pub liberi_dalla_mappa: u64,
}

/// Indirizzo virtuale (mappa diretta) di un indirizzo fisico.
pub fn virtuale(fisico: u64) -> u64 {
    // SAFETY: OFFSET è scritto una sola volta in `inizializza`, prima di ogni uso
    fisico + unsafe { OFFSET }
}

pub fn inizializza(bi: &BootInfo) -> Riepilogo {
    // SAFETY: unica scrittura, all'avvio, prima di ogni lettura
    unsafe { OFFSET = bi.offset_mappa_fisica };
    let regioni = bi.regioni();
    let fine = regioni.iter().filter(|r| r.tipo == TipoMemoria::Libera).map(|r| r.fine()).max().unwrap_or(0);
    let frame = (fine / PAGINA) as usize;
    let parole = frame.div_ceil(64);
    let byte = (parole * 8) as u64;
    let pagine_bitmap = byte.div_ceil(PAGINA);
    // la bitmap stessa va in una regione libera sopra 1 MiB abbastanza grande
    let r = regioni
        .iter()
        .find(|r| r.tipo == TipoMemoria::Libera && r.inizio >= 0x10_0000 && r.pagine >= pagine_bitmap)
        .expect("nessuna regione libera per la bitmap dei frame");
    let fis_bitmap = r.inizio;
    // SAFETY: regione libera (da mappa UEFI), raggiunta tramite la mappa diretta; viene
    // segnata occupata subito sotto e non sarà mai restituita
    let parole_ref: &'static mut [u64] = unsafe { core::slice::from_raw_parts_mut(virtuale(fis_bitmap) as *mut u64, parole) };
    let mut b = Bitmap::nuova(parole_ref, frame);
    let mut liberi_mappa = 0;
    for r in regioni.iter().filter(|r| r.tipo == TipoMemoria::Libera) {
        b.libera_intervallo((r.inizio / PAGINA) as usize, r.pagine as usize);
        liberi_mappa += r.pagine;
    }
    b.occupa_intervallo(0, 256); // primo MiB
    b.occupa_intervallo((fis_bitmap / PAGINA) as usize, pagine_bitmap as usize);
    let rep = Riepilogo { frame_totali: frame, frame_liberi: b.liberi(), liberi_dalla_mappa: liberi_mappa };
    *ALLOCATORE.prendi() = Some(b);
    rep
}

/// Frame fisico azzerato.
pub fn alloca() -> Option<u64> {
    let i = ALLOCATORE.prendi().as_mut()?.alloca()?;
    let fis = i as u64 * PAGINA;
    // SAFETY: frame appena assegnato, raggiungibile tramite la mappa diretta
    unsafe { core::ptr::write_bytes(virtuale(fis) as *mut u8, 0, PAGINA as usize) };
    Some(fis)
}

/// Restituisce un frame; false se non era assegnato (doppio rilascio).
pub fn libera(fisico: u64) -> bool {
    ALLOCATORE.prendi().as_mut().map(|b| b.libera((fisico / PAGINA) as usize)).unwrap_or(false)
}

pub fn liberi() -> usize {
    ALLOCATORE.prendi().as_ref().map(|b| b.liberi()).unwrap_or(0)
}
