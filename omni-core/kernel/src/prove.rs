// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Sequenza di avvio del kernel K1 con una prova per ogni criterio di accettazione
//! (`docs/16-omni-autonomo/milestone-k1.md`). Ogni esito va sulla seriale con il prefisso
//! `[K1]` (letto dalle prove automatiche) e sullo schermo.

use crate::arch::{cpu, gdt, idt};
use crate::interruzioni::{self as intr, BREAKPOINT, PAGE_FAULT, RECUPERO, ULTIMO_CR2, ULTIMO_ERRORE};
use crate::mem::{frame, heap, pagine};
use crate::{acpi, kprintln, sched, tastiera, tempo, testo, video, Buf};
use alloc::boxed::Box;
use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use core::arch::asm;
use core::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use omni_comune::bootinfo::{BootInfo, TipoMemoria, PAGINA};
use omni_comune::sha256;

static SUPERATE: AtomicU64 = AtomicU64::new(0);
static FALLITE: AtomicU64 = AtomicU64::new(0);

pub fn esito(id: &str, ok: bool, dettaglio: &str) {
    if ok {
        SUPERATE.fetch_add(1, Ordering::Relaxed);
    } else {
        FALLITE.fetch_add(1, Ordering::Relaxed);
    }
    let stato = if ok { "OK" } else { "FALLITO" };
    kprintln!("[PROVA] {} {} - {}", id, stato, dettaglio);
    let r = testo!("{}  {}  {}", id, stato, dettaglio);
    video::riga(r.as_str(), if ok { video::VERDE } else { video::ROSSO });
}

#[allow(unreachable_code)] // nelle varianti di prova il panico o il double fault terminano qui
pub fn esegui(indirizzo_boot_info: u64) -> ! {
    // SAFETY: OMNI Boot passa l'indirizzo (mappa diretta) di una BootInfo valida e non la
    // modifica più; la verifica di magia e versione segue subito
    let bi: &'static BootInfo = unsafe { &*(indirizzo_boot_info as *const BootInfo) };
    if !bi.valido() {
        kprintln!("[K1] K1-02 FALLITO - BootInfo non valida");
        panic!("BootInfo non valida");
    }

    // K2-08: questo avvio segue un riavvio chiesto dal kernel?
    let secondo_avvio = crate::potenza::dopo_riavvio();
    if secondo_avvio {
        kprintln!("[K2] secondo avvio: riavvio richiesto dal kernel riconosciuto");
    }

    // K1-02: ingresso nel kernel e identità del binario
    let h = sha256::esadecimale(&bi.sha256_kernel);
    let hash = core::str::from_utf8(&h).unwrap_or("?");
    kprintln!("OMNI kernel K1 avviato; sha256 del kernel {}", hash);
    kprintln!("firmware {}, UEFI {}.{}, {} regioni di memoria", bi.fornitore(), bi.revisione_uefi >> 16, (bi.revisione_uefi & 0xffff) / 10, bi.num_regioni);

    // K1-05: allocatore di frame
    let rf = frame::inizializza(bi);
    let video_ok = video::inizializza(&bi.framebuffer);
    esito("K1-02", true, testo!("kernel in esecuzione nella meta' alta, sha256 {}...", &hash[..16]).as_str());
    prova_frame(bi, &rf);

    // K1-03: GDT, TSS, IDT, eccezioni
    gdt::inizializza(0);
    idt::inizializza();
    // SAFETY: int3 genera un breakpoint gestito che riprende all'istruzione successiva
    unsafe { asm!("int3") };
    let bp = BREAKPOINT.load(Ordering::Relaxed);
    esito("K1-03", bp == 1, testo!("GDT+TSS (IST per double fault e NMI), IDT 256 voci; breakpoint gestito e ripreso ({})", bp).as_str());

    // K1-04: tabelle di pagine proprie, W^X
    prova_pagine(bi);

    // K1-06: heap
    prova_heap();

    // K1-07: ACPI
    let info = match acpi::leggi(bi.rsdp) {
        Ok(i) => i,
        Err(e) => {
            esito("K1-07", false, e);
            fine();
        }
    };
    let mut firme = Buf::new();
    for f in info.firme.iter().take(info.tabelle.min(info.firme.len())) {
        use core::fmt::Write;
        let _ = write!(firme, "{} ", core::str::from_utf8(f).unwrap_or("?"));
    }
    kprintln!("[K1] ACPI tabelle: {}", firme.as_str());
    kprintln!("[K1] CPU: {}", info.madt.cpu_abilitate);
    esito(
        "K1-07",
        info.madt.cpu_abilitate >= 1 && info.madt.ioapic != 0 && info.hpet != 0,
        testo!(
            "RSDP rev {} OEM {}, XSDT {} tabelle, MADT {} CPU, IOAPIC {:#x}, HPET {:#x}",
            info.rsdp.revisione,
            core::str::from_utf8(&info.rsdp.oem).unwrap_or("?"),
            info.tabelle,
            info.madt.cpu_abilitate,
            info.madt.ioapic,
            info.hpet
        )
        .as_str(),
    );

    // K1-08: APIC, IOAPIC, HPET, timer a 100 Hz
    tempo::disattiva_pic();
    let freq = tempo::inizializza_hpet(info.hpet);
    let apic = tempo::inizializza_apic(&info.madt);
    tempo::svuota_ps2();
    let gsi = tempo::instrada_irq(&info.madt, 1, idt::VETTORE_TASTIERA, apic.id);
    cpu::attiva_interruzioni();
    let t0 = tempo::ns();
    let k0 = tempo::TICK.load(Ordering::Relaxed);
    while tempo::ns() < t0 + 2_000_000_000 {
        cpu::attendi();
    }
    let tick = tempo::TICK.load(Ordering::Relaxed) - k0;
    esito(
        "K1-08",
        freq.is_ok() && (180..=220).contains(&tick),
        testo!(
            "PIC disattivato, APIC {} v{:#x}, HPET {} Hz, timer {} conteggi/tick: {} tick in 2 s (atteso 200 +-10%), tastiera su GSI {}",
            apic.id,
            apic.versione,
            freq.unwrap_or(0),
            apic.conteggi_per_tick,
            tick,
            gsi
        )
        .as_str(),
    );

    // K1-09: thread del kernel con prelazione
    prova_thread();

    if cfg!(feature = "prova-panico") {
        panic!("prova di panico controllata (K1-12)");
    }
    #[cfg(feature = "prova-doppio-errore")]
    {
        let _ = video_ok;
        prova_doppio_errore();
    }

    // K2: multiprocessore, memoria virtuale, stress, energia
    crate::prove_k2::prova_smp(&info.madt);
    crate::prove_k2::prova_scheduler();
    crate::prove_k2::prova_shootdown();
    crate::prove_k2::prova_vmm();
    crate::prove_k2::prova_stress();
    let energia = crate::potenza::InfoPotenza { fadt: info.fadt, s5: info.s5 };
    kprintln!(
        "[K2] ACPI energia: PM1a_CNT {:#x}, PM1b_CNT {:#x}, reset {:?}, \\_S5 {:?}",
        energia.fadt.pm1a_cnt,
        energia.fadt.pm1b_cnt,
        energia.fadt.reset,
        energia.s5
    );

    // K1-10: schermata
    let (s, f) = (SUPERATE.load(Ordering::Relaxed), FALLITE.load(Ordering::Relaxed));
    esito(
        "K1-10",
        video_ok,
        testo!("schermata OMNI su framebuffer GOP {}x{}, font vettoriale originale", bi.framebuffer.larghezza, bi.framebuffer.altezza).as_str(),
    );
    kprintln!("[K1] prove nel kernel: {} superate, {} fallite", s + 1, f);

    if !secondo_avvio {
        video::riga(testo!("Prove nel kernel: {} superate, {} fallite. Scrivi omni e premi Invio.", s + 1, f).as_str(), video::TESTO);
        // K1-11: tastiera
        prova_tastiera();
        riepilogo();
        // K2-08: riavvio (il prossimo avvio lo riconosce dal segno nella CMOS)
        kprintln!("[K2] riavvio ACPI richiesto (registro di reset {:?})", energia.fadt.reset);
        video::riga("Riavvio...", video::TESTO);
        let errore = crate::potenza::riavvia(&energia);
        esito("K2-08", false, errore);
        fine()
    }
    esito("K2-08", true, "riavvio completato: firmware, OMNI Boot e kernel ripartiti e riavvio riconosciuto");
    riepilogo();
    // K2-07: spegnimento
    kprintln!("[K2] spegnimento ACPI (SLP_TYP da \\_S5 {:?}, PM1a_CNT {:#x})", energia.s5, energia.fadt.pm1a_cnt);
    video::riga("Spegnimento...", video::TESTO);
    let errore = crate::potenza::spegni(&energia);
    esito("K2-07", false, errore);
    fine()
}

fn riepilogo() {
    let (s, f) = (SUPERATE.load(Ordering::Relaxed), FALLITE.load(Ordering::Relaxed));
    kprintln!("[K2] ESITO: {} ({} superate, {} fallite)", if f == 0 { "SUPERATO" } else { "FALLITO" }, s, f);
}

fn fine() -> ! {
    let (s, f) = (SUPERATE.load(Ordering::Relaxed), FALLITE.load(Ordering::Relaxed));
    kprintln!("[K1] ESITO: {} ({} superate, {} fallite)", if f == 0 { "SUPERATO" } else { "FALLITO" }, s, f);
    let _ = s;
    #[cfg(feature = "ktest")]
    cpu::esci_qemu(if f == 0 { 0x10 } else { 0x11 });
    #[allow(unreachable_code)]
    loop {
        cpu::attendi();
    }
}

fn prova_frame(bi: &BootInfo, r: &frame::Riepilogo) {
    // pagine libere sotto 1 MiB (riservate dal kernel) e pagine della bitmap
    let mut sotto_1mb = 0u64;
    for g in bi.regioni().iter().filter(|g| g.tipo == TipoMemoria::Libera) {
        let fine = g.fine().min(0x10_0000);
        if fine > g.inizio {
            sotto_1mb += (fine - g.inizio) / PAGINA;
        }
    }
    let pagine_bitmap = (r.frame_totali as u64).div_ceil(64) * 8;
    let pagine_bitmap = pagine_bitmap.div_ceil(PAGINA);
    let atteso = r.liberi_dalla_mappa - sotto_1mb - pagine_bitmap;
    let coerente = r.frame_liberi as u64 == atteso;
    let prima = frame::liberi();
    let mut distinti = true;
    for _ in 0..10_000 {
        let (Some(a), Some(b)) = (frame::alloca(), frame::alloca()) else {
            distinti = false;
            break;
        };
        distinti &= a != b && a % PAGINA == 0;
        frame::libera(a);
        frame::libera(b);
    }
    let x = frame::alloca().unwrap_or(0);
    frame::libera(x);
    let doppio_rilevato = !frame::libera(x);
    let dopo = frame::liberi();
    esito(
        "K1-05",
        coerente && distinti && prima == dopo && doppio_rilevato,
        testo!(
            "{} MiB liberi su {} dalla mappa UEFI (atteso {} frame, contati {}); 10000 cicli senza perdite ({} -> {}); doppio rilascio rilevato",
            (r.frame_liberi as u64 * PAGINA) >> 20,
            (r.liberi_dalla_mappa * PAGINA) >> 20,
            atteso,
            r.frame_liberi,
            prima,
            dopo
        )
        .as_str(),
    );
}

#[inline(never)]
fn bersaglio_codice() -> u64 {
    core::hint::black_box(0x0123_4567)
}

static mut DATI_NON_ESEGUIBILI: [u8; 16] = [0xc3; 16]; // "ret": se fosse eseguibile tornerebbe subito

fn prova_pagine(bi: &BootInfo) {
    let vecchie = cpu::cr3();
    let r = pagine::inizializza(bi);
    let flag = |v: u64| pagine::traduci(v).map(|(_, f)| f).unwrap_or(0);
    let (ft, fs, fd) = (flag(r.testo.0), flag(r.sola.0), flag(r.dati.0));
    let permessi_ok = ft & pagine::SCRIVIBILE == 0
        && ft & pagine::NON_ESEGUIBILE == 0
        && fs & (pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE) == pagine::NON_ESEGUIBILE
        && fd & (pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE) == (pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE);

    // 1) scrittura nel codice del kernel -> page fault (presente + scrittura)
    let codice = bersaglio_codice as fn() -> u64 as usize as u64;
    let pf0 = PAGE_FAULT.load(Ordering::Relaxed);
    // SAFETY: la scrittura provoca un page fault atteso; il gestore riprende all'etichetta 2
    unsafe {
        asm!(
            "lea rax, [rip + 2f]",
            "mov qword ptr [{rec}], rax",
            "mov byte ptr [{t}], 0x90",
            "2:",
            rec = in(reg) RECUPERO[0].as_ptr(),
            t = in(reg) codice,
            out("rax") _,
        );
    }
    let scrittura = PAGE_FAULT.load(Ordering::Relaxed) == pf0 + 1
        && ULTIMO_CR2.load(Ordering::Relaxed) == codice
        && ULTIMO_ERRORE.load(Ordering::Relaxed) & 0b11 == 0b11
        && bersaglio_codice() == 0x0123_4567;

    // 2) esecuzione da una pagina di dati -> page fault (presente + prelievo d'istruzione)
    let dati = (&raw const DATI_NON_ESEGUIBILI) as u64;
    // SAFETY: il salto provoca un page fault NX atteso; il gestore riprende all'etichetta 2
    unsafe {
        asm!(
            "lea rax, [rip + 2f]",
            "mov qword ptr [{rec}], rax",
            "jmp {d}",
            "2:",
            rec = in(reg) RECUPERO[0].as_ptr(),
            d = in(reg) dati,
            out("rax") _,
        );
    }
    let esecuzione =
        PAGE_FAULT.load(Ordering::Relaxed) == pf0 + 2 && ULTIMO_CR2.load(Ordering::Relaxed) == dati && ULTIMO_ERRORE.load(Ordering::Relaxed) & 0x11 == 0x11;

    // 3) lettura di una pagina non mappata -> page fault (non presente)
    let vuoto: u64 = 0xffff_9000_0000_0000;
    // SAFETY: lettura che provoca un page fault atteso; il gestore riprende all'etichetta 2
    unsafe {
        asm!(
            "lea rax, [rip + 2f]",
            "mov qword ptr [{rec}], rax",
            "mov rax, qword ptr [{v}]",
            "2:",
            rec = in(reg) RECUPERO[0].as_ptr(),
            v = in(reg) vuoto,
            out("rax") _,
        );
    }
    let non_mappata =
        PAGE_FAULT.load(Ordering::Relaxed) == pf0 + 3 && ULTIMO_CR2.load(Ordering::Relaxed) == vuoto && ULTIMO_ERRORE.load(Ordering::Relaxed) & 1 == 0;

    esito(
        "K1-04",
        r.pml4 != vecchie & !0xfff && permessi_ok && scrittura && esecuzione && non_mappata,
        testo!(
            "tabelle proprie (PML4 {:#x}), testo R-X, sola lettura R--, dati RW-, mappa diretta {} MiB NX; page fault su scrittura nel codice {}, esecuzione da dati {}, pagina assente {}",
            r.pml4,
            r.mappa_diretta_mib,
            if scrittura { "ok" } else { "NO" },
            if esecuzione { "ok" } else { "NO" },
            if non_mappata { "ok" } else { "NO" }
        )
        .as_str(),
    );
}

fn prova_heap() {
    let base = heap::statistiche().in_uso;
    let b = Box::new(0x5a5a_5a5a_u64);
    let mut v: Vec<u64> = Vec::new();
    for i in 0..10_000u64 {
        v.push(i * 3);
    }
    let mut m = BTreeMap::new();
    for i in 0..1000u64 {
        m.insert(i.wrapping_mul(2654435761) % 100_003, i);
    }
    let strutture = *b == 0x5a5a_5a5a && v.iter().enumerate().all(|(i, &x)| x == i as u64 * 3) && m.len() == 1000;
    drop((b, v, m));

    // 1 milione di operazioni casuali su 512 posizioni, con verifica del contenuto
    let mut x: u64 = 0x2545_f491_4f6c_dd1d;
    let mut rnd = || {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        x
    };
    let mut posizioni: Vec<Option<(Vec<u8>, u8)>> = (0..512).map(|_| None).collect();
    let mut errori = 0u64;
    let t0 = tempo::ns();
    for _ in 0..1_000_000 {
        let r = rnd();
        let i = (r % 512) as usize;
        match posizioni[i].take() {
            Some((buf, seme)) => {
                if buf.iter().enumerate().any(|(k, &c)| c != seme.wrapping_add(k as u8)) {
                    errori += 1;
                }
            }
            None => {
                let dim = if r >> 60 == 0 { 2049 + (r >> 20) as usize % 8000 } else { 1 + (r >> 20) as usize % 512 };
                let seme = (r >> 40) as u8;
                let buf: Vec<u8> = (0..dim).map(|k| seme.wrapping_add(k as u8)).collect();
                posizioni[i] = Some((buf, seme));
            }
        }
    }
    drop(posizioni);
    let _ = t0;
    let s = heap::statistiche();
    esito(
        "K1-06",
        strutture && errori == 0 && s.in_uso == base,
        testo!(
            "Box/Vec/BTreeMap corretti; 1000000 operazioni casuali verificate, {} errori; memoria in uso tornata a {} byte ({} pagine dell'heap restano mappate per le classi piccole, pronte al riuso); {} allocazioni totali",
            errori,
            s.in_uso,
            s.pagine,
            s.allocazioni
        )
        .as_str(),
    );
}

static FERMA_THREAD: AtomicBool = AtomicBool::new(false);
static ERRORI_REGISTRI: AtomicU64 = AtomicU64::new(0);
static GIRI: [AtomicU64; 3] = [AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0)];

/// Riempie 13 registri con valori derivati da `modello`, aspetta `giri` iterazioni (durante
/// le quali il timer può cambiare thread più volte) e verifica che nessun registro sia cambiato.
fn controlla_registri(modello: u64, giri: u64) -> bool {
    let esito: u64;
    // SAFETY: il blocco salva e ripristina rbx e rbp; tutti gli altri registri usati sono
    // dichiarati come sovrascritti
    unsafe {
        asm!(
            "push rbx", "push rbp",
            "mov rbx, rax", "xor rbx, 0x11",
            "mov rcx, rax", "xor rcx, 0x22",
            "mov rdx, rax", "xor rdx, 0x33",
            "mov rsi, rax", "xor rsi, 0x44",
            "mov rdi, rax", "xor rdi, 0x55",
            "mov rbp, rax", "xor rbp, 0x66",
            "mov r8, rax", "xor r8, 0x77",
            "mov r9, rax", "xor r9, 0x18",
            "mov r10, rax", "xor r10, 0x29",
            "mov r12, rax", "xor r12, 0x3a",
            "mov r13, rax", "xor r13, 0x4b",
            "mov r14, rax", "xor r14, 0x5c",
            "mov r15, rax", "xor r15, 0x6d",
            "2:", "pause", "dec r11", "jnz 2b",
            "xor rbx, rax", "cmp rbx, 0x11", "jne 3f",
            "xor rcx, rax", "cmp rcx, 0x22", "jne 3f",
            "xor rdx, rax", "cmp rdx, 0x33", "jne 3f",
            "xor rsi, rax", "cmp rsi, 0x44", "jne 3f",
            "xor rdi, rax", "cmp rdi, 0x55", "jne 3f",
            "xor rbp, rax", "cmp rbp, 0x66", "jne 3f",
            "xor r8, rax", "cmp r8, 0x77", "jne 3f",
            "xor r9, rax", "cmp r9, 0x18", "jne 3f",
            "xor r10, rax", "cmp r10, 0x29", "jne 3f",
            "xor r12, rax", "cmp r12, 0x3a", "jne 3f",
            "xor r13, rax", "cmp r13, 0x4b", "jne 3f",
            "xor r14, rax", "cmp r14, 0x5c", "jne 3f",
            "xor r15, rax", "cmp r15, 0x6d", "jne 3f",
            "xor eax, eax", "jmp 4f",
            "3:", "mov eax, 1",
            "4:", "pop rbp", "pop rbx",
            inout("rax") modello => esito,
            inout("r11") giri => _,
            out("rcx") _, out("rdx") _, out("rsi") _, out("rdi") _,
            out("r8") _, out("r9") _, out("r10") _,
            out("r12") _, out("r13") _, out("r14") _, out("r15") _,
        );
    }
    esito == 0
}

fn corpo_prova(indice: usize) {
    let modello = 0x0101_0101_0101_0101u64.wrapping_mul(indice as u64 * 0x35 + 7);
    while !FERMA_THREAD.load(Ordering::Relaxed) {
        if !controlla_registri(modello, 300_000) {
            ERRORI_REGISTRI.fetch_add(1, Ordering::Relaxed);
        }
        GIRI[indice].fetch_add(1, Ordering::Relaxed);
    }
}

fn prova_thread() {
    sched::inizializza();
    let a = sched::crea("prova-a", corpo_prova, 1, 4);
    let b = sched::crea("prova-b", corpo_prova, 2, 4);
    let c0 = sched::CAMBI.load(Ordering::Relaxed);
    let t0 = tempo::ns();
    // anche il thread principale controlla i propri registri mentre gli altri girano
    let mut principale_ok = true;
    while tempo::ns() < t0 + 1_500_000_000 {
        principale_ok &= controlla_registri(0x7766_5544_3322_1100, 200_000);
        GIRI[0].fetch_add(1, Ordering::Relaxed);
    }
    FERMA_THREAD.store(true, Ordering::Relaxed);
    let t1 = tempo::ns();
    while !(sched::terminato(a) && sched::terminato(b)) && tempo::ns() < t1 + 2_000_000_000 {
        sched::cedi();
    }
    let cambi = sched::CAMBI.load(Ordering::Relaxed) - c0;
    let (ea, eb) = (sched::esecuzioni(a), sched::esecuzioni(b));
    let (ga, gb, g0) = (GIRI[1].load(Ordering::Relaxed), GIRI[2].load(Ordering::Relaxed), GIRI[0].load(Ordering::Relaxed));
    let errori = ERRORI_REGISTRI.load(Ordering::Relaxed);
    kprintln!("[K1] thread: cambi {} esecuzioni {} {} {} {}, giri {} {} principale {}", cambi, sched::nome(a), ea, sched::nome(b), eb, ga, gb, g0);
    esito(
        "K1-09",
        principale_ok && errori == 0 && ea >= 5 && eb >= 5 && cambi >= 20 && ga > 0 && gb > 0 && sched::terminato(a) && sched::terminato(b),
        testo!(
            "3 thread alternati dal timer: {} cambi di contesto, A {} turni, B {} turni; 13 registri verificati a ogni giro: {} errori",
            cambi,
            ea,
            eb,
            errori + if principale_ok { 0 } else { 1 }
        )
        .as_str(),
    );
}

#[cfg(feature = "prova-doppio-errore")]
#[allow(unconditional_recursion)]
fn ricorsione(n: u64) -> u64 {
    let a = core::hint::black_box([n; 64]);
    ricorsione(n + 1).wrapping_add(a[3])
}

#[cfg(feature = "prova-doppio-errore")]
fn prova_doppio_errore() -> ! {
    kprintln!("[K1] prova del double fault: overflow di uno stack da 16 KiB con pagina di guardia");
    sched::crea(
        "overflow",
        |_| {
            core::hint::black_box(ricorsione(0));
        },
        0,
        4,
    );
    loop {
        sched::cedi();
        cpu::attendi();
    }
}

fn prova_tastiera() {
    kprintln!("[K1] in attesa della tastiera: scrivere omni e premere Invio");
    let t0 = tempo::ns();
    let mut ultima = usize::MAX;
    loop {
        cpu::attendi();
        let (n, testo_corrente, inviate, inviata, ni) = {
            let r = tastiera::RIGA.prendi();
            (r.lunghezza, r.testo, r.inviate, r.ultima_inviata, r.lunghezza_inviata)
        };
        if n != ultima {
            ultima = n;
            let s = core::str::from_utf8(&testo_corrente[..n]).unwrap_or("?");
            kprintln!("[tastiera] riga: {}", s);
            video::scrivi_in_fondo(testo!("> {}_", s).as_str());
        }
        if inviate > 0 {
            let s = core::str::from_utf8(&inviata[..ni]).unwrap_or("?");
            kprintln!("[tastiera] inviato: {}", s);
            esito("K1-11", s == "omni", testo!("tastiera PS/2 su IOAPIC: ricevuto \"{}\" ({} interruzioni)", s, intr::TASTI.load(Ordering::Relaxed)).as_str());
            return;
        }
        if tempo::ns() > t0 + 300_000_000_000 {
            esito("K1-11", false, "nessun Invio dalla tastiera entro 5 minuti");
            return;
        }
    }
}
