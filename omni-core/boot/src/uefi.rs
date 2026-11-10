// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Binding UEFI originali di OMNI Boot: solo le strutture e le funzioni usate, scritte dalla
//! specifica UEFI 2.10 (capitoli 4, 7, 9, 12, 13). Nessun crate esterno (ADR-0011).

use core::ffi::c_void;

pub type Handle = *mut c_void;
pub type Status = usize;
pub const SUCCESS: Status = 0;
/// Bit alto: codice di errore.
pub const ERRORE: Status = 1 << 63;
pub const LOAD_ERROR: Status = ERRORE | 1;
pub const NOT_FOUND: Status = ERRORE | 14;

pub fn errore(s: Status) -> bool {
    s & ERRORE != 0
}

#[repr(C)]
#[derive(Clone, Copy, PartialEq, Eq)]
pub struct Guid(pub u32, pub u16, pub u16, pub [u8; 8]);

pub const GUID_IMMAGINE_CARICATA: Guid = Guid(0x5b1b31a1, 0x9562, 0x11d2, [0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b]);
pub const GUID_FILE_SYSTEM_SEMPLICE: Guid = Guid(0x964e5b22, 0x6459, 0x11d2, [0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b]);
pub const GUID_GOP: Guid = Guid(0x9042a9de, 0x23dc, 0x4a38, [0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a]);
pub const GUID_ACPI_20: Guid = Guid(0x8868e871, 0xe4f1, 0x11d3, [0xbc, 0x22, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81]);

#[repr(C)]
pub struct IntestazioneTabella {
    pub firma: u64,
    pub revisione: u32,
    pub dimensione: u32,
    pub crc32: u32,
    pub _riservato: u32,
}

#[repr(C)]
pub struct VoceConfigurazione {
    pub guid: Guid,
    pub tabella: *mut c_void,
}

#[repr(C)]
pub struct TabellaSistema {
    pub intestazione: IntestazioneTabella,
    pub fornitore: *const u16,
    pub revisione_firmware: u32,
    pub handle_ingresso: Handle,
    pub ingresso: *mut c_void,
    pub handle_uscita: Handle,
    pub uscita: *mut c_void,
    pub handle_errori: Handle,
    pub errori: *mut c_void,
    pub servizi_runtime: *mut c_void,
    pub servizi_avvio: *mut ServiziAvvio,
    pub numero_voci: usize,
    pub configurazione: *mut VoceConfigurazione,
}

type Inutilizzata = usize;

/// EFI_BOOT_SERVICES fino a LocateProtocol (ordine della specifica, tabella 4.4).
#[repr(C)]
pub struct ServiziAvvio {
    pub intestazione: IntestazioneTabella,
    pub raise_tpl: Inutilizzata,
    pub restore_tpl: Inutilizzata,
    pub allocate_pages: unsafe extern "efiapi" fn(tipo: u32, tipo_memoria: u32, pagine: usize, indirizzo: *mut u64) -> Status,
    pub free_pages: Inutilizzata,
    pub get_memory_map:
        unsafe extern "efiapi" fn(dimensione: *mut usize, mappa: *mut u8, chiave: *mut usize, dim_descrittore: *mut usize, versione: *mut u32) -> Status,
    pub allocate_pool: unsafe extern "efiapi" fn(tipo_memoria: u32, dimensione: usize, buffer: *mut *mut u8) -> Status,
    pub free_pool: Inutilizzata,
    pub create_event: Inutilizzata,
    pub set_timer: Inutilizzata,
    pub wait_for_event: Inutilizzata,
    pub signal_event: Inutilizzata,
    pub close_event: Inutilizzata,
    pub check_event: Inutilizzata,
    pub install_protocol_interface: Inutilizzata,
    pub reinstall_protocol_interface: Inutilizzata,
    pub uninstall_protocol_interface: Inutilizzata,
    pub handle_protocol: unsafe extern "efiapi" fn(handle: Handle, guid: *const Guid, interfaccia: *mut *mut c_void) -> Status,
    pub _riservato: Inutilizzata,
    pub register_protocol_notify: Inutilizzata,
    pub locate_handle: Inutilizzata,
    pub locate_device_path: Inutilizzata,
    pub install_configuration_table: Inutilizzata,
    pub load_image: Inutilizzata,
    pub start_image: Inutilizzata,
    pub exit: Inutilizzata,
    pub unload_image: Inutilizzata,
    pub exit_boot_services: unsafe extern "efiapi" fn(immagine: Handle, chiave: usize) -> Status,
    pub get_next_monotonic_count: Inutilizzata,
    pub stall: unsafe extern "efiapi" fn(microsecondi: usize) -> Status,
    pub set_watchdog_timer: unsafe extern "efiapi" fn(secondi: usize, codice: u64, dim: usize, dati: *const u16) -> Status,
    pub connect_controller: Inutilizzata,
    pub disconnect_controller: Inutilizzata,
    pub open_protocol: Inutilizzata,
    pub close_protocol: Inutilizzata,
    pub open_protocol_information: Inutilizzata,
    pub protocols_per_handle: Inutilizzata,
    pub locate_handle_buffer: Inutilizzata,
    pub locate_protocol: unsafe extern "efiapi" fn(guid: *const Guid, registrazione: *mut c_void, interfaccia: *mut *mut c_void) -> Status,
}

pub const ALLOCA_PAGINE_QUALSIASI: u32 = 0;
pub const MEMORIA_DATI_CARICATORE: u32 = 2;

#[repr(C)]
pub struct DescrittoreMemoria {
    pub tipo: u32,
    pub _pad: u32,
    pub fisico: u64,
    pub virtuale: u64,
    pub pagine: u64,
    pub attributi: u64,
}

#[repr(C)]
pub struct ImmagineCaricata {
    pub revisione: u32,
    pub genitore: Handle,
    pub tabella_sistema: *mut TabellaSistema,
    pub dispositivo: Handle,
    // gli altri campi non sono usati
}

#[repr(C)]
pub struct FileSystemSemplice {
    pub revisione: u64,
    pub apri_volume: unsafe extern "efiapi" fn(this: *mut FileSystemSemplice, radice: *mut *mut File) -> Status,
}

#[repr(C)]
pub struct File {
    pub revisione: u64,
    pub apri: unsafe extern "efiapi" fn(this: *mut File, nuovo: *mut *mut File, nome: *const u16, modo: u64, attributi: u64) -> Status,
    pub chiudi: unsafe extern "efiapi" fn(this: *mut File) -> Status,
    pub elimina: Inutilizzata,
    pub leggi: unsafe extern "efiapi" fn(this: *mut File, dimensione: *mut usize, buffer: *mut u8) -> Status,
    pub scrivi: Inutilizzata,
    pub posizione: unsafe extern "efiapi" fn(this: *mut File, posizione: *mut u64) -> Status,
    pub imposta_posizione: unsafe extern "efiapi" fn(this: *mut File, posizione: u64) -> Status,
}
pub const FILE_LETTURA: u64 = 1;

#[repr(C)]
pub struct InfoModo {
    pub versione: u32,
    pub larghezza: u32,
    pub altezza: u32,
    pub formato: u32,
    pub maschere: [u32; 4],
    pub passo: u32,
}
pub const PIXEL_RGB: u32 = 0;
pub const PIXEL_BGR: u32 = 1;

#[repr(C)]
pub struct ModoGop {
    pub massimo: u32,
    pub modo: u32,
    pub info: *mut InfoModo,
    pub dim_info: usize,
    pub framebuffer: u64,
    pub dim_framebuffer: usize,
}

#[repr(C)]
pub struct Gop {
    pub interroga: unsafe extern "efiapi" fn(this: *mut Gop, modo: u32, dim: *mut usize, info: *mut *mut InfoModo) -> Status,
    pub imposta: unsafe extern "efiapi" fn(this: *mut Gop, modo: u32) -> Status,
    pub blt: Inutilizzata,
    pub modo: *mut ModoGop,
}
