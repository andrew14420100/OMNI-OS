// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Tabelle di pagine del kernel (4 livelli, Intel SDM vol. 3, cap. 4), costruite dal kernel
//! stesso: testo R-X, dati di sola lettura R--, dati RW- (W^X), mappa diretta della memoria
//! fisica RW- senza esecuzione, registri dei dispositivi non in cache.

use super::frame;
use crate::arch::cpu;
use crate::sync::Blocco;
use omni_comune::bootinfo::{BootInfo, TipoMemoria, PAGINA};

pub const PRESENTE: u64 = 1;
pub const SCRIVIBILE: u64 = 1 << 1;
pub const NO_CACHE: u64 = (1 << 3) | (1 << 4); // PWT | PCD
const GRANDE: u64 = 1 << 7;
pub const NON_ESEGUIBILE: u64 = 1 << 63;
const INDIRIZZO: u64 = 0x000f_ffff_ffff_f000;
const DUE_MB: u64 = 2 * 1024 * 1024;

/// Area per i registri dei dispositivi (APIC, IOAPIC, HPET).
const BASE_MMIO: u64 = 0xffff_ff00_0000_0000;

extern "C" {
    static __testo_inizio: u8;
    static __testo_fine: u8;
    static __sola_inizio: u8;
    static __sola_fine: u8;
    static __dati_inizio: u8;
    static __dati_fine: u8;
}

/// Frame usati per tabelle di pagine intermedie (per il conto esatto della memoria).
pub static TABELLE: core::sync::atomic::AtomicU64 = core::sync::atomic::AtomicU64::new(0);

struct Stato {
    pml4: u64,
    prossimo_mmio: u64,
}

static STATO: Blocco<Stato> = Blocco::new(Stato { pml4: 0, prossimo_mmio: BASE_MMIO });

fn tabella(fisico: u64) -> &'static mut [u64; 512] {
    // SAFETY: le tabelle sono frame assegnati a questo modulo, raggiunti tramite la mappa diretta
    unsafe { &mut *(frame::virtuale(fisico) as *mut [u64; 512]) }
}

fn successiva(t: &mut [u64; 512], i: usize, crea: bool) -> Option<u64> {
    if t[i] & PRESENTE != 0 {
        assert!(t[i] & GRANDE == 0, "pagina grande dove serve una tabella");
        return Some(t[i] & INDIRIZZO);
    }
    if !crea {
        return None;
    }
    let f = frame::alloca().expect("memoria esaurita per le tabelle di pagine");
    TABELLE.fetch_add(1, core::sync::atomic::Ordering::Relaxed);
    t[i] = f | PRESENTE | SCRIVIBILE;
    Some(f)
}

fn indici(v: u64) -> [usize; 4] {
    [((v >> 39) & 511) as usize, ((v >> 30) & 511) as usize, ((v >> 21) & 511) as usize, ((v >> 12) & 511) as usize]
}

fn mappa_in(pml4: u64, virt: u64, fis: u64, flag: u64, grande: bool) {
    let [a, b, c, d] = indici(virt);
    let pdpt = successiva(tabella(pml4), a, true).unwrap();
    let pd = successiva(tabella(pdpt), b, true).unwrap();
    if grande {
        tabella(pd)[c] = fis | flag | GRANDE | PRESENTE;
        return;
    }
    let pt = successiva(tabella(pd), c, true).unwrap();
    tabella(pt)[d] = fis | flag | PRESENTE;
}

/// Traduce un indirizzo virtuale con le tabelle indicate (anche quelle di OMNI Boot).
fn traduci_in(pml4: u64, virt: u64) -> Option<(u64, u64)> {
    let [a, b, c, d] = indici(virt);
    let pdpt = successiva(tabella(pml4), a, false)?;
    let tpd = tabella(pdpt);
    let pd = successiva(tpd, b, false)?;
    let e2 = tabella(pd)[c];
    if e2 & PRESENTE == 0 {
        return None;
    }
    if e2 & GRANDE != 0 {
        return Some(((e2 & INDIRIZZO & !(DUE_MB - 1)) + (virt & (DUE_MB - 1)), e2));
    }
    let e1 = tabella(e2 & INDIRIZZO)[d];
    (e1 & PRESENTE != 0).then(|| ((e1 & INDIRIZZO) + (virt & (PAGINA - 1)), e1))
}

fn sezione(inizio: &u8, fine: &u8) -> (u64, u64) {
    (inizio as *const u8 as u64, fine as *const u8 as u64)
}

pub struct Riepilogo {
    pub pml4: u64,
    pub testo: (u64, u64),
    pub sola: (u64, u64),
    pub dati: (u64, u64),
    pub mappa_diretta_mib: u64,
}

/// Costruisce le tabelle del kernel e le attiva (sostituiscono quelle di OMNI Boot).
pub fn inizializza(bi: &BootInfo) -> Riepilogo {
    let vecchie = cpu::cr3() & INDIRIZZO;
    let pml4 = frame::alloca().expect("memoria esaurita");
    // SAFETY: simboli definiti dallo script di collegamento
    let (testo, sola, dati) =
        unsafe { (sezione(&__testo_inizio, &__testo_fine), sezione(&__sola_inizio, &__sola_fine), sezione(&__dati_inizio, &__dati_fine)) };
    for (inizio, fine, flag) in [(testo, 0), (sola, NON_ESEGUIBILE), (dati, SCRIVIBILE | NON_ESEGUIBILE)].map(|((i, f), fl)| (i, f, fl)) {
        let mut v = inizio;
        while v < fine {
            let (fis, _) = traduci_in(vecchie, v).expect("pagina del kernel non mappata da OMNI Boot");
            mappa_in(pml4, v, fis, flag, false);
            v += PAGINA;
        }
    }
    // mappa diretta: tutta la memoria descritta, almeno 4 GiB (pagine da 2 MiB)
    let mut fine = 4u64 << 30;
    for r in bi.regioni().iter().filter(|r| !matches!(r.tipo, TipoMemoria::Mmio | TipoMemoria::Riservata)) {
        fine = fine.max(r.fine());
    }
    fine = fine.max(bi.framebuffer.fisico + bi.framebuffer.dimensione).div_ceil(DUE_MB) * DUE_MB;
    let mut f = 0;
    while f < fine {
        mappa_in(pml4, bi.offset_mappa_fisica + f, f, SCRIVIBILE | NON_ESEGUIBILE, true);
        f += DUE_MB;
    }
    // SAFETY: le nuove tabelle mappano codice, dati, stack (in .bss) e mappa diretta usati ora
    unsafe { cpu::imposta_cr3(pml4) };
    STATO.prendi().pml4 = pml4;
    Riepilogo { pml4, testo, sola, dati, mappa_diretta_mib: fine >> 20 }
}

/// Mappa una pagina da 4 KiB nello spazio del kernel.
pub fn mappa(virt: u64, fis: u64, flag: u64) {
    let pml4 = STATO.prendi().pml4;
    mappa_in(pml4, virt, fis, flag, false);
    cpu::invlpg(virt);
}

/// Rimuove una pagina e restituisce il frame che conteneva.
pub fn rimuovi(virt: u64) -> Option<u64> {
    let pml4 = STATO.prendi().pml4;
    let [a, b, c, d] = indici(virt);
    let pdpt = successiva(tabella(pml4), a, false)?;
    let pd = successiva(tabella(pdpt), b, false)?;
    let pt = successiva(tabella(pd), c, false)?;
    let t = tabella(pt);
    let e = t[d];
    if e & PRESENTE == 0 {
        return None;
    }
    t[d] = 0;
    cpu::invlpg(virt);
    crate::smp::shootdown(virt);
    Some(e & INDIRIZZO)
}

/// Cambia i permessi di una pagina già mappata (stesso frame) su tutte le CPU.
pub fn imposta_flag(virt: u64, flag: u64) -> Option<u64> {
    let pml4 = STATO.prendi().pml4;
    let [a, b, c, d] = indici(virt);
    let pdpt = successiva(tabella(pml4), a, false)?;
    let pd = successiva(tabella(pdpt), b, false)?;
    let pt = successiva(tabella(pd), c, false)?;
    let t = tabella(pt);
    if t[d] & PRESENTE == 0 {
        return None;
    }
    let f = t[d] & INDIRIZZO;
    t[d] = f | flag | PRESENTE;
    cpu::invlpg(virt);
    crate::smp::shootdown(virt);
    Some(f)
}

/// Indirizzo fisico e flag della voce che mappa `virt`.
pub fn traduci(virt: u64) -> Option<(u64, u64)> {
    traduci_in(STATO.prendi().pml4, virt)
}

/// Registri di un dispositivo: pagine non in cache, non eseguibili, in un'area dedicata.
pub fn mappa_dispositivo(fis: u64, byte: u64) -> u64 {
    let base = fis & !(PAGINA - 1);
    let pagine = (fis + byte - base).div_ceil(PAGINA);
    let virt = {
        let mut s = STATO.prendi();
        let v = s.prossimo_mmio;
        s.prossimo_mmio += (pagine + 1) * PAGINA; // una pagina vuota fra due dispositivi
        v
    };
    for p in 0..pagine {
        mappa(virt + p * PAGINA, base + p * PAGINA, SCRIVIBILE | NO_CACHE | NON_ESEGUIBILE);
    }
    virt + (fis - base)
}

/// PML4 del kernel (condivisa da tutti gli spazi d'indirizzi per la metà alta).
pub fn pml4_kernel() -> u64 {
    STATO.prendi().pml4
}

/// Crea tutte le tabelle di secondo livello della metà alta (voci 256..512 della PML4):
/// gli spazi dei processi copiano queste voci, quindi ogni mappatura futura del kernel è
/// visibile in tutti gli spazi senza aggiornarli. Restituisce le tabelle create.
#[allow(dead_code)] // K3-WIP: collegato nei passi successivi di K3
pub fn prepara_meta_alta() -> u64 {
    let pml4 = STATO.prendi().pml4;
    let t = tabella(pml4);
    let mut create = 0;
    for i in 256..512 {
        if t[i] & PRESENTE == 0 {
            successiva(t, i, true);
            create += 1;
        }
    }
    create
}
