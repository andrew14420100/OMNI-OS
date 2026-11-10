# Milestone K2 — memoria e CPU

**Obiettivo:** il kernel K1 diventa multiprocessore. K2 aggiunge:
- avvio e uso di tutte le CPU;
- coerenza delle traduzioni d'indirizzo fra le CPU;
- memoria virtuale con allocazione su richiesta e copy-on-write;
- stress della memoria in parallelo;
- spegnimento e riavvio tramite ACPI.

Tutte le prove di K1 restano attive come prove di non regressione.

**Non contiene:**
- modalità utente e processi (K3);
- IPC (K4);
- dischi (K5).

Il copy-on-write di K2 si prova fra due regioni dello spazio del kernel. Il suo uso fra
processi arriva con K3.

## Ambiente di prova

Lo stesso di K1:
- QEMU `q35` con OVMF, 2 GiB, 1 e 4 CPU, con KVM e con TCG;
- avvio da cartella FAT, **nessuna ISO**.

Per la prova di riavvio QEMU **non** usa `-no-reboot`: il riavvio deve far ripartire davvero
il firmware e OMNI Boot. Il kernel ricorda di aver chiesto il riavvio con un byte della CMOS
(registro 0x7D). In questo modo il secondo avvio sa di essere tale ed esegue lo spegnimento.

## Criteri di accettazione (automatici)

| ID | Criterio | Prova prodotta |
|---|---|---|
| K2-01 | Avvio SMP: ogni CPU elencata nella MADT parte con la sequenza INIT-SIPI-SIPI (trampolino in modalità reale → modalità lunga). Ogni CPU ha GDT, TSS e stack IST propri, la stessa IDT e il proprio timer APIC | registro: "CPU n in linea"; numero di CPU in linea = opzione `-smp` (1 e 4) |
| K2-02 | Scheduler SMP: thread distribuiti su tutte le CPU, nessun thread eseguito da due CPU insieme. Blocco a rotazione corretto fra CPU | 4×100 000 incrementi sotto blocco = 400 000 esatti; ogni CPU ha eseguito thread di prova |
| K2-03 | Coerenza del TLB (shootdown): dopo la rimozione di una pagina, tutte le CPU che l'avevano usata ricevono l'invalidazione via IPI | ogni CPU, rileggendo la pagina dopo la rimozione, ottiene un page fault (nessuna traduzione vecchia) |
| K2-04 | Memoria virtuale su richiesta: una regione riservata riceve frame solo alla prima scrittura | 1000 pagine toccate = 1000 page fault gestiti = 1000 frame; contenuto verificato; frame restituiti al rilascio |
| K2-05 | Copy-on-write: una regione clonata condivide i frame finché non viene scritta | dopo il clone: 0 frame in più; scrittura su una pagina → 1 copia; l'originale resta invariato; contatori di riferimento corretti |
| K2-06 | Stress della memoria in parallelo: heap e frame usati da tutte le CPU insieme | 4 thread × 200 000 operazioni senza errori; memoria in uso e frame liberi tornano esattamente ai valori iniziali |
| K2-07 | Spegnimento ACPI: da FADT e DSDT (`\_S5`) il kernel spegne la macchina | QEMU termina da solo con codice 0 dopo "spegnimento ACPI" (nessun isa-debug-exit) |
| K2-08 | Riavvio ACPI (registro di reset della FADT, oppure controller 8042 come ripiego) | il registro seriale mostra un secondo avvio completo di OMNI Boot e del kernel, che riconosce il riavvio |

**Regressione:** tutti i criteri K1-01…K1-12 restano superati.

**Qualità:** come in K1:
- `rustfmt` e `clippy` senza avvisi;
- nessuna dipendenza esterna;
- ogni `unsafe` con un commento `SAFETY`;
- test sul computer di build per i nuovi parser: FADT e `\_S5` dell'AML.

## Fuori da K2 (dichiarato)

- Interprete AML completo: si legge solo il pacchetto `\_S5`.
- Gestione dell'energia oltre lo spegnimento (S3, frequenze delle CPU).
- Hardware reale.
