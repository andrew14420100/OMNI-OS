# Linguaggi, strumenti e modelli di kernel: valutazione

Criteri richiesti dal proprietario, in ordine:
1. sicurezza;
2. prestazioni;
3. manutenzione;
4. sviluppo gratuito.

## 1. Linguaggio del kernel e del sistema

| Linguaggio | Sicurezza | Prestazioni | Manutenzione | Gratuito | Note |
|---|---|---|---|---|---|
| **Rust (stabile)** | **Alta**: memoria e concorrenza verificate dal compilatore fuori dai blocchi `unsafe` | pari a C | alta: tipi espressivi, gestore di pacchetti, test integrati | sì (MIT/Apache) | target ufficiali `x86_64-unknown-none` (kernel) e `x86_64-unknown-uefi` (caricatore), senza toolchain modificate. Usato da Redox OS, da parti di Windows, Linux e Android. Curva di apprendimento più ripida |
| C (C17) | Bassa: buffer overflow, use-after-free | massima | media: nessuna protezione dal compilatore, molti strumenti esterni | sì | linguaggio storico dei kernel; la maggior parte delle vulnerabilità dei kernel nasce da errori di memoria |
| C++ | Bassa-media | massima | media: linguaggio vasto, sottoinsieme da disciplinare nel kernel | sì | SerenityOS e Haiku |
| Zig | Media | massima | **rischiosa**: linguaggio non ancora stabile (versioni 0.x, cambi incompatibili) | sì | |
| Ada/SPARK | Molto alta, con prove formali | alta | ecosistema piccolo, pochi esempi di kernel x86-64 moderni | sì (GNAT) | |

**Proposta: Rust stabile** per caricatore, kernel, servizi, toolkit e app.
- L'assembly x86-64 si limita ai punti inevitabili, tramite `global_asm!`/`asm!`: ingresso
  delle interruzioni, cambio di contesto, istruzioni privilegiate.
- Niente Rust nightly. Le funzioni che lo richiederebbero, come l'ABI `x86-interrupt`, si
  sostituiscono con stub in assembly.
- Per la logica pura, test unitari sul computer di build e fuzzing (`cargo-fuzz`, solo come
  strumento).

## 2. Modello del kernel

| Modello | Esempi | Pro | Contro |
|---|---|---|---|
| Monolitico | Linux, BSD | prestazioni, semplicità iniziale | un driver difettoso può bloccare o compromettere tutto il sistema |
| Microkernel puro | seL4, QNX, Redox | isolamento massimo; i driver si riavviano | costo dell'IPC; progettazione più difficile all'inizio |
| **Ibrido orientato al microkernel** | Windows NT, XNU (in parte), Fuchsia (Zircon) | parte semplice (driver di avvio nel kernel), poi sposta i driver in spazio utente man mano che l'IPC matura | richiede disciplina per non restare monolitico |

**Proposta: ibrido orientato al microkernel con capability.**
- In K1–K3 i pochi driver necessari restano nel kernel per avanzare rapidamente.
- Da K4 driver, filesystem, rete e grafica diventano servizi utente isolati.

## 3. Avvio

| Opzione | Pro | Contro |
|---|---|---|
| **OMNI Boot (proprio)** | nessuna dipendenza; controllo totale di formato, verifica e ripristino | lavoro iniziale: circa 1–2 mila righe |
| Limine (BSD-2) | maturo e diffuso nei kernel amatoriali; protocollo pronto | componente esterno nel percorso di avvio; meno coerente con l'obiettivo di autonomia |
| GRUB (GPLv3) | universale | grande, GPL, legato all'ecosistema Linux |

**Proposta: OMNI Boot.** Limine resta il piano B se il caricatore rallentasse troppo K1.

## 4. Strumenti di sviluppo (esterni, gratuiti, non presenti nel sistema finale)

| Strumento | Uso | Licenza |
|---|---|---|
| rustup, rustc, cargo, LLVM/lld | compilazione e collegamento | MIT/Apache |
| QEMU (`q35`, KVM/TCG, QMP) | emulazione e prove automatiche | GPLv2 (strumento) |
| OVMF / EDK II | firmware UEFI per QEMU | BSD-2-Clause-Patent (strumento) |
| GitHub Actions (runner Ubuntu con KVM) | CI, artifact | gratuito per il repository |
| `cargo-deny`, `cargo-clippy`, `rustfmt`, `cargo-fuzz` | licenze, qualità, fuzzing | MIT/Apache |
| Python 3 (script QMP già scritti) | automazione delle prove | PSF |

Il sistema di build gira su Linux (il runner di CI), ma il risultato non contiene nulla di
Linux. È la distinzione indicata dal proprietario: un sistema operativo indipendente non
obbliga a reinventare gli strumenti di sviluppo.

## 5. Formati e standard aperti adottati

- **UEFI 2.x:** avvio, GOP, mappa di memoria.
- **ACPI 6.x:** tabelle; AML più avanti.
- **x86-64:** Intel SDM e AMD APM.
- **PCI Express, virtio 1.x, AHCI, NVMe, xHCI, HID, Intel HDA.**
- **ELF64:** formato degli eseguibili, scelto perché supportato da LLVM.
- **GPT e FAT32:** dischi e partizione di sistema EFI.
- **PNG e SVG (sottoinsieme), UTF-8.**
