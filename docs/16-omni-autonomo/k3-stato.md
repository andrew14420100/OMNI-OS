# K3 — Rapporto tecnico sullo stato (incompleto)

Stato: **K3 NON completato.** Nessuno dei criteri K3-01..K3-09 è stato provato in esecuzione.
Questo documento separa ciò che è verificato da ciò che è solo scritto o manca, e registra i
blocchi incontrati.

## Verificato (test automatici e CI)

| Componente | Prova | Esito |
|---|---|---|
| Pacchetto iniziale (`comune::pacchetto`) | test: andata e ritorno, alterazioni rifiutate (impronta, magia, versione, limiti, nomi) | superati |
| ABI delle chiamate di sistema (`comune::abi`) | test sui limiti dello spazio utente | superati |
| Caricatore ELF (`comune::caricatore`) | 11 test, fuzzing su 30 000 varianti, 9 mutazioni intercettate, 7 programmi veri con 0 byte diversi dal file (`cargo xtask verifica-programmi`) | superati; dettagli in `k3-caricatore.md` |
| OMNI Boot: lettura di `\OMNI\INIZIALE.PKG` | compilazione; avvio K1/K2 invariato in CI | compilato; **lettura del pacchetto non ancora provata in QEMU** |
| `omni-std` e 7 programmi utente | clippy senza avvisi; segmenti R-X / R-- / RW-, nessuno RWE (CI) | compilati; **mai eseguiti** |
| Scheduler a tempo virtuale con priorità, CR3 e stack per thread | regressione K1/K2 in QEMU | 20/20 in CI (KVM e TCG, 1 e 4 CPU); la priorità **non** è ancora misurata da una prova dedicata |
| Regressione K1+K2 | CI run 42825227293 e 42826735195 | 20/20 |

Totale `cargo test -p omni-comune`: 31/31.

## Scritto ma non verificato (compila, mai eseguito)

- Segmenti utente nella GDT e RSP0 nel TSS (`arch/gdt.rs`).
- `arch/anelli.rs`: MSR di `syscall`/`sysret`, ingresso e uscita delle chiamate, primo ingresso
  in ring 3, SMEP/SMAP. **Non ancora riesaminato** (revisione richiesta prima dell'uso).
- `mem/spazio.rs`: spazi d'indirizzi per processo con W^X e distruzione completa.
- Gestore provvisorio delle chiamate di sistema (risponde sempre `E_NUMERO`).
- 19 eccezioni `K3-WIP` al solo avviso di codice inutilizzato, elencate da
  `cargo xtask controlli` (il controllo `-D warnings` resta attivo).

## Mancante

- Integrazione caricatore ↔ spazi d'indirizzi e relativa prova nel kernel.
- Processi e thread utente, chiamate di sistema vere, esecuzione in ring 3.
- Terminazione isolata dei processi difettosi, verifica SMEP/SMAP.
- Recupero delle risorse dei processi.
- Prove K3-01..K3-09 e loro verifica in xtask e CI.

## Blocchi incontrati

Durante la generazione del codice del kernel di K3, un filtro di sicurezza automatico ha
interrotto la risposta cinque volte. Il filtro non indica quale contenuto lo attiva. Le
interruzioni sono avvenute scrivendo:

1. il codice del kernel per ring 3 e i dati per CPU (prima tornata);
2. il seguito dopo gli stack riusabili (processi, chiamate di sistema);
3. il seguito dopo lo scheduler (processi, caricatore nel kernel, chiamate di sistema);
4. il passo 3 (integrazione del caricatore con la memoria dei processi);
5. la sola prova nel kernel di caricamento in uno spazio di prova, senza ring 3 né
   `syscall`: interrotta mentre si scriveva il file della prova.

Il filtro non è stato aggirato e nessuna implementazione bloccata è stata ripetuta. Le
modifiche non provate dell'ultimo tentativo (funzione di caricamento in `mem/spazio.rs`,
pacchetto nella partizione di avvio di xtask) **non sono state committate**: sono conservate
in uno stash locale della sessione e non fanno parte del branch.

Hanno invece superato senza problemi le parti di pura elaborazione dei dati nel crate
`comune` (pacchetto, ABI, caricatore), xtask, CI e documentazione.

## Per proseguire

Le parti mancanti sono nel kernel. Per completare K3 serve che il codice bloccato venga
scritto per altra via (dall'autore o con un altro strumento); i test, la CI e la verifica in
QEMU già predisposti (`cargo xtask rapida`, `cargo xtask prova`, `verifica-programmi`) restano
utilizzabili per verificarlo.
