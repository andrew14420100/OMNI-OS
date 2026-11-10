# 16 — OMNI OS autonomo: progetto architetturale (proposta, nessun codice del kernel)

- **Stato:** proposta per il proprietario. Nessuna riga del nuovo kernel è stata scritta.
- **Data:** 2026-11-10
- **Sostituisce:** nessuna decisione. Le 55 decisioni restano il riferimento; la revisione
  proposta è in [`revisione-decisioni.md`](revisione-decisioni.md).
- **Scelte da approvare:** ADR-0007 … ADR-0011 in [`../02-adr/`](../02-adr/README.md).

## Documenti

| Documento | Contenuto |
|---|---|
| Questo file | Obiettivo, fattibilità, architettura, componenti originali, dipendenze, rischi |
| [`roadmap.md`](roadmap.md) | Piano progressivo K0–K12: kernel, avvio UEFI, memoria, processi, driver, filesystem, grafica, servizi |
| [`milestone-k2.md`](milestone-k2.md) | Milestone K2: SMP, memoria virtuale, energia ACPI (criteri) |
| [`k2-risultati.md`](k2-risultati.md) | **Risultati di K2**: 20/20 criteri (K1+K2) in CI, KVM e TCG a 1 e 4 CPU, riavvio e spegnimento ACPI |
| [`k1-risultati.md`](k1-risultati.md) | **Risultati di K1**: 12/12 criteri superati in CI (QEMU KVM e TCG), schermate e rapporto |
| [`milestone-k1.md`](milestone-k1.md) | Prima milestone verificabile: kernel OMNI autonomo in QEMU, con criteri di accettazione e prove |
| [`riuso.md`](riuso.md) | Cosa del lavoro già fatto si riusa, legalmente e tecnicamente, e cosa va riscritto |
| [`revisione-decisioni.md`](revisione-decisioni.md) | Le 55 decisioni: confermate, da rivedere (presuppongono Linux/KDE), sospese |
| [`linguaggi-e-strumenti.md`](linguaggi-e-strumenti.md) | Valutazione di linguaggi, strumenti e modelli di kernel |

## 1. Stato del lavoro precedente (conservato, non eliminato)

| Versione | Dove | Stato |
|---|---|---|
| M0/M1 (documentazione, immagine Kinoite) | `main`, PR #1/#2 | invariato |
| 0.3.0 desktop reale | branch `claude/omni-desktop-reale`, PR #6 (bozza) | invariato, verificato |
| 0.4.0 evoluzione | branch `claude/omni-0.4-evoluzione`, PR #7 (bozza) | **sospesa** come base definitiva; ultimo commit `ab5d75d` (CI corretta), nessuna run finale avviata |

La 0.4.0 resta utile come **prototipo di riferimento dell'esperienza utente**. Le
schermate, i flussi, i testi e le misure servono da specifica per le app OMNI native.
Non è più la base del sistema finale.

## 2. Obiettivo, in termini verificabili

Un sistema operativo il cui **codice in esecuzione è scritto per OMNI** e dipende solo da
standard aperti dell'hardware: UEFI, ACPI, x86-64, PCI Express, AHCI, NVMe, xHCI, virtio.
Ne fanno parte:
- caricatore UEFI;
- kernel;
- gestione della memoria e dei processi;
- driver;
- filesystem;
- servizi;
- grafica e compositore;
- toolkit dell'interfaccia;
- applicazioni.

Linux, Fedora, KDE, KWin, Qt, systemd e D-Bus non sono presenti a runtime.

**Cosa NON significa autonomia** (come da indicazione del proprietario):
- Gli **strumenti di sviluppo** restano esterni e gratuiti: compilatore Rust/LLVM, QEMU,
  firmware OVMF per le prove, GitHub Actions.
- Le **librerie di terze parti** sono ammesse solo se rispettano tutte queste condizioni:
  - licenza permissiva compatibile;
  - nessun legame con Linux;
  - sostituibili;
  - elencate e approvate una per una.

  Vedi ADR-0011. L'opzione "zero dipendenze" è possibile, ma più lenta.

## 3. Fattibilità: valutazione onesta

### 3.1 Che cosa è realistico

| Obiettivo | Fattibilità | Ordine di grandezza |
|---|---|---|
| Kernel che si avvia in QEMU via UEFI, con memoria, interruzioni, timer e thread (K1) | **Alta** | settimane di iterazioni con prove automatiche |
| Processi in modalità utente, chiamate di sistema, ELF, IPC (K3–K4) | Alta | mesi |
| Disco virtuale (virtio), filesystem OMNI, FAT32 (K5) | Alta | mesi |
| Desktop grafico OMNI in QEMU: compositore software, toolkit, shell, app di base (K6–K7) | Media | molti mesi |
| Rete TCP/IP con driver virtio/e1000 (K8) | Media | mesi |
| Avvio su un **PC di prova dedicato**, con risoluzione nativa via GOP, NVMe, USB e tastiera/mouse | Media-bassa | dopo K10, con hardware dedicato |
| Uso quotidiano paragonabile a Windows | **Bassa nel medio periodo** | anni, come per ogni sistema operativo indipendente |

### 3.2 Che cosa NON viene promesso (senza prove)

- **Esecuzione di applicazioni Windows o Linux.** Un livello di compatibilità è un progetto
  a sé; ReactOS lo insegue da oltre 25 anni.
- **Accelerazione 3D sulla RTX 5070 Ti.** NVIDIA non pubblica una documentazione
  sufficiente per un driver indipendente. Il massimo realistico è il framebuffer GOP fornito
  dal firmware della scheda: un'immagine a risoluzione nativa, senza accelerazione.
- **Wi-Fi e Bluetooth reali.** Richiedono firmware proprietario e driver specifici per
  ciascun chip.
- **Browser web moderno.** Un motore completo (HTML, CSS, JavaScript) richiede milioni di
  righe. Il porting di un motore esistente richiede prima uno strato POSIX/libc (vedi K12).
- **Giochi Steam, codec proprietari, HDR/VRR.**

### 3.3 Termini di paragone (sistemi reali indipendenti)

| Sistema | Linguaggio | Anni di sviluppo | Stato |
|---|---|---|---|
| SerenityOS | C++ | dal 2018, centinaia di contributori | desktop completo, browser proprio, hardware reale limitato |
| Redox OS | Rust, microkernel | dal 2015 | desktop e porting di software, hardware reale limitato |
| Haiku | C++ | dal 2001 | uso quotidiano possibile su hardware supportato |
| ReactOS | C | dal 1996 | compatibilità Windows parziale, ancora alfa |

**Conclusione:** il progetto è fattibile **per gradi**, e ogni grado produce un risultato
concreto e verificabile. Il primo è il kernel in QEMU. Una sostituzione completa di Windows
sul PC principale non è un obiettivo con una data credibile, e questo documento non la
promette.

## 4. Architettura proposta

### 4.1 Scelte di fondo (da approvare)

| Tema | Proposta | Alternativa principale | ADR |
|---|---|---|---|
| Linguaggio | **Rust stabile** (con assembly minimo per l'avvio e le interruzioni) | C; Zig | 0007 |
| Modello del kernel | **Kernel ibrido orientato al microkernel**: nel kernel memoria, scheduler, IPC, capability e driver essenziali di avvio; driver, filesystem, rete e grafica in servizi utente man mano che l'IPC matura | monolitico; microkernel puro | 0008 |
| Avvio | **Caricatore UEFI OMNI** (OMNI Boot, applicazione UEFI scritta da zero) | Limine (BSD, maturo) | 0009 |
| Formati | ELF64 per kernel e programmi, GPT/FAT32 per la partizione di sistema EFI, filesystem OMNI per i dati | PE/COFF | 0010 |
| Dipendenze nel codice eseguito | Solo crate permissivi approvati, elencati in un registro; nessuna libreria GPL nel kernel | zero dipendenze | 0011 |

### 4.2 Strati

```
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ L6  App OMNI: Impostazioni, Gestione attività, Esplora file, Terminale,    │
 │     Editor, Visualizzatore immagini, Store (pacchetti OMNI firmati)        │
 ├───────────────────────────────────────────────────────────────────────────┤
 │ L5  OMNI UI (toolkit dichiarativo in Rust, linguaggio visivo OMNI)         │
 │     + Shell OMNI (barra, Start, pannelli, notifiche)                       │
 ├───────────────────────────────────────────────────────────────────────────┤
 │ L4  Servizi utente: compositore/finestre, input, sessione, configurazione, │
 │     rete, archiviazione, audio, pacchetti, aggiornamenti A/B, sicurezza    │
 ├───────────────────────────────────────────────────────────────────────────┤
 │ L3  Driver in spazio utente (dopo K4): virtio, AHCI, NVMe, xHCI/HID,       │
 │     e1000, HDA; accesso all'hardware solo tramite capability concesse      │
 ├───────────────────────────────────────────────────────────────────────────┤
 │ L2  Librerie di sistema: omni-std (chiamate di sistema, IPC, async),       │
 │     omni-libc (sottoinsieme C, solo per il porting, K12)                   │
 ├───────────────────────────────────────────────────────────────────────────┤
 │ L1  Kernel OMNI (Rust): memoria fisica/virtuale, processi e thread,        │
 │     scheduler SMP, IPC a messaggi e memoria condivisa, capability,          │
 │     interruzioni/APIC, timer, ACPI di base, console, log                    │
 ├───────────────────────────────────────────────────────────────────────────┤
 │ L0  OMNI Boot (applicazione UEFI): mappa memoria, GOP, ACPI RSDP,          │
 │     caricamento ELF del kernel, passaggio di BootInfo                       │
 └───────────────────────────────────────────────────────────────────────────┘
   Firmware UEFI (standard aperto, non OMNI) — hardware x86-64
```

### 4.3 Principi di sicurezza (validi da K1)

- **Rust sicuro per impostazione predefinita.** Ogni `unsafe` è isolato in moduli
  dell'hardware, commentato con l'invariante che garantisce e contato in CI. Un aumento
  non giustificato blocca la PR.
- **W^X**: nessuna pagina è scrivibile ed eseguibile insieme. Bit NX, SMEP e SMAP sono
  attivi quando la CPU li supporta. Il kernel risiede nella metà alta dello spazio
  d'indirizzi, con pagine di guardia per gli stack.
- **Capability**: un processo accede solo agli oggetti (memoria, porte I/O, interruzioni,
  canali IPC, file) per cui ha ricevuto un riferimento esplicito. Non esiste un "root"
  onnipotente; i privilegi amministrativi sono capability concesse dall'utente con
  conferma.
- **Avvio verificabile**: hash del kernel registrato da OMNI Boot. La firma del kernel con
  chiavi OMNI e il Secure Boot con chiavi proprie arrivano più avanti (K9). Il firmware del
  PC dell'utente non viene toccato.
- **Aggiornamenti A/B atomici** con ritorno alla versione precedente (K9), come principio
  già scelto per la base Fedora (decisione 15).

### 4.4 Interfaccia binaria

- **Chiamate di sistema OMNI** (`syscall`/`sysret`), numerate e versionate in un crate
  condiviso (`omni-abi`).
- Nessuna emulazione delle chiamate di Linux né di Windows.
- Per portare software C esistente (K12) si valuterà uno strato libc. Per esempio relibc
  di Redox (licenza MIT) o una libc propria; la scelta sarà presentata prima.

## 5. Componenti originali e componenti esterni

| Componente | Origine | Note |
|---|---|---|
| OMNI Boot, kernel, scheduler, gestione memoria, IPC, capability | **Originale** | Rust + assembly x86-64 minimo |
| Driver (seriale, framebuffer, PS/2, APIC/IOAPIC, HPET, virtio, AHCI, NVMe, xHCI, e1000, HDA) | **Originale**, scritti dalle specifiche pubbliche | specifiche: Intel SDM, AMD APM, ACPI, UEFI, virtio OASIS, NVMe, AHCI, xHCI |
| Filesystem OMNI (OMNIFS) | **Originale** | FAT32 implementato da zero per la partizione EFI e le chiavette |
| Compositore, OMNI UI, shell, app | **Originale** | riprende il linguaggio visivo già progettato |
| Parser ACPI/AML | Proposta: originale per le tabelle statiche; per l'AML valutare il crate `aml`/`acpi` (MIT/Apache) contro una scrittura propria | l'AML completo è grande |
| Stack TCP/IP | Proposta: originale; alternativa `smoltcp` (0BSD) | decisione in K8 |
| Font | **Inter** (SIL OFL 1.1, già usato) e un font bitmap proprio per la console | la OFL permette l'inclusione |
| Strumenti di sviluppo | rustc/LLVM (MIT/Apache), QEMU (GPL, solo strumento), OVMF/EDK II (BSD-2-Clause-Patent, solo per le prove) | non fanno parte del sistema eseguito |

## 6. Rischi principali

| ID | Rischio | Prob. | Impatto | Mitigazione |
|---|---|---|---|---|
| RK-01 | Il progetto è molto più grande di quanto sembri: rischio di non arrivare mai a un sistema usabile | Alta | Alto | milestone piccole, ciascuna con risultati verificabili; si valuta dopo ogni milestone |
| RK-02 | Hardware reale (ACPI con errori, USB, GPU, Wi-Fi) molto diverso da QEMU | Alta | Alto | QEMU prima; poi un **PC di prova dedicato**, mai il PC principale; elenco hardware supportato solo con prove |
| RK-03 | Nessuna accelerazione GPU (NVIDIA): grafica software lenta in 4K | Certa sulla RTX 5070 Ti | Medio | compositore software ottimizzato con aggiornamento delle sole regioni cambiate; virtio-gpu in VM; nessuna promessa |
| RK-04 | Bug di memoria o concorrenza nel kernel | Media | Alto | Rust, `unsafe` isolato e contato, test in QEMU a ogni commit, fuzzing di parser (ELF, ACPI, FAT, OMNIFS) |
| RK-05 | Mancanza di applicazioni (browser, office, media) | Certa nel medio periodo | Alto | app OMNI essenziali proprie; porting tramite libc (K12) solo dopo una valutazione |
| RK-06 | Licenze: codice GPL copiato per errore, o crate con licenza incompatibile | Bassa | Alto | nessuna copia da Linux/BSD-GPL; controllo automatico delle licenze in CI (`cargo-deny`); registro delle dipendenze |
| RK-07 | Sicurezza: kernel giovane senza revisione esterna | Alta | Alto | capability, W^X, nessuna rete fino a K8, nessun uso con dati reali fino a una revisione |
| RK-08 | Dipendenza da un unico sviluppatore/assistente: conoscenza non trasmessa | Media | Medio | documentazione per ogni modulo, ADR, test come specifica |
| RK-09 | Avvio su hardware reale che danneggia dati | Bassa | Molto alto | nessuna scrittura su dischi reali prima di K10; avvio solo da supporti di prova dedicati, con autorizzazione esplicita |

## 7. Vincoli rispettati da questa proposta

- Nessuna ISO.
- Nessuna installazione sul PC del proprietario.
- Nessuna modifica a Windows, al BIOS/UEFI o al Secure Boot.
- Nessuna funzione IA.
- Nessuna cancellazione delle versioni precedenti.
- Nessun merge e nessuna release.
- Nessuna promessa di compatibilità con app Windows, GPU NVIDIA o hardware moderno senza
  prove.

Le prove della milestone K1 si svolgono solo in QEMU su GitHub Actions, avviando una
cartella FAT o un'immagine disco grezza: niente ISO.

## 8. Prossimo passo

Dopo l'approvazione degli ADR 0007–0011, o delle modifiche indicate dal proprietario, si
apre la milestone **K1** ([`milestone-k1.md`](milestone-k1.md)) su un branch dedicato.
Il lavoro procede con PR in bozza e prove in QEMU a ogni commit.
