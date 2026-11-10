# K3 — Caricatore dei programmi utente: verifica

Stato: **verificato da solo**, non ancora collegato al kernel. K3 nel suo insieme **non** è
completato (vedi la PR #11).

## Cosa è

`omni-core/comune/src/caricatore.rs`, nel crate condiviso (`no_std`, nessun `unsafe`, provato
sul computer di build):

- `pianifica(elf) -> Piano`: valida il file e calcola, per ogni segmento, l'intervallo di
  pagine con i permessi;
- `riempi_pagina(elf, segmento, k, pagina)`: contenuto della pagina `k`: byte del file dove ci
  sono, zeri altrove (inizio non allineato, `.bss`).

Il kernel userà il piano per assegnare i frame nello spazio d'indirizzi del processo; il
caricatore non tocca la memoria.

## Regole verificate

| Regola | Errore |
|---|---|
| firma, classe 64 bit, little-endian, x86-64, `ET_EXEC`, intestazioni e segmenti dentro il file, memoria ≥ file | `Elf(...)` |
| versione ELF 1 (identificazione e intestazione) | `VersioneElf` |
| ABI System V | `AbiNonSupportata` |
| solo eseguibili statici | `Interprete`, `Dinamico`, `Tls` |
| stack non eseguibile (`PT_GNU_STACK` senza X) | `StackEseguibile` |
| da 1 a 8 segmenti `PT_LOAD` non vuoti | `NessunSegmento`, `TroppiSegmenti` |
| allineamento 0, 1 o potenza di 2, con indirizzo ≡ offset | `AllineamentoNonValido` |
| segmenti in [4 MiB, `LIMITE_IMMAGINE` = 16 TiB): niente pagina nulla, kernel, traboccamenti | `FuoriSpazioUtente` |
| W^X: nessun segmento scrivibile ed eseguibile | `ScrivibileEdEseguibile` |
| nessuna pagina condivisa da due segmenti | `Sovrapposizione` |
| al massimo 4096 pagine (16 MiB) | `TroppaMemoria` |
| punto d'ingresso in un segmento eseguibile | `IngressoNonEseguibile` |

## Prove automatiche (riproducibili)

1. `cargo test -p omni-comune`: 31 test, tutti superati, di cui 11 sul caricatore:
   - positivi: programma tipico a tre segmenti più `PT_GNU_STACK`; contenuto di ogni pagina
     (file, coda azzerata, `.bss`, pagine oltre il segmento); segmenti non allineati alla
     pagina e a cavallo di due pagine; segmenti vuoti e non caricabili ignorati;
   - negativi: ogni errore della tabella, con i limiti esatti (ultimo byte ammesso accettato,
     un byte oltre rifiutato; 8 segmenti accettati, 9 rifiutati; immagine di 4095 pagine
     accettata, 4097 rifiutata), sovrapposizioni in ordine diretto e inverso, indice del
     segmento colpevole nell'errore;
   - fuzzing deterministico: 30 000 varianti alterate di intestazioni e intestazioni di
     programma; nessun panico; ogni piano accettato rispetta W^X, i limiti di spazio e di
     pagine (e il caso positivo viene davvero esercitato).
2. Prova di mutazione (eseguita a mano durante lo sviluppo): togliendo uno per volta i
   controlli di W^X, sovrapposizione, limite inferiore, limite superiore, interprete,
   numero di pagine, ingresso eseguibile, numero di segmenti, e copiando la `.bss` dal file,
   almeno un test fallisce in tutti e 9 i casi.
3. `cargo xtask verifica-programmi` (anche nella CI): costruisce i 7 programmi utente veri e
   applica il caricatore. Risultato:

| Programma | Byte | Ingresso | Pagine | Segmenti | Byte diversi dal file |
|---|---|---|---|---|---|
| ciao | 21168 | 0x4003d0 | 4 | 0x400000+2 R-X, 0x402000+1 R--, 0x403000+1 RW- | 0 |
| spazio | 21384 | 0x400320 | 4 | 0x400000+2 R-X, 0x402000+1 R--, 0x403000+1 RW- | 0 |
| memoria | 28752 | 0x400880 | 5 | 0x400000+3 R-X, 0x403000+1 R--, 0x404000+1 RW- | 0 |
| errore | 21600 | 0x4006f0 | 4 | 0x400000+2 R-X, 0x402000+1 R--, 0x403000+1 RW- | 0 |
| ciclo | 20824 | 0x4002d0 | 4 | 0x400000+2 R-X, 0x402000+1 R--, 0x403000+1 RW- | 0 |
| genitore | 28192 | 0x400a30 | 5 | 0x400000+3 R-X, 0x403000+1 R--, 0x404000+1 RW- | 0 |
| figlio | 20832 | 0x400290 | 4 | 0x400000+2 R-X, 0x402000+1 R--, 0x403000+1 RW- | 0 |

Le dimensioni dipendono dalla compilazione; il comando le ricalcola a ogni esecuzione.

## Regressione

CI run 42825227293 (commit `58cf807`, con il nuovo scheduler K3): 20/20 criteri K1+K2
superati con KVM e TCG, a 1 e 4 CPU, con riavvio e spegnimento ACPI, panico e double fault.

## Limiti

- Non ancora usato dal kernel: assegnazione dei frame, spazio d'indirizzi del processo e
  ingresso in ring 3 sono i passi successivi di K3.
- Solo eseguibili statici non PIE (scelta di K3: nessun collegamento dinamico).
