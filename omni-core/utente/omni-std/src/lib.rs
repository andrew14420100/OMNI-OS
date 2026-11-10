// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! `omni-std`: libreria minima dei programmi utente OMNI (K3).
//!
//! - chiamate di sistema (`syscall`, ABI in `omni_comune::abi`);
//! - testo sul registro del sistema (`stampa!`);
//! - allocatore globale sopra `SC_MAPPA` (per `alloc::vec::Vec`, `Box`, `String`);
//! - processi e thread;
//! - punto d'ingresso `_start` (macro `principale!`) e gestore del panico.
//!
//! Il programma gira in ring 3 nel proprio spazio d'indirizzi: ogni accesso alla memoria del
//! kernel o di un altro processo termina soltanto il programma stesso.
#![no_std]

extern crate alloc;

use core::alloc::{GlobalAlloc, Layout};
use core::arch::asm;
use core::fmt::{self, Write};
use core::sync::atomic::{AtomicBool, Ordering};
pub use omni_comune::abi;

// ------------------------------------------------------------------ chiamate di sistema

/// Chiamata di sistema con fino a cinque argomenti.
///
/// # Safety
/// Gli argomenti devono rispettare il contratto della chiamata `numero` (puntatori validi
/// per le lunghezze indicate); il kernel verifica comunque ogni indirizzo.
#[inline(always)]
pub unsafe fn chiamata(numero: u64, a: u64, b: u64, c: u64, d: u64, e: u64) -> i64 {
    let r: i64;
    // SAFETY: `syscall` entra nel kernel, che conserva tutti i registri tranne rax, rcx, r11
    unsafe {
        asm!(
            "syscall",
            inlateout("rax") numero as i64 => r,
            in("rdi") a,
            in("rsi") b,
            in("rdx") c,
            in("r10") d,
            in("r8") e,
            lateout("rcx") _,
            lateout("r11") _,
            options(nostack),
        );
    }
    r
}

/// Scrive testo sul registro del sistema.
pub fn scrivi(s: &str) -> i64 {
    // SAFETY: puntatore e lunghezza di una stringa valida
    unsafe { chiamata(abi::SC_SCRIVI, s.as_ptr() as u64, s.len() as u64, 0, 0, 0) }
}

/// Termina il processo con il codice indicato.
pub fn esci(codice: i64) -> ! {
    // SAFETY: nessun puntatore
    unsafe { chiamata(abi::SC_ESCI, codice as u64, 0, 0, 0, 0) };
    // il kernel non ritorna da SC_ESCI
    loop {
        core::hint::spin_loop();
    }
}

pub fn cedi() {
    // SAFETY: nessun argomento
    unsafe { chiamata(abi::SC_CEDI, 0, 0, 0, 0, 0) };
}

/// Pagine nuove, azzerate, lettura e scrittura (non eseguibili).
pub fn mappa(pagine: u64) -> Result<*mut u8, i64> {
    // SAFETY: nessun puntatore in ingresso
    let r = unsafe { chiamata(abi::SC_MAPPA, pagine, 0, 0, 0, 0) };
    if r < 0 {
        Err(r)
    } else {
        Ok(r as *mut u8)
    }
}

pub fn info(chiave: u64) -> u64 {
    // SAFETY: nessun puntatore
    unsafe { chiamata(abi::SC_INFO, chiave, 0, 0, 0, 0) as u64 }
}

pub fn pid() -> u64 {
    info(abi::INFO_PID)
}

pub fn cpu() -> u64 {
    info(abi::INFO_CPU)
}

pub fn tempo_ns() -> u64 {
    info(abi::INFO_TEMPO_NS)
}

/// Avvia un programma del pacchetto iniziale; restituisce l'identificativo del processo.
pub fn avvia(nome: &str, argomento: u64, priorita: u64) -> Result<u64, i64> {
    // SAFETY: puntatore e lunghezza di una stringa valida
    let r = unsafe { chiamata(abi::SC_AVVIA, nome.as_ptr() as u64, nome.len() as u64, argomento, priorita, 0) };
    if r < 0 {
        Err(r)
    } else {
        Ok(r as u64)
    }
}

/// Attende la fine di un processo figlio e ne restituisce il codice d'uscita.
pub fn attendi(pid: u64) -> i64 {
    // SAFETY: nessun puntatore
    unsafe { chiamata(abi::SC_ATTENDI, pid, 0, 0, 0, 0) }
}

/// Termina un processo figlio.
pub fn termina(pid: u64) -> i64 {
    // SAFETY: nessun puntatore
    unsafe { chiamata(abi::SC_TERMINA, pid, 0, 0, 0, 0) }
}

// ------------------------------------------------------------------------------ thread

const PAGINE_STACK_THREAD: u64 = 8;

extern "C" fn ingresso_thread(dati: u64) -> ! {
    // SAFETY: `dati` è il Box creato da `thread` e consegnato solo a questo thread
    let f = *unsafe { alloc::boxed::Box::from_raw(dati as *mut alloc::boxed::Box<dyn FnOnce() + Send>) };
    f();
    // SAFETY: nessun argomento
    unsafe { chiamata(abi::SC_FINE_THREAD, 0, 0, 0, 0, 0) };
    loop {
        core::hint::spin_loop();
    }
}

/// Crea un thread nello stesso processo (stessa memoria); restituisce il suo identificativo.
pub fn thread<F: FnOnce() + Send + 'static>(f: F) -> Result<u64, i64> {
    let pila = mappa(PAGINE_STACK_THREAD)? as u64 + PAGINE_STACK_THREAD * 4096;
    let dati: alloc::boxed::Box<alloc::boxed::Box<dyn FnOnce() + Send>> = alloc::boxed::Box::new(alloc::boxed::Box::new(f));
    let p = alloc::boxed::Box::into_raw(dati) as u64;
    // pila - 8: allineamento come dopo una `call` (ABI System V)
    // SAFETY: ingresso e stack appartengono al processo; `p` resta valido fino a ingresso_thread
    let r = unsafe { chiamata(abi::SC_THREAD, ingresso_thread as extern "C" fn(u64) -> ! as usize as u64, pila - 8, p, 0, 0) };
    if r < 0 {
        // SAFETY: il thread non è stato creato: il Box torna a noi
        drop(unsafe { alloc::boxed::Box::from_raw(p as *mut alloc::boxed::Box<dyn FnOnce() + Send>) });
        Err(r)
    } else {
        Ok(r as u64)
    }
}

pub fn attendi_thread(tid: u64) -> i64 {
    // SAFETY: nessun puntatore
    unsafe { chiamata(abi::SC_ATTENDI_THREAD, tid, 0, 0, 0, 0) }
}

// ------------------------------------------------------------------------------- testo

/// Riga di testo composta in un buffer fisso e scritta con una sola chiamata.
pub struct Riga {
    b: [u8; 256],
    n: usize,
}

impl Riga {
    pub const fn new() -> Self {
        Self { b: [0; 256], n: 0 }
    }
    pub fn invia(&self) {
        scrivi(core::str::from_utf8(&self.b[..self.n]).unwrap_or("?"));
    }
}

impl Default for Riga {
    fn default() -> Self {
        Self::new()
    }
}

impl Write for Riga {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        for &c in s.as_bytes() {
            if self.n < self.b.len() {
                self.b[self.n] = c;
                self.n += 1;
            }
        }
        Ok(())
    }
}

/// Stampa una riga sul registro del sistema.
#[macro_export]
macro_rules! stampa {
    ($($a:tt)*) => {{
        use core::fmt::Write as _;
        let mut r = $crate::Riga::new();
        let _ = write!(r, $($a)*);
        r.invia();
    }};
}

// -------------------------------------------------------------------------- allocatore

/// Allocatore a "bump" su blocchi ottenuti con `SC_MAPPA`: semplice e sufficiente per i
/// programmi di K3 (la memoria torna al sistema alla fine del processo). Il rilascio
/// recupera solo l'ultimo blocco assegnato.
struct Allocatore;

struct StatoAlloc {
    cima: u64,
    fine: u64,
    ultimo: u64,
}

static OCCUPATO: AtomicBool = AtomicBool::new(false);
static mut STATO: StatoAlloc = StatoAlloc { cima: 0, fine: 0, ultimo: 0 };
const PAGINE_BLOCCO: u64 = 64;

fn con_stato<R>(f: impl FnOnce(&mut StatoAlloc) -> R) -> R {
    while OCCUPATO.compare_exchange_weak(false, true, Ordering::Acquire, Ordering::Relaxed).is_err() {
        core::hint::spin_loop();
    }
    let p = &raw mut STATO;
    // SAFETY: accesso esclusivo garantito da OCCUPATO
    let r = f(unsafe { &mut *p });
    OCCUPATO.store(false, Ordering::Release);
    r
}

// SAFETY: i blocchi restituiti sono allineati, disgiunti e grandi almeno quanto il layout
unsafe impl GlobalAlloc for Allocatore {
    // SAFETY: vedi sopra
    unsafe fn alloc(&self, l: Layout) -> *mut u8 {
        con_stato(|s| {
            let allinea = l.align().max(16) as u64;
            let mut inizio = s.cima.div_ceil(allinea) * allinea;
            if s.cima == 0 || inizio + l.size() as u64 > s.fine {
                let pagine = (l.size() as u64 + allinea).div_ceil(4096).max(PAGINE_BLOCCO);
                let Ok(p) = mappa(pagine) else { return core::ptr::null_mut() };
                s.cima = p as u64;
                s.fine = p as u64 + pagine * 4096;
                inizio = s.cima.div_ceil(allinea) * allinea;
            }
            s.cima = inizio + l.size() as u64;
            s.ultimo = inizio;
            inizio as *mut u8
        })
    }

    // SAFETY: `p` proviene da `alloc`
    unsafe fn dealloc(&self, p: *mut u8, _l: Layout) {
        con_stato(|s| {
            if p as u64 == s.ultimo {
                s.cima = s.ultimo;
                s.ultimo = 0;
            }
        })
    }
}

#[global_allocator]
static ALLOCATORE: Allocatore = Allocatore;

// --------------------------------------------------------------- ingresso e panico

/// Definisce `_start`: chiama `$f(argomento: u64) -> i64` e termina con il suo risultato.
#[macro_export]
macro_rules! principale {
    ($f:path) => {
        #[no_mangle]
        pub extern "C" fn _start(argomento: u64) -> ! {
            let codice: i64 = $f(argomento);
            $crate::esci(codice)
        }
    };
}

#[panic_handler]
fn panico(info: &core::panic::PanicInfo) -> ! {
    let mut r = Riga::new();
    let _ = write!(r, "panico nel programma: {}", info.message());
    r.invia();
    esci(101)
}
