// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Informazioni che OMNI Boot passa al kernel (formato versionato, `repr(C)`).
//!
//! OMNI Boot riempie la struttura prima di `ExitBootServices` e ne passa l'indirizzo
//! virtuale (nella mappa diretta della memoria fisica) al punto d'ingresso del kernel.

/// "OMNIBOOT" in ASCII.
pub const MAGIA: u64 = u64::from_be_bytes(*b"OMNIBOOT");
/// Versione del formato: va incrementata a ogni modifica incompatibile.
pub const VERSIONE: u32 = 2;
/// Numero massimo di regioni di memoria trasmesse.
pub const MAX_REGIONI: usize = 512;
/// Inizio della mappa diretta della memoria fisica nello spazio del kernel.
pub const OFFSET_MAPPA_FISICA: u64 = 0xffff_8000_0000_0000;
/// Dimensione di una pagina.
pub const PAGINA: u64 = 4096;

/// Uso di una regione di memoria fisica, tradotto dai tipi UEFI.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TipoMemoria {
    /// Utilizzabile dal kernel (memoria convenzionale e dei servizi di avvio UEFI).
    Libera = 1,
    /// Riservata dal firmware o non utilizzabile.
    Riservata = 2,
    /// Tabelle ACPI recuperabili dopo la lettura.
    AcpiRecuperabile = 3,
    /// Memoria non volatile ACPI: da non toccare.
    AcpiNvs = 4,
    /// Strutture di OMNI Boot ancora in uso (tabelle di pagine iniziali, BootInfo).
    Caricatore = 5,
    /// Segmenti del kernel.
    Kernel = 6,
    /// Registri di dispositivi mappati in memoria.
    Mmio = 7,
    /// Memoria segnalata difettosa.
    Difettosa = 8,
    /// Pacchetto iniziale dei programmi utente (K3): resta in memoria, in sola lettura.
    Pacchetto = 9,
}

/// Una regione contigua di memoria fisica.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct RegioneMemoria {
    pub inizio: u64,
    pub pagine: u64,
    pub tipo: TipoMemoria,
    pub _riservato: u32,
}

impl RegioneMemoria {
    pub const VUOTA: Self = Self { inizio: 0, pagine: 0, tipo: TipoMemoria::Riservata, _riservato: 0 };
    pub fn fine(&self) -> u64 {
        self.inizio + self.pagine * PAGINA
    }
}

/// Formato dei pixel del framebuffer.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FormatoPixel {
    /// Byte in memoria: rosso, verde, blu, riservato.
    Rgb = 0,
    /// Byte in memoria: blu, verde, rosso, riservato.
    Bgr = 1,
}

/// Framebuffer lineare fornito dal firmware (UEFI GOP).
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Framebuffer {
    pub fisico: u64,
    pub dimensione: u64,
    pub larghezza: u32,
    pub altezza: u32,
    /// Pixel per riga (può essere maggiore della larghezza).
    pub passo: u32,
    pub formato: FormatoPixel,
}

/// Informazioni di avvio.
#[repr(C)]
pub struct BootInfo {
    pub magia: u64,
    pub versione: u32,
    pub revisione_uefi: u32,
    /// Offset della mappa diretta: indirizzo virtuale = fisico + offset.
    pub offset_mappa_fisica: u64,
    /// Indirizzo fisico della RSDP ACPI (0 se assente).
    pub rsdp: u64,
    pub framebuffer: Framebuffer,
    /// SHA-256 del file del kernel letto dal disco.
    pub sha256_kernel: [u8; 32],
    /// Fornitore del firmware (ASCII, terminato da zero).
    pub fornitore_firmware: [u8; 64],
    /// Pacchetto iniziale (K3): indirizzo fisico e lunghezza (0 se assente) e SHA-256 del file.
    pub pacchetto_fisico: u64,
    pub pacchetto_lunghezza: u64,
    pub sha256_pacchetto: [u8; 32],
    pub num_regioni: u32,
    pub _riservato: u32,
    pub regioni: [RegioneMemoria; MAX_REGIONI],
}

impl BootInfo {
    pub fn valido(&self) -> bool {
        self.magia == MAGIA && self.versione == VERSIONE && (self.num_regioni as usize) <= MAX_REGIONI
    }
    pub fn regioni(&self) -> &[RegioneMemoria] {
        &self.regioni[..(self.num_regioni as usize).min(MAX_REGIONI)]
    }
    pub fn fornitore(&self) -> &str {
        let n = self.fornitore_firmware.iter().position(|&b| b == 0).unwrap_or(self.fornitore_firmware.len());
        core::str::from_utf8(&self.fornitore_firmware[..n]).unwrap_or("?")
    }
}

/// Converte un tipo di memoria UEFI (specifica UEFI 2.10, tabella 7.10) nel tipo OMNI.
/// `kernel` e `caricatore` sono i tipi personalizzati con cui OMNI Boot marca le proprie
/// allocazioni (intervallo 0x80000000–0xFFFFFFFF riservato ai sistemi operativi).
pub fn da_tipo_uefi(t: u32) -> TipoMemoria {
    match t {
        // EfiLoaderCode e EfiLoaderData: il codice di OMNI Boot e i dati ancora in uso
        1 | 2 => TipoMemoria::Caricatore,
        // EfiBootServicesCode/Data, EfiConventionalMemory: liberi dopo ExitBootServices
        3 | 4 | 7 => TipoMemoria::Libera,
        8 => TipoMemoria::Difettosa,
        9 => TipoMemoria::AcpiRecuperabile,
        10 => TipoMemoria::AcpiNvs,
        11 | 12 => TipoMemoria::Mmio,
        TIPO_UEFI_KERNEL => TipoMemoria::Kernel,
        TIPO_UEFI_CARICATORE => TipoMemoria::Caricatore,
        TIPO_UEFI_PACCHETTO => TipoMemoria::Pacchetto,
        _ => TipoMemoria::Riservata,
    }
}

/// Tipo di memoria UEFI usato per i segmenti del kernel.
pub const TIPO_UEFI_KERNEL: u32 = 0x8000_0001;
/// Tipo di memoria UEFI usato per tabelle di pagine iniziali e BootInfo.
pub const TIPO_UEFI_CARICATORE: u32 = 0x8000_0002;
/// Tipo di memoria UEFI usato per il pacchetto iniziale (K3).
pub const TIPO_UEFI_PACCHETTO: u32 = 0x8000_0003;

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn magia_e_tipi() {
        assert_eq!(&MAGIA.to_be_bytes(), b"OMNIBOOT");
        assert_eq!(da_tipo_uefi(7), TipoMemoria::Libera);
        assert_eq!(da_tipo_uefi(4), TipoMemoria::Libera);
        assert_eq!(da_tipo_uefi(2), TipoMemoria::Caricatore);
        assert_eq!(da_tipo_uefi(TIPO_UEFI_KERNEL), TipoMemoria::Kernel);
        assert_eq!(da_tipo_uefi(TIPO_UEFI_PACCHETTO), TipoMemoria::Pacchetto);
        assert_eq!(da_tipo_uefi(10), TipoMemoria::AcpiNvs);
        assert_eq!(da_tipo_uefi(0), TipoMemoria::Riservata);
        let r = RegioneMemoria { inizio: 0x1000, pagine: 2, tipo: TipoMemoria::Libera, _riservato: 0 };
        assert_eq!(r.fine(), 0x3000);
    }

    #[test]
    fn dimensione_stabile() {
        // la struttura attraversa il confine fra due binari: dimensione controllata
        assert_eq!(core::mem::size_of::<RegioneMemoria>(), 24);
        assert_eq!(core::mem::size_of::<Framebuffer>(), 32);
    }
}
