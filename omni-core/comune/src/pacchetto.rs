// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Pacchetto iniziale (K3): un file `\OMNI\INIZIALE.PKG` che OMNI Boot carica in memoria
//! insieme al kernel e che contiene i primi programmi utente (file ELF).
//!
//! Formato (tutti i numeri little-endian):
//!
//! | offset | dimensione | contenuto |
//! |---|---|---|
//! | 0 | 8 | magia `OMNIPKG\0` |
//! | 8 | 4 | versione (1) |
//! | 12 | 4 | numero di voci N |
//! | 16 | N × 96 | voci |
//! | ... | | contenuti dei file |
//!
//! Voce (96 byte): nome (32 byte ASCII, completato da zeri), offset del contenuto (8),
//! lunghezza (8), SHA-256 del contenuto (32), riservato (16, zeri).
//!
//! La lettura verifica limiti, nomi e l'impronta SHA-256 di ogni contenuto: un pacchetto
//! alterato viene rifiutato per intero.

use crate::sha256;

pub const MAGIA: [u8; 8] = *b"OMNIPKG\0";
pub const VERSIONE: u32 = 1;
pub const DIM_INTESTAZIONE: usize = 16;
pub const DIM_VOCE: usize = 96;
pub const MAX_NOME: usize = 32;
pub const MAX_VOCI: usize = 64;

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum ErrorePacchetto {
    TroppoCorto,
    MagiaErrata,
    VersioneErrata,
    TroppeVoci,
    NomeNonValido(usize),
    NomeDuplicato(usize),
    FuoriDalFile(usize),
    ImprontaErrata(usize),
    DestinazioneTroppoPiccola,
}

impl ErrorePacchetto {
    pub fn descrizione(&self) -> &'static str {
        match self {
            Self::TroppoCorto => "pacchetto troppo corto",
            Self::MagiaErrata => "firma del pacchetto assente",
            Self::VersioneErrata => "versione del pacchetto non supportata",
            Self::TroppeVoci => "troppe voci",
            Self::NomeNonValido(_) => "nome di voce non valido",
            Self::NomeDuplicato(_) => "nome di voce duplicato",
            Self::FuoriDalFile(_) => "contenuto fuori dal pacchetto",
            Self::ImprontaErrata(_) => "impronta SHA-256 di un contenuto errata",
            Self::DestinazioneTroppoPiccola => "spazio insufficiente per scrivere il pacchetto",
        }
    }
}

fn u32_le(d: &[u8], o: usize) -> u32 {
    u32::from_le_bytes([d[o], d[o + 1], d[o + 2], d[o + 3]])
}
fn u64_le(d: &[u8], o: usize) -> u64 {
    let mut b = [0u8; 8];
    b.copy_from_slice(&d[o..o + 8]);
    u64::from_le_bytes(b)
}

/// Una voce verificata del pacchetto.
#[derive(Clone, Copy)]
pub struct Voce<'a> {
    pub nome: &'a str,
    pub contenuto: &'a [u8],
    pub sha256: [u8; 32],
}

/// Vista verificata di un pacchetto.
#[derive(Clone, Copy)]
pub struct Pacchetto<'a> {
    dati: &'a [u8],
    numero: usize,
}

fn nome_valido(n: &[u8]) -> Option<&str> {
    let fine = n.iter().position(|&b| b == 0).unwrap_or(n.len());
    if fine == 0 || n[fine..].iter().any(|&b| b != 0) {
        return None;
    }
    let s = &n[..fine];
    if !s.iter().all(|&b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.') {
        return None;
    }
    core::str::from_utf8(s).ok()
}

impl<'a> Pacchetto<'a> {
    /// Verifica intestazione, voci e impronte di tutti i contenuti.
    pub fn leggi(dati: &'a [u8]) -> Result<Self, ErrorePacchetto> {
        if dati.len() < DIM_INTESTAZIONE {
            return Err(ErrorePacchetto::TroppoCorto);
        }
        if dati[0..8] != MAGIA {
            return Err(ErrorePacchetto::MagiaErrata);
        }
        if u32_le(dati, 8) != VERSIONE {
            return Err(ErrorePacchetto::VersioneErrata);
        }
        let numero = u32_le(dati, 12) as usize;
        if numero > MAX_VOCI {
            return Err(ErrorePacchetto::TroppeVoci);
        }
        if dati.len() < DIM_INTESTAZIONE + numero * DIM_VOCE {
            return Err(ErrorePacchetto::TroppoCorto);
        }
        let p = Pacchetto { dati, numero };
        for i in 0..numero {
            let o = DIM_INTESTAZIONE + i * DIM_VOCE;
            let nome = nome_valido(&dati[o..o + MAX_NOME]).ok_or(ErrorePacchetto::NomeNonValido(i))?;
            let inizio = u64_le(dati, o + 32);
            let lunghezza = u64_le(dati, o + 40);
            let fine = inizio.checked_add(lunghezza).ok_or(ErrorePacchetto::FuoriDalFile(i))?;
            if inizio < (DIM_INTESTAZIONE + numero * DIM_VOCE) as u64 || fine > dati.len() as u64 {
                return Err(ErrorePacchetto::FuoriDalFile(i));
            }
            let mut atteso = [0u8; 32];
            atteso.copy_from_slice(&dati[o + 48..o + 80]);
            if sha256::sha256(&dati[inizio as usize..fine as usize]) != atteso {
                return Err(ErrorePacchetto::ImprontaErrata(i));
            }
            for j in 0..i {
                if p.voce_grezza(j).0 == nome {
                    return Err(ErrorePacchetto::NomeDuplicato(i));
                }
            }
        }
        Ok(p)
    }

    fn voce_grezza(&self, i: usize) -> (&'a str, &'a [u8], [u8; 32]) {
        let d = self.dati;
        let o = DIM_INTESTAZIONE + i * DIM_VOCE;
        let nome = nome_valido(&d[o..o + MAX_NOME]).unwrap_or("?");
        let inizio = u64_le(d, o + 32) as usize;
        let lunghezza = u64_le(d, o + 40) as usize;
        let mut h = [0u8; 32];
        h.copy_from_slice(&d[o + 48..o + 80]);
        (nome, &d[inizio..inizio + lunghezza], h)
    }

    pub fn numero(&self) -> usize {
        self.numero
    }

    pub fn voce(&self, i: usize) -> Option<Voce<'a>> {
        (i < self.numero).then(|| {
            let (nome, contenuto, sha256) = self.voce_grezza(i);
            Voce { nome, contenuto, sha256 }
        })
    }

    pub fn trova(&self, nome: &str) -> Option<Voce<'a>> {
        (0..self.numero).filter_map(|i| self.voce(i)).find(|v| v.nome == nome)
    }
}

/// Dimensione del pacchetto con queste voci (nome, contenuto).
pub fn dimensione(voci: &[(&str, &[u8])]) -> usize {
    DIM_INTESTAZIONE + voci.len() * DIM_VOCE + voci.iter().map(|v| v.1.len()).sum::<usize>()
}

/// Scrive il pacchetto in `out` (almeno `dimensione(voci)` byte); restituisce i byte scritti.
pub fn scrivi(voci: &[(&str, &[u8])], out: &mut [u8]) -> Result<usize, ErrorePacchetto> {
    let n = dimensione(voci);
    if out.len() < n {
        return Err(ErrorePacchetto::DestinazioneTroppoPiccola);
    }
    if voci.len() > MAX_VOCI {
        return Err(ErrorePacchetto::TroppeVoci);
    }
    out[..n].fill(0);
    out[0..8].copy_from_slice(&MAGIA);
    out[8..12].copy_from_slice(&VERSIONE.to_le_bytes());
    out[12..16].copy_from_slice(&(voci.len() as u32).to_le_bytes());
    let mut pos = DIM_INTESTAZIONE + voci.len() * DIM_VOCE;
    for (i, (nome, contenuto)) in voci.iter().enumerate() {
        let b = nome.as_bytes();
        let mut campo = [0u8; MAX_NOME];
        if b.len() > MAX_NOME {
            return Err(ErrorePacchetto::NomeNonValido(i));
        }
        campo[..b.len()].copy_from_slice(b);
        if nome_valido(&campo).is_none() {
            return Err(ErrorePacchetto::NomeNonValido(i));
        }
        let o = DIM_INTESTAZIONE + i * DIM_VOCE;
        out[o..o + MAX_NOME].copy_from_slice(&campo);
        out[o + 32..o + 40].copy_from_slice(&(pos as u64).to_le_bytes());
        out[o + 40..o + 48].copy_from_slice(&(contenuto.len() as u64).to_le_bytes());
        out[o + 48..o + 80].copy_from_slice(&sha256::sha256(contenuto));
        out[pos..pos + contenuto.len()].copy_from_slice(contenuto);
        pos += contenuto.len();
    }
    Ok(n)
}

#[cfg(test)]
mod test {
    use super::*;
    use std::vec;
    use std::vec::Vec;

    fn crea(voci: &[(&str, &[u8])]) -> Vec<u8> {
        let mut v = vec![0u8; dimensione(voci)];
        scrivi(voci, &mut v).unwrap();
        v
    }

    #[test]
    fn andata_e_ritorno() {
        let d = crea(&[("ciao", b"\x7fELF uno"), ("memoria", b"due"), ("vuoto", b"")]);
        let p = Pacchetto::leggi(&d).unwrap();
        assert_eq!(p.numero(), 3);
        assert_eq!(p.trova("memoria").unwrap().contenuto, b"due");
        assert_eq!(p.trova("vuoto").unwrap().contenuto, b"");
        assert_eq!(p.voce(0).unwrap().nome, "ciao");
        assert_eq!(p.voce(0).unwrap().sha256, sha256::sha256(b"\x7fELF uno"));
        assert!(p.trova("assente").is_none());
        assert!(p.voce(3).is_none());
    }

    #[test]
    fn alterazioni_rifiutate() {
        let d = crea(&[("a", b"contenuto"), ("b", b"altro")]);
        // un byte di contenuto cambiato: impronta errata
        let mut x = d.clone();
        let n = x.len();
        x[n - 1] ^= 1;
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::ImprontaErrata(1)));
        // magia, versione, numero di voci
        let mut x = d.clone();
        x[0] = b'X';
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::MagiaErrata));
        let mut x = d.clone();
        x[8] = 2;
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::VersioneErrata));
        let mut x = d.clone();
        x[12] = 200;
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::TroppeVoci));
        // lunghezza oltre la fine del file
        let mut x = d.clone();
        x[DIM_INTESTAZIONE + 40] = 0xff;
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::FuoriDalFile(0)));
        // offset che punta dentro le intestazioni
        let mut x = d.clone();
        x[DIM_INTESTAZIONE + 32..DIM_INTESTAZIONE + 40].copy_from_slice(&0u64.to_le_bytes());
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::FuoriDalFile(0)));
        // nome con caratteri non ammessi, nome vuoto, nome duplicato
        let mut x = d.clone();
        x[DIM_INTESTAZIONE] = b'/';
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::NomeNonValido(0)));
        let mut x = d.clone();
        x[DIM_INTESTAZIONE] = 0;
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::NomeNonValido(0)));
        let mut x = d.clone();
        x[DIM_INTESTAZIONE + DIM_VOCE] = b'a';
        assert_eq!(Pacchetto::leggi(&x).err(), Some(ErrorePacchetto::NomeDuplicato(1)));
        // file troncato
        assert_eq!(Pacchetto::leggi(&d[..10]).err(), Some(ErrorePacchetto::TroppoCorto));
        assert_eq!(Pacchetto::leggi(&d[..DIM_INTESTAZIONE + 10]).err(), Some(ErrorePacchetto::TroppoCorto));
    }

    #[test]
    fn scrittura_controllata() {
        let mut piccolo = [0u8; 10];
        assert_eq!(scrivi(&[("a", b"x")], &mut piccolo).err(), Some(ErrorePacchetto::DestinazioneTroppoPiccola));
        let mut v = vec![0u8; 1000];
        assert_eq!(scrivi(&[("nome con spazi", b"x")], &mut v).err(), Some(ErrorePacchetto::NomeNonValido(0)));
        let lungo = "n".repeat(40);
        assert_eq!(scrivi(&[(lungo.as_str(), b"x")], &mut v).err(), Some(ErrorePacchetto::NomeNonValido(0)));
    }
}
