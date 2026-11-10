// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! OMNI Boot: applicazione UEFI che carica il kernel OMNI.
//!
//! 1. Legge `\OMNI\KERNEL.ELF` dal volume da cui è stato avviato e ne calcola lo SHA-256;
//!    legge anche il pacchetto iniziale dei programmi utente `\OMNI\INIZIALE.PKG` (K3).
//! 2. Verifica l'ELF e copia i segmenti in pagine fisiche dedicate.
//! 3. Sceglie la modalità grafica (GOP), trova la RSDP ACPI.
//! 4. Costruisce le tabelle di pagine iniziali: identità (solo per il passaggio), mappa
//!    diretta della memoria fisica nella metà alta, segmenti del kernel con permessi W^X.
//! 5. Prende la mappa di memoria, chiama ExitBootServices e salta al kernel.
//!
//! Il registro va sulla porta seriale COM1 (prove automatiche, criterio K1-01).
#![no_std]
#![no_main]

mod seriale;
mod uefi;

use core::ffi::c_void;
use core::fmt::Write;
use omni_comune::bootinfo::{self, BootInfo, FormatoPixel, Framebuffer, RegioneMemoria, TipoMemoria};
use omni_comune::elf::{Elf, PT_LOAD};
use omni_comune::sha256;
use uefi::*;

macro_rules! log {
    ($($a:tt)*) => {{ let _ = writeln!(seriale::Seriale, "[omni-boot] {}", format_args!($($a)*)); }};
}

const PERCORSO_KERNEL: &str = "\\OMNI\\KERNEL.ELF";
const PERCORSO_PACCHETTO: &str = "\\OMNI\\INIZIALE.PKG";
const PAGINA: u64 = 4096;
const DUE_MB: u64 = 2 * 1024 * 1024;
// bit delle voci di tabella delle pagine (Intel SDM vol. 3, 4.5)
const P: u64 = 1;
const RW: u64 = 1 << 1;
const PS: u64 = 1 << 7;
const NX: u64 = 1 << 63;

struct Avvio {
    bs: &'static ServiziAvvio,
}

impl Avvio {
    fn pagine(&self, n: usize, tipo: u32) -> Result<u64, Status> {
        let mut ind = 0u64;
        // SAFETY: servizio di avvio valido finché non si chiama ExitBootServices
        let s = unsafe { (self.bs.allocate_pages)(ALLOCA_PAGINE_QUALSIASI, tipo, n, &mut ind) };
        if errore(s) {
            return Err(s);
        }
        // SAFETY: il firmware ha appena assegnato n pagine a partire da ind (mappa identità)
        unsafe { core::ptr::write_bytes(ind as *mut u8, 0, n * PAGINA as usize) };
        Ok(ind)
    }

    fn protocollo<T>(&self, handle: Handle, guid: &Guid) -> Result<*mut T, Status> {
        let mut p: *mut c_void = core::ptr::null_mut();
        // SAFETY: chiamata documentata; il puntatore restituito appartiene al firmware
        let s = unsafe { (self.bs.handle_protocol)(handle, guid, &mut p) };
        if errore(s) || p.is_null() {
            return Err(if errore(s) { s } else { NOT_FOUND });
        }
        Ok(p as *mut T)
    }
}

/// Legge un intero file del volume di avvio in pagine del tipo indicato. `Ok(None)` se il
/// file non esiste.
fn leggi_file(a: &Avvio, immagine: Handle, percorso: &str, tipo: u32) -> Result<Option<&'static [u8]>, Status> {
    let img: *mut ImmagineCaricata = a.protocollo(immagine, &GUID_IMMAGINE_CARICATA)?;
    // SAFETY: protocollo restituito dal firmware per la nostra immagine
    let dispositivo = unsafe { (*img).dispositivo };
    let fs: *mut FileSystemSemplice = a.protocollo(dispositivo, &GUID_FILE_SYSTEM_SEMPLICE)?;
    let mut radice: *mut File = core::ptr::null_mut();
    let mut nome = [0u16; 32];
    for (i, c) in percorso.encode_utf16().enumerate() {
        nome[i] = c;
    }
    // SAFETY: protocolli del firmware; i puntatori restano validi durante i servizi di avvio
    unsafe {
        let s = ((*fs).apri_volume)(fs, &mut radice);
        if errore(s) {
            return Err(s);
        }
        let mut file: *mut File = core::ptr::null_mut();
        let s = ((*radice).apri)(radice, &mut file, nome.as_ptr(), FILE_LETTURA, 0);
        if errore(s) {
            ((*radice).chiudi)(radice);
            return if s == NOT_FOUND { Ok(None) } else { Err(s) };
        }
        let mut dim = 0u64;
        ((*file).imposta_posizione)(file, u64::MAX);
        ((*file).posizione)(file, &mut dim);
        ((*file).imposta_posizione)(file, 0);
        let pagine = dim.div_ceil(PAGINA) as usize;
        let buf = a.pagine(pagine.max(1), tipo)? as *mut u8;
        let mut letti = dim as usize;
        let s = ((*file).leggi)(file, &mut letti, buf);
        ((*file).chiudi)(file);
        ((*radice).chiudi)(radice);
        if errore(s) || letti as u64 != dim {
            return Err(LOAD_ERROR);
        }
        Ok(Some(core::slice::from_raw_parts(buf, letti)))
    }
}

/// Tabelle di pagine a 4 livelli costruite in memoria fisica (mappa identità di UEFI).
struct Tabelle<'a> {
    a: &'a Avvio,
    pml4: u64,
}

impl Tabelle<'_> {
    fn voce(&self, tabella: u64, indice: u64) -> Result<u64, Status> {
        let p = (tabella + indice * 8) as *mut u64;
        // SAFETY: `tabella` è una pagina allocata da noi, indice < 512
        let v = unsafe { p.read() };
        if v & P != 0 {
            return Ok(v & 0x000f_ffff_ffff_f000);
        }
        let nuova = self.a.pagine(1, bootinfo::TIPO_UEFI_CARICATORE)?;
        // SAFETY: come sopra; le tabelle intermedie sono scrivibili ed eseguibili, i permessi
        // effettivi sono decisi dalla voce finale
        unsafe { p.write(nuova | P | RW) };
        Ok(nuova)
    }

    fn mappa(&self, virt: u64, fis: u64, flag: u64, grande: bool) -> Result<(), Status> {
        let i4 = (virt >> 39) & 511;
        let i3 = (virt >> 30) & 511;
        let i2 = (virt >> 21) & 511;
        let i1 = (virt >> 12) & 511;
        let pdpt = self.voce(self.pml4, i4)?;
        let pd = self.voce(pdpt, i3)?;
        if grande {
            // SAFETY: pagina di tabella nostra
            unsafe { ((pd + i2 * 8) as *mut u64).write(fis | flag | PS | P) };
            return Ok(());
        }
        let pt = self.voce(pd, i2)?;
        // SAFETY: pagina di tabella nostra
        unsafe { ((pt + i1 * 8) as *mut u64).write(fis | flag | P) };
        Ok(())
    }
}

/// Converte i caratteri UCS-2 del fornitore in ASCII.
fn fornitore(st: &TabellaSistema, out: &mut [u8; 64]) {
    let mut p = st.fornitore;
    let mut i = 0;
    while !p.is_null() && i < 63 {
        // SAFETY: stringa terminata da zero fornita dal firmware
        let c = unsafe { p.read() };
        if c == 0 {
            break;
        }
        out[i] = if c < 128 { c as u8 } else { b'?' };
        i += 1;
        // SAFETY: avanzamento entro la stringa (fermo a zero)
        p = unsafe { p.add(1) };
    }
}

fn scegli_grafica(a: &Avvio) -> Option<Framebuffer> {
    let mut gop: *mut c_void = core::ptr::null_mut();
    // SAFETY: chiamata documentata
    let s = unsafe { (a.bs.locate_protocol)(&GUID_GOP, core::ptr::null_mut(), &mut gop) };
    if errore(s) || gop.is_null() {
        log!("grafica: nessun GOP");
        return None;
    }
    let gop = gop as *mut Gop;
    // SAFETY: protocollo GOP valido durante i servizi di avvio
    unsafe {
        let massimo = (*(*gop).modo).massimo;
        let mut scelto = None;
        for m in 0..massimo {
            let mut dim = 0usize;
            let mut info: *mut InfoModo = core::ptr::null_mut();
            if errore(((*gop).interroga)(gop, m, &mut dim, &mut info)) || info.is_null() {
                continue;
            }
            let i = &*info;
            if i.larghezza == 1280 && i.altezza == 800 && (i.formato == PIXEL_RGB || i.formato == PIXEL_BGR) {
                scelto = Some(m);
            }
        }
        if let Some(m) = scelto {
            if errore(((*gop).imposta)(gop, m)) {
                log!("grafica: modo {} non impostato, resta quello corrente", m);
            }
        }
        let modo = &*(*gop).modo;
        let info = &*modo.info;
        let formato = match info.formato {
            PIXEL_RGB => FormatoPixel::Rgb,
            PIXEL_BGR => FormatoPixel::Bgr,
            altro => {
                log!("grafica: formato pixel {} non supportato", altro);
                return None;
            }
        };
        Some(Framebuffer {
            fisico: modo.framebuffer,
            dimensione: modo.dim_framebuffer as u64,
            larghezza: info.larghezza,
            altezza: info.altezza,
            passo: info.passo,
            formato,
        })
    }
}

fn rsdp(st: &TabellaSistema) -> u64 {
    for i in 0..st.numero_voci {
        // SAFETY: tabella di configurazione del firmware con `numero_voci` voci
        let v = unsafe { &*st.configurazione.add(i) };
        if v.guid == GUID_ACPI_20 {
            return v.tabella as u64;
        }
    }
    0
}

#[no_mangle]
extern "efiapi" fn efi_main(immagine: Handle, st: *mut TabellaSistema) -> Status {
    seriale::inizializza();
    // SAFETY: il firmware passa una tabella di sistema valida
    let st = unsafe { &*st };
    // SAFETY: puntatore ai servizi di avvio, valido fino a ExitBootServices
    let a = Avvio { bs: unsafe { &*st.servizi_avvio } };
    // SAFETY: disattiva il watchdog di 5 minuti del firmware
    unsafe { (a.bs.set_watchdog_timer)(0, 0, 0, core::ptr::null()) };
    match avvia(&a, immagine, st) {
        Ok(()) => SUCCESS,
        Err(s) => {
            log!("ERRORE: avvio interrotto (stato {:#x})", s);
            s
        }
    }
}

fn avvia(a: &Avvio, immagine: Handle, st: &TabellaSistema) -> Result<(), Status> {
    let mut forn = [0u8; 64];
    fornitore(st, &mut forn);
    let n = forn.iter().position(|&b| b == 0).unwrap_or(64);
    let rev = st.intestazione.revisione;
    log!("OMNI Boot avviato");
    log!("firmware: {} (revisione {:#x}); UEFI {}.{}", core::str::from_utf8(&forn[..n]).unwrap_or("?"), st.revisione_firmware, rev >> 16, (rev & 0xffff) / 10);

    // 1-2. kernel
    let Some(file) = leggi_file(a, immagine, PERCORSO_KERNEL, MEMORIA_DATI_CARICATORE)? else {
        log!("ERRORE: {} non trovato", PERCORSO_KERNEL);
        return Err(NOT_FOUND);
    };
    let hash = sha256::sha256(file);
    log!("kernel: {} ({} byte) sha256={}", PERCORSO_KERNEL, file.len(), core::str::from_utf8(&sha256::esadecimale(&hash)).unwrap_or("?"));
    let elf = Elf::verifica(file).map_err(|e| {
        log!("ERRORE: kernel non valido: {}", e.descrizione());
        LOAD_ERROR
    })?;

    // pacchetto iniziale (facoltativo): resta in memoria per il kernel, tipo dedicato
    let pacchetto = leggi_file(a, immagine, PERCORSO_PACCHETTO, bootinfo::TIPO_UEFI_PACCHETTO)?;
    let hash_pacchetto = match pacchetto {
        Some(p) => {
            let h = sha256::sha256(p);
            log!("pacchetto iniziale: {} ({} byte) sha256={}", PERCORSO_PACCHETTO, p.len(), core::str::from_utf8(&sha256::esadecimale(&h)).unwrap_or("?"));
            h
        }
        None => {
            log!("pacchetto iniziale: {} assente", PERCORSO_PACCHETTO);
            [0; 32]
        }
    };

    // 3. grafica e ACPI
    let fb = scegli_grafica(a);
    if let Some(f) = &fb {
        log!("grafica: {}x{} passo {} formato {:?} a {:#x}", f.larghezza, f.altezza, f.passo, f.formato, f.fisico);
    }
    let rsdp = rsdp(st);
    log!("ACPI: RSDP a {:#x}", rsdp);

    // 4. tabelle di pagine
    let t = Tabelle { a, pml4: a.pagine(1, bootinfo::TIPO_UEFI_CARICATORE)? };
    for s in elf.segmenti().filter(|s| s.tipo == PT_LOAD && s.dim_memoria > 0) {
        let inizio = s.virtuale & !(PAGINA - 1);
        let fine = (s.virtuale + s.dim_memoria).div_ceil(PAGINA) * PAGINA;
        let pagine = ((fine - inizio) / PAGINA) as usize;
        let fis = a.pagine(pagine, bootinfo::TIPO_UEFI_KERNEL)?;
        // SAFETY: destinazione appena allocata e grande abbastanza; sorgente verificata dal parser
        unsafe {
            core::ptr::copy_nonoverlapping(elf.contenuto(&s).as_ptr(), (fis + (s.virtuale - inizio)) as *mut u8, s.dim_file as usize);
        }
        let flag = if s.scrivibile() { RW } else { 0 } | if s.eseguibile() { 0 } else { NX };
        for p in 0..pagine as u64 {
            t.mappa(inizio + p * PAGINA, fis + p * PAGINA, flag, false)?;
        }
        log!(
            "segmento {:#x}..{:#x} -> fisico {:#x} (R{}{})",
            inizio,
            fine,
            fis,
            if s.scrivibile() { "W" } else { "-" },
            if s.eseguibile() { "X" } else { "-" }
        );
    }
    let info_fis = a.pagine(core::mem::size_of::<BootInfo>().div_ceil(PAGINA as usize), bootinfo::TIPO_UEFI_CARICATORE)?;
    // buffer per la mappa di memoria (ampio: le allocazioni successive la fanno crescere)
    let dim_buffer_mappa = 64 * PAGINA as usize;
    let mappa = a.pagine(64, bootinfo::TIPO_UEFI_CARICATORE)? as *mut u8;

    // estensione della memoria fisica: dalla mappa corrente, più il framebuffer
    let (mut dim, mut chiave, mut dim_desc, mut ver) = (dim_buffer_mappa, 0usize, 0usize, 0u32);
    // SAFETY: buffer nostro di `dim` byte
    let s = unsafe { (a.bs.get_memory_map)(&mut dim, mappa, &mut chiave, &mut dim_desc, &mut ver) };
    if errore(s) {
        return Err(s);
    }
    let mut massimo = 4u64 << 30;
    for i in 0..dim / dim_desc {
        // SAFETY: descrittori nel buffer appena riempito dal firmware
        let d = unsafe { &*(mappa.add(i * dim_desc) as *const DescrittoreMemoria) };
        // solo memoria vera (non registri di dispositivi né aree riservate oltre i 4 GiB)
        if !matches!(bootinfo::da_tipo_uefi(d.tipo), TipoMemoria::Mmio | TipoMemoria::Riservata) {
            massimo = massimo.max(d.fisico + d.pagine * PAGINA);
        }
    }
    if let Some(f) = &fb {
        massimo = massimo.max(f.fisico + f.dimensione);
    }
    let massimo = massimo.div_ceil(DUE_MB) * DUE_MB;
    let mut fis = 0;
    while fis < massimo {
        t.mappa(fis, fis, RW, true)?; // identità: solo per proseguire dopo il cambio di CR3
        t.mappa(bootinfo::OFFSET_MAPPA_FISICA + fis, fis, RW | NX, true)?;
        fis += DUE_MB;
    }
    log!("tabelle di pagine pronte: mappa diretta di {} MiB, PML4 a {:#x}", massimo >> 20, t.pml4);

    // 5. BootInfo e uscita dai servizi di avvio
    let info = info_fis as *mut BootInfo;
    // SAFETY: pagine allocate per BootInfo, azzerate
    let bi = unsafe { &mut *info };
    bi.magia = bootinfo::MAGIA;
    bi.versione = bootinfo::VERSIONE;
    bi.revisione_uefi = rev;
    bi.offset_mappa_fisica = bootinfo::OFFSET_MAPPA_FISICA;
    bi.rsdp = rsdp;
    bi.framebuffer = fb.unwrap_or(Framebuffer { fisico: 0, dimensione: 0, larghezza: 0, altezza: 0, passo: 0, formato: FormatoPixel::Bgr });
    bi.sha256_kernel = hash;
    bi.fornitore_firmware = forn;
    bi.pacchetto_fisico = pacchetto.map(|p| p.as_ptr() as u64).unwrap_or(0);
    bi.pacchetto_lunghezza = pacchetto.map(|p| p.len() as u64).unwrap_or(0);
    bi.sha256_pacchetto = hash_pacchetto;

    let mut tentativi = 0;
    loop {
        let (mut dim, mut chiave, mut dim_desc, mut ver) = (dim_buffer_mappa, 0usize, 0usize, 0u32);
        // SAFETY: buffer nostro; nessuna allocazione fra questa chiamata e ExitBootServices
        let s = unsafe { (a.bs.get_memory_map)(&mut dim, mappa, &mut chiave, &mut dim_desc, &mut ver) };
        if errore(s) {
            return Err(s);
        }
        let mut n = 0usize;
        let mut libere = 0u64;
        for i in 0..dim / dim_desc {
            // SAFETY: descrittori appena scritti dal firmware
            let d = unsafe { &*(mappa.add(i * dim_desc) as *const DescrittoreMemoria) };
            let tipo = bootinfo::da_tipo_uefi(d.tipo);
            if tipo == TipoMemoria::Libera {
                libere += d.pagine;
            }
            // regioni adiacenti dello stesso tipo unite (resta entro MAX_REGIONI)
            if n > 0 {
                let u = &mut bi.regioni[n - 1];
                if u.tipo == tipo && u.fine() == d.fisico {
                    u.pagine += d.pagine;
                    continue;
                }
            }
            if n == bootinfo::MAX_REGIONI {
                break;
            }
            bi.regioni[n] = RegioneMemoria { inizio: d.fisico, pagine: d.pagine, tipo, _riservato: 0 };
            n += 1;
        }
        bi.num_regioni = n as u32;
        if tentativi == 0 {
            log!("mappa di memoria: {} descrittori, {} regioni, {} MiB liberi", dim / dim_desc, n, (libere * PAGINA) >> 20);
            log!("uscita dai servizi di avvio; salto al kernel a {:#x}", elf.ingresso);
        }
        // SAFETY: chiave della mappa appena letta
        let s = unsafe { (a.bs.exit_boot_services)(immagine, chiave) };
        if !errore(s) {
            break;
        }
        tentativi += 1;
        if tentativi > 3 {
            return Err(s);
        }
    }

    // da qui niente servizi UEFI
    let ingresso = elf.ingresso;
    let argomento = bootinfo::OFFSET_MAPPA_FISICA + info_fis;
    // SAFETY: tabelle costruite sopra (identità inclusa per questa sequenza); NXE abilitato
    // prima di caricare voci con il bit NX; il kernel imposta subito il proprio stack
    unsafe {
        core::arch::asm!(
            "cli",
            "mov ecx, 0xC0000080", // IA32_EFER
            "rdmsr",
            "or eax, 0x800",       // NXE
            "wrmsr",
            "mov rax, cr0",
            "or rax, 0x10000",     // WP: rispetta la sola lettura anche nel kernel
            "mov cr0, rax",
            "mov cr3, r8",
            "jmp r9",
            in("r8") t.pml4,
            in("r9") ingresso,
            in("rdi") argomento,
            options(noreturn)
        );
    }
}

#[panic_handler]
fn panico(info: &core::panic::PanicInfo) -> ! {
    log!("PANICO in OMNI Boot: {}", info);
    loop {
        // SAFETY: arresto della CPU in attesa
        unsafe { core::arch::asm!("hlt") };
    }
}
