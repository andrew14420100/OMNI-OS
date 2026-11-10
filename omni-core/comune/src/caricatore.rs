// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Caricatore dei programmi utente (K3): validazione completa di un ELF e piano di
//! caricamento pagina per pagina. Nessun accesso alla memoria: il kernel usa il piano per
//! assegnare i frame e `riempi_pagina` per il loro contenuto.
//!
//! Regole (oltre a quelle di `elf::Elf::verifica`: firma, classe, ordine dei byte, x86-64,
//! eseguibile, intestazioni e segmenti dentro il file, memoria >= file):
//! - versione ELF 1 e ABI System V;
//! - solo eseguibili statici: niente `PT_INTERP`, `PT_DYNAMIC`, `PT_TLS`; uno stack eseguibile
//!   (`PT_GNU_STACK` con X) è rifiutato;
//! - da 1 a `MAX_SEGMENTI` segmenti `PT_LOAD` non vuoti (quelli vuoti sono ignorati);
//! - allineamento 0, 1 o potenza di 2, con indirizzo e offset congruenti (specifica ELF);
//! - ogni segmento interamente in [`abi::UTENTE_INIZIO`, `abi::LIMITE_IMMAGINE`);
//! - W^X: nessun segmento scrivibile ed eseguibile;
//! - nessuna pagina condivisa da due segmenti (i permessi sono per pagina);
//! - al massimo `MAX_PAGINE_IMMAGINE` pagine in tutto;
//! - punto d'ingresso dentro un segmento eseguibile.

use crate::abi;
use crate::elf::{Elf, ErroreElf, PF_W, PF_X, PT_LOAD};

pub const PAGINA: u64 = 4096;
pub const MAX_SEGMENTI: usize = 8;
/// 16 MiB per codice e dati di un programma.
pub const MAX_PAGINE_IMMAGINE: u64 = 4096;

pub const PT_DYNAMIC: u32 = 2;
pub const PT_INTERP: u32 = 3;
pub const PT_TLS: u32 = 7;
pub const PT_GNU_STACK: u32 = 0x6474_e551;

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum ErroreCaricamento {
    Elf(ErroreElf),
    VersioneElf,
    AbiNonSupportata,
    Interprete,
    Dinamico,
    Tls,
    StackEseguibile,
    NessunSegmento,
    TroppiSegmenti,
    AllineamentoNonValido(usize),
    FuoriSpazioUtente(usize),
    ScrivibileEdEseguibile(usize),
    Sovrapposizione(usize, usize),
    TroppaMemoria,
    IngressoNonEseguibile,
}

impl ErroreCaricamento {
    pub fn descrizione(&self) -> &'static str {
        match self {
            Self::Elf(e) => e.descrizione(),
            Self::VersioneElf => "versione ELF diversa da 1",
            Self::AbiNonSupportata => "ABI diversa da System V",
            Self::Interprete => "richiede un interprete (eseguibile dinamico)",
            Self::Dinamico => "sezione dinamica presente (solo eseguibili statici)",
            Self::Tls => "memoria locale ai thread non supportata",
            Self::StackEseguibile => "stack eseguibile richiesto",
            Self::NessunSegmento => "nessun segmento caricabile",
            Self::TroppiSegmenti => "troppi segmenti caricabili",
            Self::AllineamentoNonValido(_) => "allineamento di un segmento non valido",
            Self::FuoriSpazioUtente(_) => "segmento fuori dallo spazio dei programmi",
            Self::ScrivibileEdEseguibile(_) => "segmento scrivibile ed eseguibile (W^X)",
            Self::Sovrapposizione(_, _) => "segmenti che condividono una pagina",
            Self::TroppaMemoria => "immagine troppo grande",
            Self::IngressoNonEseguibile => "punto d'ingresso fuori dai segmenti eseguibili",
        }
    }
}

/// Un segmento validato, con l'intervallo di pagine che occupa.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct SegmentoUtente {
    pub virtuale: u64,
    pub offset: u64,
    pub dim_file: u64,
    pub dim_memoria: u64,
    pub scrivibile: bool,
    pub eseguibile: bool,
    /// prima pagina (indirizzo allineato) e numero di pagine
    pub prima_pagina: u64,
    pub pagine: u64,
}

impl SegmentoUtente {
    pub fn fine(&self) -> u64 {
        self.prima_pagina + self.pagine * PAGINA
    }
}

/// Piano di caricamento verificato.
#[derive(Debug, Clone, Copy)]
pub struct Piano {
    pub ingresso: u64,
    pub segmenti: [SegmentoUtente; MAX_SEGMENTI],
    pub numero: usize,
}

impl Piano {
    pub fn segmenti(&self) -> &[SegmentoUtente] {
        &self.segmenti[..self.numero]
    }
    pub fn pagine_totali(&self) -> u64 {
        self.segmenti().iter().map(|s| s.pagine).sum()
    }
}

fn u32_le(d: &[u8], o: usize) -> u32 {
    u32::from_le_bytes([d[o], d[o + 1], d[o + 2], d[o + 3]])
}

/// Valida un programma utente e ne calcola il piano di caricamento.
pub fn pianifica(dati: &[u8]) -> Result<Piano, ErroreCaricamento> {
    let elf = Elf::verifica(dati).map_err(ErroreCaricamento::Elf)?;
    // Elf::verifica garantisce almeno 64 byte
    if dati[6] != 1 || u32_le(dati, 20) != 1 {
        return Err(ErroreCaricamento::VersioneElf);
    }
    if dati[7] != 0 {
        return Err(ErroreCaricamento::AbiNonSupportata);
    }
    let mut piano = Piano { ingresso: elf.ingresso, segmenti: [SegmentoUtente::default(); MAX_SEGMENTI], numero: 0 };
    for s in elf.segmenti() {
        match s.tipo {
            PT_INTERP => return Err(ErroreCaricamento::Interprete),
            PT_DYNAMIC => return Err(ErroreCaricamento::Dinamico),
            PT_TLS => return Err(ErroreCaricamento::Tls),
            PT_GNU_STACK if s.permessi & PF_X != 0 => return Err(ErroreCaricamento::StackEseguibile),
            PT_LOAD if s.dim_memoria > 0 => {}
            _ => continue,
        }
        let i = piano.numero;
        if i == MAX_SEGMENTI {
            return Err(ErroreCaricamento::TroppiSegmenti);
        }
        let a = s.allineamento;
        if a > 1 && (!a.is_power_of_two() || s.virtuale % a != s.offset % a) {
            return Err(ErroreCaricamento::AllineamentoNonValido(i));
        }
        let fine = s.virtuale.checked_add(s.dim_memoria).ok_or(ErroreCaricamento::FuoriSpazioUtente(i))?;
        if s.virtuale < abi::UTENTE_INIZIO || fine > abi::LIMITE_IMMAGINE {
            return Err(ErroreCaricamento::FuoriSpazioUtente(i));
        }
        let scrivibile = s.permessi & PF_W != 0;
        let eseguibile = s.permessi & PF_X != 0;
        if scrivibile && eseguibile {
            return Err(ErroreCaricamento::ScrivibileEdEseguibile(i));
        }
        let prima_pagina = s.virtuale & !(PAGINA - 1);
        // fine <= LIMITE_IMMAGINE: l'arrotondamento non trabocca
        let pagine = (fine.div_ceil(PAGINA) * PAGINA - prima_pagina) / PAGINA;
        piano.segmenti[i] = SegmentoUtente {
            virtuale: s.virtuale,
            offset: s.offset,
            dim_file: s.dim_file,
            dim_memoria: s.dim_memoria,
            scrivibile,
            eseguibile,
            prima_pagina,
            pagine,
        };
        piano.numero += 1;
    }
    if piano.numero == 0 {
        return Err(ErroreCaricamento::NessunSegmento);
    }
    let seg = piano.segmenti();
    for (i, a) in seg.iter().enumerate() {
        for (j, b) in seg.iter().enumerate().skip(i + 1) {
            if a.prima_pagina < b.fine() && b.prima_pagina < a.fine() {
                return Err(ErroreCaricamento::Sovrapposizione(i, j));
            }
        }
    }
    if piano.pagine_totali() > MAX_PAGINE_IMMAGINE {
        return Err(ErroreCaricamento::TroppaMemoria);
    }
    if !seg.iter().any(|s| s.eseguibile && piano.ingresso >= s.virtuale && piano.ingresso < s.virtuale + s.dim_memoria) {
        return Err(ErroreCaricamento::IngressoNonEseguibile);
    }
    Ok(piano)
}

/// Contenuto della pagina `k` del segmento: byte del file dove il segmento li ha, zeri
/// altrove (inizio non allineato, parte `.bss`). `dati` è lo stesso file passato a `pianifica`.
pub fn riempi_pagina(dati: &[u8], s: &SegmentoUtente, k: u64, out: &mut [u8; PAGINA as usize]) {
    out.fill(0);
    if k >= s.pagine {
        return;
    }
    let p = s.prima_pagina + k * PAGINA;
    // intersezione fra [p, p+PAGINA) e la parte del segmento presente nel file
    let da = p.max(s.virtuale);
    let a = (p + PAGINA).min(s.virtuale + s.dim_file);
    if da >= a {
        return;
    }
    let sorgente = (s.offset + (da - s.virtuale)) as usize;
    let n = (a - da) as usize;
    let dest = (da - p) as usize;
    out[dest..dest + n].copy_from_slice(&dati[sorgente..sorgente + n]);
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::elf::PF_R;
    use std::vec;
    use std::vec::Vec;

    #[derive(Clone, Copy)]
    struct Ph {
        tipo: u32,
        permessi: u32,
        offset: u64,
        virtuale: u64,
        dim_file: u64,
        dim_memoria: u64,
        allineamento: u64,
    }

    fn carico(permessi: u32, offset: u64, virtuale: u64, dim_file: u64, dim_memoria: u64) -> Ph {
        Ph { tipo: PT_LOAD, permessi, offset, virtuale, dim_file, dim_memoria, allineamento: 0x1000 }
    }

    /// ELF con le intestazioni indicate; il file è lungo `lunghezza` byte, con byte(i) = i % 251.
    fn costruisci(ingresso: u64, ph: &[Ph], lunghezza: usize) -> Vec<u8> {
        let mut d: Vec<u8> = (0..lunghezza.max(64 + 56 * ph.len())).map(|i| (i % 251) as u8).collect();
        d[..64].fill(0);
        d[0..4].copy_from_slice(b"\x7fELF");
        d[4] = 2;
        d[5] = 1;
        d[6] = 1;
        d[16..18].copy_from_slice(&2u16.to_le_bytes());
        d[18..20].copy_from_slice(&0x3eu16.to_le_bytes());
        d[20..24].copy_from_slice(&1u32.to_le_bytes());
        d[24..32].copy_from_slice(&ingresso.to_le_bytes());
        d[32..40].copy_from_slice(&64u64.to_le_bytes());
        d[54..56].copy_from_slice(&56u16.to_le_bytes());
        d[56..58].copy_from_slice(&(ph.len() as u16).to_le_bytes());
        for (i, h) in ph.iter().enumerate() {
            let o = 64 + 56 * i;
            d[o..o + 4].copy_from_slice(&h.tipo.to_le_bytes());
            d[o + 4..o + 8].copy_from_slice(&h.permessi.to_le_bytes());
            d[o + 8..o + 16].copy_from_slice(&h.offset.to_le_bytes());
            d[o + 16..o + 24].copy_from_slice(&h.virtuale.to_le_bytes());
            d[o + 24..o + 32].copy_from_slice(&h.virtuale.to_le_bytes());
            d[o + 32..o + 40].copy_from_slice(&h.dim_file.to_le_bytes());
            d[o + 40..o + 48].copy_from_slice(&h.dim_memoria.to_le_bytes());
            d[o + 48..o + 56].copy_from_slice(&h.allineamento.to_le_bytes());
        }
        d
    }

    /// Programma tipico: codice R-X, costanti R--, dati RW- con .bss (come utente.ld).
    fn tipico() -> (Vec<u8>, Vec<Ph>) {
        let ph = vec![
            carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x1805, 0x1805),
            carico(PF_R, 0x3000, 0x40_2000, 0x3e4, 0x3e4),
            carico(PF_R | PF_W, 0x4000, 0x40_3000, 0xc8, 0x20f1),
            Ph { tipo: PT_GNU_STACK, permessi: PF_R | PF_W, offset: 0, virtuale: 0, dim_file: 0, dim_memoria: 0, allineamento: 0 },
        ];
        (costruisci(0x40_03d0, &ph, 0x5000), ph)
    }

    fn con(ph: &[Ph], ingresso: u64) -> Result<Piano, ErroreCaricamento> {
        pianifica(&costruisci(ingresso, ph, 0x5000))
    }

    #[test]
    fn programma_tipico() {
        let (d, _) = tipico();
        let p = pianifica(&d).unwrap();
        assert_eq!(p.ingresso, 0x40_03d0);
        assert_eq!(p.numero, 3);
        let s = p.segmenti();
        assert_eq!((s[0].prima_pagina, s[0].pagine, s[0].eseguibile, s[0].scrivibile), (0x40_0000, 2, true, false));
        assert_eq!((s[1].prima_pagina, s[1].pagine, s[1].eseguibile, s[1].scrivibile), (0x40_2000, 1, false, false));
        assert_eq!((s[2].prima_pagina, s[2].pagine, s[2].eseguibile, s[2].scrivibile), (0x40_3000, 3, false, true));
        assert_eq!(p.pagine_totali(), 6);
    }

    #[test]
    fn contenuto_delle_pagine() {
        let (d, _) = tipico();
        let p = pianifica(&d).unwrap();
        let mut pg = [0xaau8; 4096];
        // codice: pagina 0 intera dal file, pagina 1 fino a 0x805 poi zeri
        riempi_pagina(&d, &p.segmenti()[0], 0, &mut pg);
        assert_eq!(&pg[..], &d[0x1000..0x2000]);
        riempi_pagina(&d, &p.segmenti()[0], 1, &mut pg);
        assert_eq!(&pg[..0x805], &d[0x2000..0x2805]);
        assert!(pg[0x805..].iter().all(|&b| b == 0));
        // dati: 0xc8 byte dal file, poi .bss azzerata, pagine successive tutte zero
        let dati = p.segmenti()[2];
        riempi_pagina(&d, &dati, 0, &mut pg);
        assert_eq!(&pg[..0xc8], &d[0x4000..0x40c8]);
        assert!(pg[0xc8..].iter().all(|&b| b == 0));
        for k in 1..dati.pagine {
            pg.fill(0xaa);
            riempi_pagina(&d, &dati, k, &mut pg);
            assert!(pg.iter().all(|&b| b == 0));
        }
        // pagina oltre il segmento: zeri
        pg.fill(0xaa);
        riempi_pagina(&d, &dati, dati.pagine, &mut pg);
        assert!(pg.iter().all(|&b| b == 0));
    }

    #[test]
    fn segmento_non_allineato_alla_pagina() {
        // inizio a metà pagina: i byte vanno all'offset giusto, il resto è zero
        let ph = [carico(PF_R | PF_X, 0x1234, 0x40_0234, 0x100, 0x100)];
        let d = costruisci(0x40_0234, &ph, 0x2000);
        let p = pianifica(&d).unwrap();
        let s = p.segmenti()[0];
        assert_eq!((s.prima_pagina, s.pagine), (0x40_0000, 1));
        let mut pg = [0xaau8; 4096];
        riempi_pagina(&d, &s, 0, &mut pg);
        assert!(pg[..0x234].iter().all(|&b| b == 0));
        assert_eq!(&pg[0x234..0x334], &d[0x1234..0x1334]);
        assert!(pg[0x334..].iter().all(|&b| b == 0));
        // a cavallo di due pagine
        let ph = [carico(PF_R | PF_X, 0x1f00, 0x40_0f00, 0x200, 0x200)];
        let d = costruisci(0x40_0f00, &ph, 0x3000);
        let s = pianifica(&d).unwrap().segmenti()[0];
        assert_eq!(s.pagine, 2);
        riempi_pagina(&d, &s, 1, &mut pg);
        assert_eq!(&pg[..0x100], &d[0x2000..0x2100]);
        assert!(pg[0x100..].iter().all(|&b| b == 0));
    }

    #[test]
    fn segmenti_vuoti_e_non_caricabili_ignorati() {
        let ph = [
            carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x10, 0x10),
            carico(PF_R | PF_W, 0x1000, 0x40_1000, 0, 0), // vuoto
            Ph { tipo: 4, permessi: PF_R, offset: 0x1000, virtuale: 0, dim_file: 8, dim_memoria: 8, allineamento: 4 }, // PT_NOTE
        ];
        assert_eq!(con(&ph, 0x40_0000).unwrap().numero, 1);
    }

    #[test]
    fn errori_di_formato() {
        let (d, _) = tipico();
        let mut x = d.clone();
        x[0] = 0;
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::Elf(ErroreElf::MagiaErrata)));
        let mut x = d.clone();
        x[4] = 1; // ELF a 32 bit
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::Elf(ErroreElf::NonElf64)));
        let mut x = d.clone();
        x[5] = 2; // big-endian
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::Elf(ErroreElf::NonLittleEndian)));
        let mut x = d.clone();
        x[18] = 0xb7; // AArch64
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::Elf(ErroreElf::NonX86_64)));
        let mut x = d.clone();
        x[16] = 3; // ET_DYN (PIE o libreria)
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::Elf(ErroreElf::NonEseguibile)));
        let mut x = d.clone();
        x[6] = 0;
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::VersioneElf));
        let mut x = d.clone();
        x[20] = 2;
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::VersioneElf));
        let mut x = d.clone();
        x[7] = 3; // ABI Linux
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::AbiNonSupportata));
        assert_eq!(pianifica(&d[..40]).err(), Some(ErroreCaricamento::Elf(ErroreElf::TroppoCorto)));
        // file troncato: un segmento esce dal file
        assert_eq!(pianifica(&d[..0x4050]).err(), Some(ErroreCaricamento::Elf(ErroreElf::SegmentoFuoriFile)));
        // intestazioni di programma fuori dal file
        let mut x = d.clone();
        x[32..40].copy_from_slice(&0x10_0000u64.to_le_bytes());
        assert_eq!(pianifica(&x).err(), Some(ErroreCaricamento::Elf(ErroreElf::IntestazioniFuoriFile)));
    }

    #[test]
    fn eseguibili_non_statici_rifiutati() {
        let base = carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x10, 0x10);
        let altro = |tipo, permessi| Ph { tipo, permessi, offset: 0x1000, virtuale: 0x40_0000, dim_file: 0x10, dim_memoria: 0x10, allineamento: 1 };
        assert_eq!(con(&[base, altro(PT_INTERP, PF_R)], 0x40_0000).err(), Some(ErroreCaricamento::Interprete));
        assert_eq!(con(&[base, altro(PT_DYNAMIC, PF_R)], 0x40_0000).err(), Some(ErroreCaricamento::Dinamico));
        assert_eq!(con(&[base, altro(PT_TLS, PF_R)], 0x40_0000).err(), Some(ErroreCaricamento::Tls));
        assert_eq!(con(&[base, altro(PT_GNU_STACK, PF_R | PF_W | PF_X)], 0x40_0000).err(), Some(ErroreCaricamento::StackEseguibile));
        assert!(con(&[base, altro(PT_GNU_STACK, PF_R | PF_W)], 0x40_0000).is_ok());
    }

    #[test]
    fn segmenti_e_limiti() {
        let codice = carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x10, 0x10);
        // nessun segmento caricabile
        assert_eq!(con(&[], 0x40_0000).err(), Some(ErroreCaricamento::NessunSegmento));
        assert_eq!(con(&[carico(PF_R, 0x1000, 0x40_0000, 0, 0)], 0x40_0000).err(), Some(ErroreCaricamento::NessunSegmento));
        // troppi segmenti
        let molti: Vec<Ph> = (0..9).map(|i| carico(PF_R | PF_X, 0x1000, 0x40_0000 + i * 0x1000, 0x10, 0x10)).collect();
        assert_eq!(con(&molti, 0x40_0000).err(), Some(ErroreCaricamento::TroppiSegmenti));
        assert!(con(&molti[..8], 0x40_0000).is_ok());
        // allineamento non potenza di 2, o indirizzo e offset non congruenti
        let mut a = codice;
        a.allineamento = 0x1800;
        assert_eq!(con(&[a], 0x40_0000).err(), Some(ErroreCaricamento::AllineamentoNonValido(0)));
        let mut a = codice;
        a.offset = 0x1010;
        assert_eq!(con(&[a], 0x40_0000).err(), Some(ErroreCaricamento::AllineamentoNonValido(0)));
        // fuori dallo spazio dei programmi: pagina nulla, sotto 4 MiB, kernel, oltre il limite, traboccamento
        assert_eq!(con(&[carico(PF_R | PF_X, 0x1000, 0, 0x10, 0x10)], 0).err(), Some(ErroreCaricamento::FuoriSpazioUtente(0)));
        assert_eq!(con(&[carico(PF_R | PF_X, 0x1000, 0x1000, 0x10, 0x10)], 0x1000).err(), Some(ErroreCaricamento::FuoriSpazioUtente(0)));
        let k = 0xffff_ffff_8000_0000;
        assert_eq!(con(&[carico(PF_R | PF_X, 0x1000, k, 0x10, 0x10)], k).err(), Some(ErroreCaricamento::FuoriSpazioUtente(0)));
        let l = abi::LIMITE_IMMAGINE - 0x1000;
        assert!(con(&[carico(PF_R | PF_X, 0x1000, l, 0x10, 0x1000)], l).is_ok());
        assert_eq!(con(&[carico(PF_R | PF_X, 0x1000, l, 0x10, 0x1001)], l).err(), Some(ErroreCaricamento::FuoriSpazioUtente(0)));
        let mut t = carico(PF_R | PF_X, 0x1000, 0xffff_ffff_ffff_f000, 0x10, 0x2000);
        t.allineamento = 0;
        assert!(matches!(
            con(&[t], 0x40_0000).err(),
            Some(ErroreCaricamento::Elf(ErroreElf::SegmentoIncoerente)) | Some(ErroreCaricamento::FuoriSpazioUtente(0))
        ));
        // immagine troppo grande (memoria oltre il limite di pagine, senza file corrispondente)
        let grande = carico(PF_R | PF_W, 0x2000, 0x50_0000, 0x10, (MAX_PAGINE_IMMAGINE + 1) * PAGINA);
        assert_eq!(con(&[codice, grande], 0x40_0000).err(), Some(ErroreCaricamento::TroppaMemoria));
        let giusto = carico(PF_R | PF_W, 0x2000, 0x50_0000, 0x10, (MAX_PAGINE_IMMAGINE - 1) * PAGINA);
        assert!(con(&[codice, giusto], 0x40_0000).is_ok());
    }

    #[test]
    fn permessi_w_xor_x() {
        assert_eq!(con(&[carico(PF_R | PF_W | PF_X, 0x1000, 0x40_0000, 0x10, 0x10)], 0x40_0000).err(), Some(ErroreCaricamento::ScrivibileEdEseguibile(0)));
        assert_eq!(con(&[carico(PF_W | PF_X, 0x1000, 0x40_0000, 0x10, 0x10)], 0x40_0000).err(), Some(ErroreCaricamento::ScrivibileEdEseguibile(0)));
        // il secondo segmento viola W^X: indice corretto nell'errore
        let ph = [carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x10, 0x10), carico(PF_R | PF_W | PF_X, 0x2000, 0x40_1000, 0x10, 0x10)];
        assert_eq!(con(&ph, 0x40_0000).err(), Some(ErroreCaricamento::ScrivibileEdEseguibile(1)));
    }

    #[test]
    fn sovrapposizioni() {
        // codice e dati nella stessa pagina (permessi incompatibili sulla stessa pagina)
        let ph = [carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x800, 0x800), carico(PF_R | PF_W, 0x1800, 0x40_0800, 0x10, 0x10)];
        assert_eq!(con(&ph, 0x40_0000).err(), Some(ErroreCaricamento::Sovrapposizione(0, 1)));
        // stesso intervallo, o un segmento dentro l'altro
        let ph = [carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x10, 0x3000), carico(PF_R, 0x2000, 0x40_2000, 0x10, 0x10)];
        assert_eq!(con(&ph, 0x40_0000).err(), Some(ErroreCaricamento::Sovrapposizione(0, 1)));
        // pagine adiacenti: ammesse
        let ph = [carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x10, 0x1000), carico(PF_R | PF_W, 0x2000, 0x40_1000, 0x10, 0x10)];
        assert!(con(&ph, 0x40_0000).is_ok());
        // ordine inverso nel file: rilevata comunque
        let ph = [carico(PF_R | PF_W, 0x2000, 0x40_1000, 0x10, 0x10), carico(PF_R | PF_X, 0x1000, 0x40_0000, 0x10, 0x1800)];
        assert_eq!(con(&ph, 0x40_0000).err(), Some(ErroreCaricamento::Sovrapposizione(0, 1)));
    }

    #[test]
    fn punto_d_ingresso() {
        let (d, ph) = tipico();
        let _ = d;
        // nei dati (non eseguibili), nelle costanti, fuori da tutto, subito dopo la fine del codice
        assert_eq!(con(&ph, 0x40_3000).err(), Some(ErroreCaricamento::IngressoNonEseguibile));
        assert_eq!(con(&ph, 0x40_2000).err(), Some(ErroreCaricamento::IngressoNonEseguibile));
        assert_eq!(con(&ph, 0).err(), Some(ErroreCaricamento::IngressoNonEseguibile));
        assert_eq!(con(&ph, 0x40_1805).err(), Some(ErroreCaricamento::IngressoNonEseguibile));
        assert!(con(&ph, 0x40_1804).is_ok());
        assert!(con(&ph, 0x40_0000).is_ok());
    }

    #[test]
    fn mai_panico_su_dati_alterati() {
        // fuzzing deterministico: qualsiasi alterazione dà un piano coerente o un errore
        let (base, _) = tipico();
        let mut x: u64 = 0x2545_F491_4F6C_DD1D;
        let mut validi = 0;
        let mut pg = [0u8; 4096];
        for _ in 0..30_000 {
            let mut d = base.clone();
            for _ in 0..3 {
                x ^= x << 13;
                x ^= x >> 7;
                x ^= x << 17;
                // alterazioni concentrate su intestazioni ed intestazioni di programma
                let i = (x as usize) % (64 + 56 * 4);
                d[i] = (x >> 32) as u8;
            }
            if let Ok(p) = pianifica(&d) {
                validi += 1;
                assert!(p.numero >= 1 && p.pagine_totali() <= MAX_PAGINE_IMMAGINE);
                for s in p.segmenti() {
                    assert!(!(s.scrivibile && s.eseguibile));
                    assert!(abi::intervallo_utente(s.prima_pagina, s.pagine * PAGINA) && s.fine() <= abi::LIMITE_IMMAGINE);
                    for k in 0..s.pagine.min(4) {
                        riempi_pagina(&d, s, k, &mut pg);
                    }
                }
            }
        }
        assert!(validi > 0, "nessuna variante valida: il fuzzing non esercita il caso positivo");
    }
}
