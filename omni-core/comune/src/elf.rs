// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Lettura (solo verifica e intestazioni di programma) di file ELF64 per x86-64.
//! Specifica: System V ABI, "ELF-64 Object File Format" 1.5.

/// Errori di verifica del file.
#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum ErroreElf {
    TroppoCorto,
    MagiaErrata,
    NonElf64,
    NonLittleEndian,
    NonX86_64,
    NonEseguibile,
    IntestazioniFuoriFile,
    SegmentoFuoriFile,
    SegmentoIncoerente,
}

impl ErroreElf {
    pub fn descrizione(&self) -> &'static str {
        match self {
            Self::TroppoCorto => "file troppo corto",
            Self::MagiaErrata => "firma ELF assente",
            Self::NonElf64 => "non e' un ELF a 64 bit",
            Self::NonLittleEndian => "non little-endian",
            Self::NonX86_64 => "macchina diversa da x86-64",
            Self::NonEseguibile => "non e' un eseguibile",
            Self::IntestazioniFuoriFile => "intestazioni di programma fuori dal file",
            Self::SegmentoFuoriFile => "segmento fuori dal file",
            Self::SegmentoIncoerente => "segmento con dimensioni incoerenti",
        }
    }
}

pub const PT_LOAD: u32 = 1;
pub const PF_X: u32 = 1;
pub const PF_W: u32 = 2;
pub const PF_R: u32 = 4;

/// Intestazione di programma (solo i campi usati).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Segmento {
    pub tipo: u32,
    pub permessi: u32,
    pub offset: u64,
    pub virtuale: u64,
    pub dim_file: u64,
    pub dim_memoria: u64,
    pub allineamento: u64,
}

impl Segmento {
    pub fn eseguibile(&self) -> bool {
        self.permessi & PF_X != 0
    }
    pub fn scrivibile(&self) -> bool {
        self.permessi & PF_W != 0
    }
}

/// Vista verificata di un file ELF64.
pub struct Elf<'a> {
    dati: &'a [u8],
    pub ingresso: u64,
    phoff: usize,
    phentsize: usize,
    phnum: usize,
}

fn u16_le(d: &[u8], o: usize) -> u16 {
    u16::from_le_bytes([d[o], d[o + 1]])
}
fn u32_le(d: &[u8], o: usize) -> u32 {
    u32::from_le_bytes([d[o], d[o + 1], d[o + 2], d[o + 3]])
}
fn u64_le(d: &[u8], o: usize) -> u64 {
    let mut b = [0u8; 8];
    b.copy_from_slice(&d[o..o + 8]);
    u64::from_le_bytes(b)
}

impl<'a> Elf<'a> {
    /// Verifica intestazione, intestazioni di programma e segmenti caricabili.
    pub fn verifica(dati: &'a [u8]) -> Result<Self, ErroreElf> {
        if dati.len() < 64 {
            return Err(ErroreElf::TroppoCorto);
        }
        if &dati[0..4] != b"\x7fELF" {
            return Err(ErroreElf::MagiaErrata);
        }
        if dati[4] != 2 {
            return Err(ErroreElf::NonElf64);
        }
        if dati[5] != 1 {
            return Err(ErroreElf::NonLittleEndian);
        }
        if u16_le(dati, 18) != 0x3e {
            return Err(ErroreElf::NonX86_64);
        }
        if u16_le(dati, 16) != 2 {
            return Err(ErroreElf::NonEseguibile);
        }
        let e =
            Elf { dati, ingresso: u64_le(dati, 24), phoff: u64_le(dati, 32) as usize, phentsize: u16_le(dati, 54) as usize, phnum: u16_le(dati, 56) as usize };
        let fine = e.phentsize.checked_mul(e.phnum).and_then(|n| n.checked_add(e.phoff)).ok_or(ErroreElf::IntestazioniFuoriFile)?;
        if e.phentsize < 56 || fine > dati.len() {
            return Err(ErroreElf::IntestazioniFuoriFile);
        }
        for s in e.segmenti() {
            if s.tipo != PT_LOAD {
                continue;
            }
            if s.dim_file > s.dim_memoria {
                return Err(ErroreElf::SegmentoIncoerente);
            }
            let f = s.offset.checked_add(s.dim_file).ok_or(ErroreElf::SegmentoFuoriFile)?;
            if f > dati.len() as u64 {
                return Err(ErroreElf::SegmentoFuoriFile);
            }
            if s.virtuale.checked_add(s.dim_memoria).is_none() {
                return Err(ErroreElf::SegmentoIncoerente);
            }
        }
        Ok(e)
    }

    pub fn segmento(&self, i: usize) -> Segmento {
        let o = self.phoff + i * self.phentsize;
        let d = self.dati;
        Segmento {
            tipo: u32_le(d, o),
            permessi: u32_le(d, o + 4),
            offset: u64_le(d, o + 8),
            virtuale: u64_le(d, o + 16),
            dim_file: u64_le(d, o + 32),
            dim_memoria: u64_le(d, o + 40),
            allineamento: u64_le(d, o + 48),
        }
    }

    pub fn segmenti(&self) -> impl Iterator<Item = Segmento> + '_ {
        (0..self.phnum).map(move |i| self.segmento(i))
    }

    /// Byte del segmento presenti nel file.
    pub fn contenuto(&self, s: &Segmento) -> &'a [u8] {
        &self.dati[s.offset as usize..(s.offset + s.dim_file) as usize]
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use std::vec::Vec;

    /// ELF minimo costruito a mano: intestazione + 1 segmento PT_LOAD.
    fn esempio() -> Vec<u8> {
        let mut d = std::vec![0u8; 64 + 56 + 16];
        d[0..4].copy_from_slice(b"\x7fELF");
        d[4] = 2;
        d[5] = 1;
        d[6] = 1;
        d[16..18].copy_from_slice(&2u16.to_le_bytes());
        d[18..20].copy_from_slice(&0x3eu16.to_le_bytes());
        d[24..32].copy_from_slice(&0xffff_ffff_8000_0000u64.to_le_bytes());
        d[32..40].copy_from_slice(&64u64.to_le_bytes());
        d[54..56].copy_from_slice(&56u16.to_le_bytes());
        d[56..58].copy_from_slice(&1u16.to_le_bytes());
        let p = 64;
        d[p..p + 4].copy_from_slice(&PT_LOAD.to_le_bytes());
        d[p + 4..p + 8].copy_from_slice(&(PF_R | PF_X).to_le_bytes());
        d[p + 8..p + 16].copy_from_slice(&120u64.to_le_bytes());
        d[p + 16..p + 24].copy_from_slice(&0xffff_ffff_8000_0000u64.to_le_bytes());
        d[p + 32..p + 40].copy_from_slice(&16u64.to_le_bytes());
        d[p + 40..p + 48].copy_from_slice(&4096u64.to_le_bytes());
        d[120..136].copy_from_slice(&[0xC3; 16]);
        d
    }

    #[test]
    fn valido() {
        let d = esempio();
        let e = Elf::verifica(&d).unwrap();
        assert_eq!(e.ingresso, 0xffff_ffff_8000_0000);
        let s: Vec<_> = e.segmenti().collect();
        assert_eq!(s.len(), 1);
        assert!(s[0].eseguibile() && !s[0].scrivibile());
        assert_eq!(e.contenuto(&s[0]), &[0xC3; 16]);
    }

    #[test]
    fn errori() {
        let mut d = esempio();
        d[0] = 0;
        assert_eq!(Elf::verifica(&d).err(), Some(ErroreElf::MagiaErrata));
        let mut d = esempio();
        d[18] = 0x28; // ARM
        assert_eq!(Elf::verifica(&d).err(), Some(ErroreElf::NonX86_64));
        let mut d = esempio();
        d[64 + 32..64 + 40].copy_from_slice(&1000u64.to_le_bytes()); // oltre la fine del file
        assert_eq!(Elf::verifica(&d).err(), Some(ErroreElf::SegmentoFuoriFile));
        let mut d = esempio();
        d[64 + 40..64 + 48].copy_from_slice(&8u64.to_le_bytes()); // memoria < file
        assert_eq!(Elf::verifica(&d).err(), Some(ErroreElf::SegmentoIncoerente));
        let mut d = esempio();
        d[56..58].copy_from_slice(&u16::MAX.to_le_bytes());
        assert_eq!(Elf::verifica(&d).err(), Some(ErroreElf::IntestazioniFuoriFile));
        assert_eq!(Elf::verifica(&[0u8; 10]).err(), Some(ErroreElf::TroppoCorto));
    }

    #[test]
    fn mai_panico_su_dati_casuali() {
        // fuzzing deterministico leggero: nessun input deve provocare un panico
        let base = esempio();
        let mut x: u64 = 0x9E37_79B9_7F4A_7C15;
        for _ in 0..20_000 {
            let mut d = base.clone();
            for _ in 0..4 {
                x ^= x << 13;
                x ^= x >> 7;
                x ^= x << 17;
                let i = (x as usize) % d.len();
                d[i] = (x >> 32) as u8;
            }
            if let Ok(e) = Elf::verifica(&d) {
                for s in e.segmenti().filter(|s| s.tipo == PT_LOAD) {
                    let _ = e.contenuto(&s);
                }
            }
        }
    }
}
