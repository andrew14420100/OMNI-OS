// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Prove della milestone K2 (`docs/16-omni-autonomo/milestone-k2.md`): multiprocessore,
//! scheduler SMP, shootdown del TLB, memoria su richiesta, copy-on-write, stress della memoria
//! su tutte le CPU, spegnimento e riavvio ACPI.

use crate::interruzioni::{FAULT_ATTESI, RECUPERO};
use crate::mem::{frame, heap, pagine};
use crate::prove::esito;
use crate::sync::Blocco;
use crate::{kprintln, sched, smp, tempo, testo, vmm};
use alloc::vec::Vec;
use core::arch::asm;
use core::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use omni_comune::acpi::{Madt, MAX_CPU};
use omni_comune::bootinfo::PAGINA;

fn attendi_thread(id: &[u64], secondi: u64) -> bool {
    let t0 = tempo::ns();
    while !id.iter().all(|&i| sched::terminato(i)) {
        if tempo::ns() > t0 + secondi * 1_000_000_000 {
            return false;
        }
        sched::cedi();
        crate::arch::cpu::attendi();
    }
    true
}

fn maschera_tutte() -> u32 {
    (0..MAX_CPU).filter(|&i| smp::cpu_in_linea(i)).fold(0, |m, i| m | (1 << i))
}

// ------------------------------------------------------------------------------- K2-01

pub fn prova_smp(madt: &Madt) {
    let e = smp::avvia(madt);
    kprintln!("[K2] CPU in linea: {}", e.in_linea);
    esito(
        "K2-01",
        e.in_linea == e.attese && e.in_linea >= 1,
        testo!(
            "{} CPU su {} della MADT in linea in {} ms (INIT-SIPI-SIPI, trampolino reale->lungo); GDT/TSS/IST e timer APIC per CPU",
            e.in_linea,
            e.attese,
            e.tempo_ms
        )
        .as_str(),
    );
}

// ------------------------------------------------------------------------------- K2-02

static CONTATORE: Blocco<u64> = Blocco::new(0);
const INCREMENTI: u64 = 100_000;

fn incrementa(_: usize) {
    for _ in 0..INCREMENTI {
        *CONTATORE.prendi() += 1;
        for _ in 0..50 {
            core::hint::spin_loop();
        }
    }
}

pub fn prova_scheduler() {
    let n = 8usize;
    let id: Vec<u64> = (0..n).map(|_| sched::crea("contatore", incrementa, 0, 4)).collect();
    let ok_tempo = attendi_thread(&id, 120);
    let totale = *CONTATORE.prendi();
    let usate = id.iter().fold(0u32, |m, &i| m | sched::cpu_usate(i));
    let tutte = maschera_tutte();
    esito(
        "K2-02",
        ok_tempo && totale == n as u64 * INCREMENTI && usate == tutte,
        testo!(
            "{} thread su {} CPU: {} incrementi sotto blocco (attesi {}), CPU usate {:#b} su {:#b}",
            n,
            smp::in_linea(),
            totale,
            n as u64 * INCREMENTI,
            usate,
            tutte
        )
        .as_str(),
    );
}

// ------------------------------------------------------------------------------- K2-03

const PAGINA_PROVA: u64 = 0xffff_e000_0000_0000;
static LETTO: [AtomicU64; MAX_CPU] = [const { AtomicU64::new(0) }; MAX_CPU];
static FAULT_DOPO: [AtomicBool; MAX_CPU] = [const { AtomicBool::new(false) }; MAX_CPU];

fn leggi_pagina(cpu: usize) {
    // SAFETY: la pagina di prova è mappata quando questo thread viene creato
    let v = unsafe { core::ptr::read_volatile(PAGINA_PROVA as *const u64) };
    LETTO[cpu].store(v, Ordering::Relaxed);
}

fn rileggi_dopo_rimozione(cpu: usize) {
    let prima = FAULT_ATTESI[cpu].load(Ordering::Relaxed);
    // SAFETY: lettura che deve provocare un page fault atteso (pagina rimossa); il gestore
    // riprende all'etichetta 2. Se il TLB di questa CPU fosse vecchio, la lettura riuscirebbe
    unsafe {
        asm!(
            "lea rax, [rip + 2f]",
            "mov qword ptr [{rec}], rax",
            "mov rax, qword ptr [{v}]",
            "2:",
            rec = in(reg) RECUPERO[cpu].as_ptr(),
            v = in(reg) PAGINA_PROVA,
            out("rax") _,
        );
    }
    RECUPERO[cpu].store(0, Ordering::Relaxed);
    FAULT_DOPO[cpu].store(FAULT_ATTESI[cpu].load(Ordering::Relaxed) == prima + 1, Ordering::Relaxed);
}

pub fn prova_shootdown() {
    let f = frame::alloca().expect("memoria");
    pagine::mappa(PAGINA_PROVA, f, pagine::SCRIVIBILE | pagine::NON_ESEGUIBILE);
    // SAFETY: pagina appena mappata
    unsafe { core::ptr::write_volatile(PAGINA_PROVA as *mut u64, 0x5eed_0123_4567_89ab) };
    let cpu: Vec<usize> = (0..MAX_CPU).filter(|&i| smp::cpu_in_linea(i)).collect();
    // 1) ogni CPU legge la pagina: la traduzione entra nel suo TLB
    let id: Vec<u64> = cpu.iter().map(|&c| sched::crea_su("leggi", leggi_pagina, c, 2, Some(c))).collect();
    let letti = attendi_thread(&id, 30) && cpu.iter().all(|&c| LETTO[c].load(Ordering::Relaxed) == 0x5eed_0123_4567_89ab);
    // 2) la CPU 0 rimuove la pagina: shootdown verso le altre CPU
    let s0 = smp::SHOOTDOWN.load(Ordering::Relaxed);
    let rimossa = pagine::rimuovi(PAGINA_PROVA) == Some(f);
    frame::libera(f);
    let inviati = smp::SHOOTDOWN.load(Ordering::Relaxed) - s0;
    // 3) ogni CPU rilegge: deve ottenere un page fault
    let id: Vec<u64> = cpu.iter().map(|&c| sched::crea_su("rileggi", rileggi_dopo_rimozione, c, 2, Some(c))).collect();
    let finiti = attendi_thread(&id, 30);
    let con_fault = cpu.iter().filter(|&&c| FAULT_DOPO[c].load(Ordering::Relaxed)).count();
    let shootdown_atteso = if cpu.len() > 1 { 1 } else { 0 };
    esito(
        "K2-03",
        letti && rimossa && finiti && con_fault == cpu.len() && inviati == shootdown_atteso,
        testo!(
            "pagina letta da {} CPU, rimossa con {} shootdown via IPI: page fault sulla rilettura in {} CPU su {} (nessuna traduzione vecchia)",
            cpu.len(),
            inviati,
            con_fault,
            cpu.len()
        )
        .as_str(),
    );
}

// ---------------------------------------------------------------------------- K2-04/05

pub fn prova_vmm() {
    // K2-04: 1000 pagine su richiesta in una regione da 64 MiB
    let liberi0 = frame::liberi();
    let tab0 = pagine::TABELLE.load(Ordering::Relaxed);
    let f0 = vmm::FAULT_SU_RICHIESTA.load(Ordering::Relaxed);
    let pagine_regione = 16384u64;
    let r = vmm::riserva(pagine_regione);
    let prima_di_toccare = vmm::presenti(r);
    let indice = |i: u64| (i * 13) % pagine_regione; // 1000 pagine distinte (13 coprimo con 16384)
    for i in 0..1000u64 {
        // SAFETY: la pagina appartiene a una regione riservata: il page fault la assegna
        unsafe { core::ptr::write_volatile((r + indice(i) * PAGINA) as *mut u64, i.wrapping_mul(0x9e37_79b9_7f4a_7c15)) };
    }
    let fault = vmm::FAULT_SU_RICHIESTA.load(Ordering::Relaxed) - f0;
    let presenti = vmm::presenti(r);
    let tabelle = pagine::TABELLE.load(Ordering::Relaxed) - tab0;
    let usati = (liberi0 - frame::liberi()) as u64;
    // SAFETY: pagine assegnate sopra
    let contenuto = (0..1000u64).all(|i| unsafe { core::ptr::read_volatile((r + indice(i) * PAGINA) as *const u64) } == i.wrapping_mul(0x9e37_79b9_7f4a_7c15));
    vmm::rilascia(r);
    let dopo = frame::liberi();
    esito(
        "K2-04",
        prima_di_toccare == 0 && fault == 1000 && presenti == 1000 && usati == 1000 + tabelle && contenuto && dopo + tabelle as usize == liberi0,
        testo!(
            "regione da 64 MiB senza frame; 1000 pagine toccate: {} page fault, {} pagine presenti, {} frame (+{} tabelle); contenuto verificato; dopo il rilascio frame liberi {} (prima {})",
            fault,
            presenti,
            usati - tabelle,
            tabelle,
            dopo as u64 + tabelle,
            liberi0
        )
        .as_str(),
    );

    // K2-05: copy-on-write
    let n = 64u64;
    let a = vmm::riserva(n);
    for p in 0..n {
        // SAFETY: regione riservata, assegnata su richiesta
        unsafe { core::ptr::write_volatile((a + p * PAGINA) as *mut u64, 0xa000 + p) };
    }
    let liberi1 = frame::liberi();
    let tab1 = pagine::TABELLE.load(Ordering::Relaxed);
    let c0 = vmm::COPIE_COW.load(Ordering::Relaxed);
    let b = vmm::clona_cow(a).expect("regione");
    let tabelle_clone = pagine::TABELLE.load(Ordering::Relaxed) - tab1;
    let frame_nuovi = (liberi1 - frame::liberi()) as u64 - tabelle_clone;
    let condivisi =
        (0..n).all(|p| vmm::frame_di(a + p * PAGINA) == vmm::frame_di(b + p * PAGINA) && vmm::riferimenti(vmm::frame_di(a + p * PAGINA).unwrap_or(0)) == 2);
    // SAFETY: pagine presenti (condivise in sola lettura)
    let uguali = (0..n).all(|p| unsafe { core::ptr::read_volatile((b + p * PAGINA) as *const u64) } == 0xa000 + p);
    // scrittura sul clone: una copia privata, l'originale resta invariato
    // SAFETY: pagina copy-on-write: il page fault di scrittura ne fa una copia
    unsafe { core::ptr::write_volatile((b + 5 * PAGINA) as *mut u64, 0xbbbb) };
    let copie1 = vmm::COPIE_COW.load(Ordering::Relaxed) - c0;
    let separati = vmm::frame_di(a + 5 * PAGINA) != vmm::frame_di(b + 5 * PAGINA);
    // SAFETY: pagine presenti
    let originale = unsafe { core::ptr::read_volatile((a + 5 * PAGINA) as *const u64) } == 0xa005;
    let rif = vmm::riferimenti(vmm::frame_di(a + 5 * PAGINA).unwrap_or(0));
    // scrittura sull'originale della stessa pagina: ultimo riferimento, nessuna copia
    // SAFETY: pagina con un solo riferimento, ritorna scrivibile senza copia
    unsafe { core::ptr::write_volatile((a + 5 * PAGINA) as *mut u64, 0xaaaa) };
    let copie2 = vmm::COPIE_COW.load(Ordering::Relaxed) - c0;
    // SAFETY: pagina presente
    let clone_intatto = unsafe { core::ptr::read_volatile((b + 5 * PAGINA) as *const u64) } == 0xbbbb;
    vmm::rilascia(a);
    vmm::rilascia(b);
    let tab_tot = pagine::TABELLE.load(Ordering::Relaxed) - tab1;
    let restituiti = frame::liberi() as u64 + tab_tot == liberi1 as u64 + n;
    esito(
        "K2-05",
        frame_nuovi == 0 && condivisi && uguali && copie1 == 1 && separati && originale && rif == 1 && copie2 == 1 && clone_intatto && restituiti,
        testo!(
            "clone di 64 pagine: {} frame nuovi, frame condivisi con 2 riferimenti; scrittura sul clone: {} copia, originale invariato; scrittura sull'originale (1 riferimento): nessuna copia; frame restituiti al rilascio: {}",
            frame_nuovi,
            copie1,
            if restituiti { "tutti" } else { "NO" }
        )
        .as_str(),
    );
}

// ------------------------------------------------------------------------------- K2-06

static VIA: AtomicBool = AtomicBool::new(false);
static ERRORI_STRESS: AtomicU64 = AtomicU64::new(0);
const OPERAZIONI: u64 = 200_000;

fn stress(seme: usize) {
    while !VIA.load(Ordering::Acquire) {
        core::hint::spin_loop();
    }
    let mut x = 0x9e37_79b9_7f4a_7c15u64 ^ (seme as u64).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    let mut rnd = || {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        x
    };
    let mut posti: Vec<Option<(Vec<u8>, u8)>> = (0..64).map(|_| None).collect();
    for op in 0..OPERAZIONI {
        let r = rnd();
        let i = (r % 64) as usize;
        match posti[i].take() {
            Some((b, s)) => {
                if b.iter().enumerate().any(|(k, &c)| c != s.wrapping_add(k as u8)) {
                    ERRORI_STRESS.fetch_add(1, Ordering::Relaxed);
                }
            }
            None => {
                let dim = if r >> 61 == 0 { 2049 + (r >> 20) as usize % 6000 } else { 1 + (r >> 20) as usize % 700 };
                let s = (r >> 40) as u8;
                posti[i] = Some(((0..dim).map(|k| s.wrapping_add(k as u8)).collect(), s));
            }
        }
        if op % 16 == 0 {
            match frame::alloca() {
                Some(f) => {
                    if !frame::libera(f) {
                        ERRORI_STRESS.fetch_add(1, Ordering::Relaxed);
                    }
                }
                None => {
                    ERRORI_STRESS.fetch_add(1, Ordering::Relaxed);
                }
            }
        }
    }
}

pub fn prova_stress() {
    let n = (smp::in_linea() as usize).max(4);
    let id: Vec<u64> = (0..n).map(|i| sched::crea("stress", stress, i, 8)).collect();
    // misure di partenza dopo la creazione (stack e strutture dei thread già assegnati)
    let heap0 = heap::statistiche();
    let liberi0 = frame::liberi();
    let tab0 = pagine::TABELLE.load(Ordering::Relaxed);
    let t0 = tempo::ns();
    VIA.store(true, Ordering::Release);
    let finiti = attendi_thread(&id, 300);
    let ms = (tempo::ns() - t0) / 1_000_000;
    let heap1 = heap::statistiche();
    let tabelle = pagine::TABELLE.load(Ordering::Relaxed) - tab0;
    let pagine_heap = heap1.pagine - heap0.pagine;
    let usati = liberi0 as u64 - frame::liberi() as u64;
    let usate = id.iter().fold(0u32, |m, &i| m | sched::cpu_usate(i));
    let errori = ERRORI_STRESS.load(Ordering::Relaxed);
    esito(
        "K2-06",
        finiti && errori == 0 && heap1.in_uso == heap0.in_uso && usati == pagine_heap + tabelle,
        testo!(
            "{} thread x {} operazioni (heap + frame) su CPU {:#b} in {} ms: {} errori; memoria in uso {} -> {} byte; frame consumati {} = pagine dell'heap {} + tabelle {}",
            n,
            OPERAZIONI,
            usate,
            ms,
            errori,
            heap0.in_uso,
            heap1.in_uso,
            usati,
            pagine_heap,
            tabelle
        )
        .as_str(),
    );
}
