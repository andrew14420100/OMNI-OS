// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Interfaccia binaria fra i programmi utente e il kernel OMNI (K3), condivisa da `omni-std`
//! e dal kernel.
//!
//! Chiamata di sistema: istruzione `syscall` con il numero in RAX e gli argomenti in RDI, RSI,
//! RDX, R10, R8; il risultato torna in RAX (valori negativi = errori `E_*`). Il kernel
//! conserva tutti i registri tranne RAX, RCX e R11 (questi due sono usati da `syscall`).

/// Scrive testo sul registro del sistema: (indirizzo, lunghezza) → byte scritti.
pub const SC_SCRIVI: u64 = 1;
/// Termina il processo: (codice) → non ritorna.
pub const SC_ESCI: u64 = 2;
/// Cede la CPU: () → 0.
pub const SC_CEDI: u64 = 3;
/// Assegna memoria al processo: (pagine) → indirizzo della prima pagina (lettura e scrittura,
/// non eseguibile, azzerata).
pub const SC_MAPPA: u64 = 4;
/// Avvia un programma del pacchetto iniziale: (nome, lunghezza del nome, argomento, priorità)
/// → identificativo del processo figlio.
pub const SC_AVVIA: u64 = 5;
/// Attende la fine di un processo figlio: (pid) → codice d'uscita.
pub const SC_ATTENDI: u64 = 6;
/// Crea un thread nel processo: (ingresso, cima dello stack, argomento) → identificativo.
pub const SC_THREAD: u64 = 7;
/// Termina il thread chiamante (l'ultimo thread chiude il processo con codice 0).
pub const SC_FINE_THREAD: u64 = 8;
/// Attende la fine di un thread dello stesso processo: (tid) → 0.
pub const SC_ATTENDI_THREAD: u64 = 9;
/// Informazioni: (chiave `INFO_*`) → valore.
pub const SC_INFO: u64 = 10;
/// Termina un processo figlio: (pid) → 0.
pub const SC_TERMINA: u64 = 11;

pub const INFO_PID: u64 = 0;
pub const INFO_CPU: u64 = 1;
pub const INFO_TEMPO_NS: u64 = 2;
pub const INFO_THREAD: u64 = 3;

/// Indirizzo fuori dallo spazio utente o pagina non accessibile.
pub const E_INDIRIZZO: i64 = -1;
/// Numero di chiamata sconosciuto.
pub const E_NUMERO: i64 = -2;
/// Programma, processo o thread inesistente (o non figlio del chiamante).
pub const E_NON_TROVATO: i64 = -3;
/// Memoria insufficiente o limite del processo superato.
pub const E_MEMORIA: i64 = -4;
/// Argomento non valido.
pub const E_ARGOMENTO: i64 = -5;

/// Codice d'uscita di un processo terminato da un'eccezione: `ECCEZIONE - vettore`.
pub const CODICE_ECCEZIONE: i64 = -1000;
/// Codice d'uscita di un processo terminato dal genitore o dal kernel.
pub const CODICE_TERMINATO: i64 = -2000;

/// Priorità dei processi (pesi nello scheduler: 1, 2, 4).
pub const PRIORITA_BASSA: u64 = 1;
pub const PRIORITA_NORMALE: u64 = 2;
pub const PRIORITA_ALTA: u64 = 3;

/// Spazio utente: da 4 MiB (le prime pagine restano vuote per intercettare i puntatori
/// nulli) fino all'ultima pagina esclusa della metà bassa (un `syscall` nell'ultima pagina
/// avrebbe un indirizzo di ritorno non canonico).
pub const UTENTE_INIZIO: u64 = 0x0000_0000_0040_0000;
pub const UTENTE_FINE: u64 = 0x0000_7fff_ffff_f000;
/// Cima dello stack del thread principale (16 pagine, guardia sotto).
pub const CIMA_STACK: u64 = 0x0000_7000_0000_0000;
pub const PAGINE_STACK: u64 = 16;
/// Inizio della memoria assegnata con `SC_MAPPA`.
pub const BASE_MAPPA: u64 = 0x0000_1000_0000_0000;
/// Pagine al massimo per processo con `SC_MAPPA` (64 MiB).
pub const MAX_PAGINE_MAPPA: u64 = 16384;

/// true se [inizio, inizio+lunghezza) è interamente nello spazio utente.
pub fn intervallo_utente(inizio: u64, lunghezza: u64) -> bool {
    match inizio.checked_add(lunghezza) {
        Some(fine) => inizio >= UTENTE_INIZIO && fine <= UTENTE_FINE,
        None => false,
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn intervalli() {
        assert!(intervallo_utente(UTENTE_INIZIO, 0));
        assert!(intervallo_utente(0x40_1000, 4096));
        assert!(intervallo_utente(UTENTE_FINE - 1, 1));
        assert!(!intervallo_utente(UTENTE_FINE - 1, 2));
        assert!(!intervallo_utente(0, 1)); // puntatore nullo
        assert!(!intervallo_utente(0x1000, 8));
        assert!(!intervallo_utente(0xffff_8000_0000_0000, 8)); // kernel
        assert!(!intervallo_utente(0xffff_ffff_8000_0000, 16));
        assert!(!intervallo_utente(UTENTE_INIZIO, u64::MAX)); // traboccamento
        assert!(!intervallo_utente(0x0000_8000_0000_0000, 1)); // non canonico
        assert!(intervallo_utente(CIMA_STACK - PAGINE_STACK * 4096, PAGINE_STACK * 4096));
        assert!(intervallo_utente(BASE_MAPPA, MAX_PAGINE_MAPPA * 4096));
    }
}
