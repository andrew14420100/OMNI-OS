# Milestone K1 — kernel OMNI autonomo in QEMU

**Obiettivo:** un kernel OMNI scritto da zero che parte via UEFI in QEMU e inizializza le
funzioni fondamentali della CPU e della memoria. Ogni passo produce una prova automatica.

**Non contiene:**
- modalità utente;
- filesystem su disco;
- rete;
- desktop.

Gli elementi esclusi arrivano da K3 in poi, come da [`roadmap.md`](roadmap.md).

## Ambiente di prova

- **Macchina emulata:** QEMU `q35`, 2 GB di RAM, 1 e poi 4 CPU, firmware **OVMF** (UEFI,
  EDK II). Si prova con KVM, disponibile sui runner di GitHub, e senza KVM (TCG), per
  verificare che non ci siano dipendenze dalla velocità.
- **Supporto di avvio:**
  - cartella che QEMU espone come disco FAT (`-drive file=fat:rw:esp/`);
  - in alternativa, immagine disco grezza GPT+FAT32 creata dallo strumento `xtask`.

  **Nessuna ISO.**
- **Uscite:**
  - porta seriale COM1 (log del kernel);
  - dispositivo `isa-debug-exit`, che restituisce a CI il codice "superato/fallito";
  - schermate catturate via QMP;
  - tastiera simulata via QMP.
- **Riproducibilità:** versione di Rust fissata (`rust-toolchain.toml`), `Cargo.lock`
  versionato, hash dei binari nel rapporto.

## Struttura del codice prevista

```
omni-core/
  rust-toolchain.toml        # Rust stabile, versione fissa
  boot/                      # OMNI Boot (x86_64-unknown-uefi)
  kernel/                    # kernel OMNI (x86_64-unknown-none)
    src/arch/x86_64/         # GDT, IDT, stub delle interruzioni (global_asm!), paging, APIC
    src/mem/                 # frame, page table, heap
    src/acpi/                # tabelle statiche
    src/sched/               # thread del kernel, cambio di contesto
    src/dev/                 # seriale, framebuffer, PS/2, HPET
    src/ktest/               # test eseguiti nel kernel (--features ktest)
  abi/                       # BootInfo condiviso fra boot e kernel (formato versionato)
  xtask/                     # build, immagine di avvio, avvio di QEMU, raccolta delle prove
  tests/                     # script QMP, verifiche delle schermate
```

## Criteri di accettazione (tutti automatici)

| ID | Criterio | Prova prodotta |
|---|---|---|
| K1-01 | OMNI Boot parte in OVMF e scrive sulla seriale fornitore del firmware, revisione UEFI, numero e totale delle regioni di memoria, modalità GOP scelta e indirizzo RSDP | log seriale confrontato con i valori attesi di QEMU (es. 2 GB ± le aree riservate) |
| K1-02 | Il caricatore verifica l'ELF del kernel (magic, classe, macchina, segmenti), lo carica nella metà alta e chiama `ExitBootServices`. Il kernel stampa `OMNI kernel K1` con l'hash del proprio binario | log seriale; l'hash coincide con quello calcolato in CI |
| K1-03 | GDT e TSS del kernel, IDT con le 32 eccezioni; `int3` gestito con ripresa; double fault su uno stack IST separato | test nel kernel: breakpoint ripreso; un overflow di stack provocato produce un rapporto di double fault, non un riavvio silenzioso |
| K1-04 | Tabelle di pagine proprie (4 livelli) con NX/WP attivi. Il codice del kernel è non scrivibile, i dati non eseguibili. Una pagina non mappata genera un page fault con CR2 e codice d'errore | test: scrittura sul codice → page fault riportato; esecuzione da dati → page fault NX |
| K1-05 | Allocatore di frame dalla mappa UEFI: il totale libero concorda con la mappa; 10 000 cicli di allocazione e rilascio senza perdite | contatori nel log e test nel kernel |
| K1-06 | Heap del kernel: `Box`, `Vec` e `BTreeMap` funzionano; prova con 1 milione di allocazioni casuali con verifica del contenuto | test nel kernel |
| K1-07 | ACPI statico: firma e checksum di RSDP/XSDT, MADT (numero di CPU e indirizzo dell'IOAPIC), HPET | log confrontato con le opzioni di QEMU: con `-smp 4` si trovano 4 CPU |
| K1-08 | Local APIC e IOAPIC; PIC 8259 disattivato; timer APIC calibrato con l'HPET a 100 Hz | dopo 2 s di orologio QEMU il contatore dei tick è 200 ± 10% |
| K1-09 | Due o più thread del kernel alternati dal timer (preemptivi), con un cambio di contesto che salva tutti i registri | il log mostra l'alternanza; un test verifica che i registri di ciascun thread non vengano alterati |
| K1-10 | Framebuffer GOP: schermata di avvio OMNI con logo, testo in un font bitmap proprio, risoluzione e stato dei test | schermata QMP; controllo automatico dei pixel in posizioni note (sfondo, logo, testo) |
| K1-11 | Tastiera PS/2 (i8042): i tasti inviati via QMP compaiono a schermo e nel log | test QMP `send-key` → testo atteso nel log |
| K1-12 | Errore controllato: un `panic` del kernel mostra un rapporto leggibile su seriale e a schermo e ferma la CPU | variante di prova che provoca un panic; rapporto atteso |

**Qualità del codice, verificata in CI:**
- `cargo clippy` senza avvisi;
- `cargo fmt`;
- `cargo-deny`: solo licenze ammesse;
- numero di blocchi `unsafe` riportato nel rapporto, ciascuno con un commento `SAFETY:`;
- test unitari sul computer di build per la logica pura (allocatore, parser ELF e ACPI su
  dati di esempio);
- build senza warning sia con KVM sia con TCG.

## Prove consegnate al proprietario

1. Run di GitHub Actions con il rapporto `k1.md`: ogni criterio OK/FALLITO con il tempo.
2. Log seriale completo dell'avvio.
3. Schermate della schermata OMNI in QEMU, a 1 e a 4 CPU.
4. Hash dei binari (`omni-boot.efi`, `kernel.elf`) e versione della toolchain.
5. Conteggio delle righe di codice e dei blocchi `unsafe`.

Facoltativo, solo su richiesta: un'immagine disco grezza per provarlo in VirtualBox con EFI
attivo, da artifact e non da release, come per le VM precedenti. Nessuna installazione e
nessuna ISO.

## Rischi specifici di K1

| Rischio | Mitigazione |
|---|---|
| Interruzioni con Rust stabile (`abi_x86_interrupt` richiede nightly) | stub in `global_asm!` che salvano i registri e chiamano funzioni Rust `extern "C"`: Rust stabile |
| Errori di temporizzazione con TCG | calibrazione tramite HPET e tolleranze nei criteri |
| Mappa di memoria UEFI con regioni inattese | il parser rifiuta le regioni incoerenti e lo registra; test con mappe di esempio |
| Crate esterni | solo quelli approvati nell'ADR-0011; per K1 la proposta è **nessuna dipendenza nel kernel** e, nel caricatore, scrittura diretta dei binding UEFI necessari |

## Fuori da K1 (dichiarato)

- SMP oltre il conteggio delle CPU: solo la CPU di avvio esegue codice; le altre arrivano
  in K2.
- Spegnimento ACPI: in K1 si usa `isa-debug-exit`, solo in QEMU.
- Hardware reale: nessuna prova in K1.
