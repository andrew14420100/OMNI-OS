// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Heap del kernel (`GlobalAlloc`):
//! - blocchi piccoli (fino a 2 KiB) in classi di dimensione a potenza di 2, con liste libere
//!   per classe (allocazione e rilascio in tempo costante);
//! - blocchi grandi in pagine dedicate, mappate all'allocazione e restituite al rilascio.

use super::{frame, pagine};
use crate::sync::Blocco;
use core::alloc::{GlobalAlloc, Layout};
use omni_comune::bootinfo::PAGINA;

const BASE: u64 = 0xffff_c000_0000_0000;
const LIMITE: u64 = 1 << 30; // 1 GiB di spazio virtuale per l'heap
const CLASSI: usize = 8; // 16, 32, ..., 2048
const MINIMO: usize = 16;

struct Heap {
    liste: [u64; CLASSI],
    cima: u64,
    in_uso: usize,
    allocazioni: u64,
    pagine_mappate: u64,
}

static HEAP: Blocco<Heap> = Blocco::new(Heap { liste: [0; CLASSI], cima: BASE, in_uso: 0, allocazioni: 0, pagine_mappate: 0 });

fn classe(l: &Layout) -> Option<usize> {
    let d = l.size().max(l.align()).max(MINIMO).next_power_of_two();
    (d <= MINIMO << (CLASSI - 1)).then(|| d.trailing_zeros() as usize - MINIMO.trailing_zeros() as usize)
}

impl Heap {
    /// Riserva `n` pagine virtuali nuove e le mappa a frame fisici.
    fn pagine(&mut self, n: u64) -> Option<u64> {
        if self.cima + n * PAGINA > BASE + LIMITE {
            return None;
        }
        let v = self.cima;
        for i in 0..n {
            let f = frame::alloca()?;
            pagine::mappa(v + i * PAGINA, f, pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE);
        }
        self.cima += n * PAGINA;
        self.pagine_mappate += n;
        Some(v)
    }
}

pub struct AllocatoreKernel;

// SAFETY: ogni blocco restituito è allineato e di dimensione almeno pari al layout; i blocchi
// liberi non sono mai restituiti due volte (liste per classe, pagine grandi rimosse al rilascio)
unsafe impl GlobalAlloc for AllocatoreKernel {
    // SAFETY: vedi sopra; il layout ha dimensione non nulla (contratto di GlobalAlloc)
    unsafe fn alloc(&self, l: Layout) -> *mut u8 {
        let mut h = HEAP.prendi();
        h.allocazioni += 1;
        match classe(&l) {
            Some(c) => {
                let dim = MINIMO << c;
                if h.liste[c] == 0 {
                    // nuova pagina divisa in blocchi della classe (allineati alla loro dimensione)
                    let Some(p) = h.pagine(1) else { return core::ptr::null_mut() };
                    let n = PAGINA as usize / dim;
                    for i in (0..n).rev() {
                        let b = p + (i * dim) as u64;
                        // SAFETY: blocco nella pagina appena mappata
                        unsafe { (b as *mut u64).write(h.liste[c]) };
                        h.liste[c] = b;
                    }
                }
                let b = h.liste[c];
                // SAFETY: blocco libero della lista: contiene il puntatore al successivo
                h.liste[c] = unsafe { (b as *const u64).read() };
                h.in_uso += dim;
                b as *mut u8
            }
            None => {
                if l.align() > PAGINA as usize {
                    return core::ptr::null_mut();
                }
                let n = (l.size() as u64).div_ceil(PAGINA);
                match h.pagine(n) {
                    Some(v) => {
                        h.in_uso += (n * PAGINA) as usize;
                        v as *mut u8
                    }
                    None => core::ptr::null_mut(),
                }
            }
        }
    }

    // SAFETY: `p` e `l` provengono da `alloc` (contratto di GlobalAlloc): il blocco torna
    // nella lista della sua classe oppure le sue pagine vengono rimosse e i frame liberati
    unsafe fn dealloc(&self, p: *mut u8, l: Layout) {
        let mut h = HEAP.prendi();
        match classe(&l) {
            Some(c) => {
                // SAFETY: blocco restituito da `alloc` per questa classe
                unsafe { (p as *mut u64).write(h.liste[c]) };
                h.liste[c] = p as u64;
                h.in_uso -= MINIMO << c;
            }
            None => {
                let n = (l.size() as u64).div_ceil(PAGINA);
                for i in 0..n {
                    if let Some(f) = pagine::rimuovi(p as u64 + i * PAGINA) {
                        frame::libera(f);
                    }
                }
                h.in_uso -= (n * PAGINA) as usize;
                h.pagine_mappate -= n;
            }
        }
    }
}

#[global_allocator]
static ALLOCATORE: AllocatoreKernel = AllocatoreKernel;

pub struct Statistiche {
    pub in_uso: usize,
    pub allocazioni: u64,
    pub pagine: u64,
}

pub fn statistiche() -> Statistiche {
    let h = HEAP.prendi();
    Statistiche { in_uso: h.in_uso, allocazioni: h.allocazioni, pagine: h.pagine_mappate }
}

// ---------------------------------------------------------------------- stack dei thread

const BASE_STACK: u64 = 0xffff_fe00_0000_0000;
static PROSSIMO_STACK: Blocco<u64> = Blocco::new(BASE_STACK);

/// Stack di `pagine` pagine con una pagina di guardia NON mappata sotto: un overflow
/// produce un page fault invece di sovrascrivere altra memoria. Restituisce la cima.
pub fn nuovo_stack(pagine_stack: u64) -> u64 {
    let base = {
        let mut p = PROSSIMO_STACK.prendi();
        let b = *p;
        *p += (pagine_stack + 1) * PAGINA;
        b
    };
    // base: guardia (non mappata); da base+PAGINA lo stack vero
    for i in 1..=pagine_stack {
        let f = frame::alloca().expect("memoria esaurita per lo stack");
        pagine::mappa(base + i * PAGINA, f, pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE);
    }
    base + (pagine_stack + 1) * PAGINA
}

/// true se l'indirizzo cade su una pagina di guardia di uno stack.
pub fn in_guardia(ind: u64) -> bool {
    ind >= BASE_STACK && ind < *PROSSIMO_STACK.prendi() && pagine::traduci(ind).is_none()
}
