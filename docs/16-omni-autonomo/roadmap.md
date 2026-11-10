# Roadmap progressiva del sistema OMNI autonomo (K0–K12)

Ogni milestone:
- parte solo dopo che quella precedente ha superato i suoi criteri;
- produce prove automatiche in QEMU (log seriale, schermate via QMP, rapporti dei test);
- si chiude con una PR in bozza e un rapporto.

Le durate non sono promesse: dipendono dai risultati e vengono riviste a ogni chiusura.

| Milestone | Contenuto | Uscita verificabile |
|---|---|---|
| **K0** Fondamenta | Repository `omni-core/` (Cargo workspace), toolchain Rust stabile fissata, `xtask` per costruire l'immagine di avvio, CI con QEMU+OVMF, `cargo-deny` per le licenze, conteggio di `unsafe` | CI verde che avvia una "hello" UEFI e ne legge l'output seriale |
| **K1** Kernel autonomo in QEMU | OMNI Boot (UEFI) → kernel nella metà alta; seriale, GDT/TSS/IDT, eccezioni, paging proprio, allocatore di frame, heap, ACPI statico (RSDP/XSDT/MADT/HPET), APIC + timer, thread del kernel con cambio di contesto, framebuffer GOP con schermata OMNI, tastiera PS/2 | Vedi [`milestone-k1.md`](milestone-k1.md): 12 criteri automatici |
| **K2** Memoria e CPU | Gestore della memoria virtuale (regioni, mappature su richiesta, copy-on-write), allocatore slab, avvio SMP di tutte le CPU, TLB shootdown, spegnimento ACPI (\_S5) e riavvio | prove di stress della memoria e di SMP (4 CPU in QEMU), spegnimento pulito |
| **K3** Processi | Modalità utente (ring 3), `syscall`/`sysret`, caricatore ELF, processi e thread utente, scheduler preemptivo SMP con priorità, segnali/eccezioni utente, `omni-std` minimo | un processo utente separato stampa, alloca e termina; un errore di un processo non blocca il kernel |
| **K4** IPC e capability | Canali a messaggi, memoria condivisa, eventi, capability con trasferimento e revoca, server dei nomi, primi servizi utente (console, log, init OMNI) | spostamento del driver seriale e del framebuffer in servizi utente; prove di isolamento |
| **K5** Archiviazione | virtio-blk, AHCI, NVMe; layer a blocchi; VFS; FAT32 (lettura/scrittura); **OMNIFS** v1 (journal, checksum dei metadati) | creazione, lettura e verifica di file su un disco virtuale; fuzzing dei parser |
| **K6** Input e grafica | PS/2 completo, xHCI + HID USB (tastiera/mouse), compositore software (doppio buffer, aggiornamento delle regioni cambiate, cursore), virtio-gpu 2D, modalità GOP native | finestre spostabili con il mouse in QEMU; misure di fotogrammi e latenza |
| **K7** OMNI UI e shell | Toolkit dichiarativo in Rust con il linguaggio visivo OMNI (colori, Inter, icone, componenti); shell (barra, Start, pannelli, notifiche); app essenziali (Impostazioni, Esplora file, Gestione attività, Terminale, Editor) | desktop OMNI in QEMU, prove interattive via QMP come per la 0.3/0.4 |
| **K8** Rete | virtio-net, e1000/e1000e, stack TCP/IP (proprio o `smoltcp`, da decidere), DHCP, DNS, TLS (scelta della libreria da presentare) | ping, HTTP, download verificato con hash in QEMU |
| **K9** Sicurezza e aggiornamenti | Utenti e sessione, permessi per app, sandbox, firma dei pacchetti OMNI, aggiornamenti A/B con ritorno indietro, Secure Boot con chiavi proprie (solo in VM) | aggiornamento e ritorno indietro automatici in QEMU; prove di sandbox |
| **K10** Audio e periferiche | Intel HDA (QEMU e PC comuni), USB storage, gestione dell'energia | audio in QEMU; chiavetta USB virtuale |
| **K11** Pilota su hardware reale | Avvio su un **PC di prova dedicato** autorizzato dal proprietario (mai il PC principale), registro dell'hardware funzionante | elenco dell'hardware verificato, con prove fotografiche e log |
| **K12** Ecosistema | SDK OMNI, pacchetti OMNI, `omni-libc` (sottoinsieme POSIX) per il porting di software C selezionato, valutazione del porting di un browser | prima app di terzi portata e documentata |

## Dettaglio per area

### Avvio UEFI
- **K0:** applicazione UEFI minima.
- **K1:** OMNI Boot carica `kernel.elf` dalla partizione EFI, prende la mappa di memoria,
  la modalità GOP e l'indirizzo RSDP, poi chiama `ExitBootServices`. Imposta le tabelle di
  pagine iniziali e salta nella metà alta.
- **K9:** verifica della firma del kernel; menu di ripristino con la versione precedente.

### Memoria
- **K1:** allocatore di frame a bitmap, ricavato dalla mappa UEFI, e paging a 4 livelli
  proprio, con NX/WP. Heap del kernel (allocatore a liste libere, poi slab in K2).
- **K2:** spazi d'indirizzi per processo, mappature su richiesta, copy-on-write, pagine di
  guardia, statistiche per Gestione attività.

### Processi e scheduler
- **K1:** thread del kernel, cambio di contesto e scheduler round-robin guidato dal timer.
- **K3:** processi utente e scheduler a priorità con code per CPU.
- **K4:** limiti di risorse per processo, equivalenti funzionali dei cgroup.

### Driver
- Ordine guidato da QEMU prima e da hardware comune poi: seriale → framebuffer → PS/2 →
  APIC/HPET → virtio → AHCI/NVMe → xHCI → e1000 → HDA.
- Ogni driver nasce con un test in QEMU. Da K4 i driver si spostano in spazio utente.
- **Fuori programma senza prove:** GPU NVIDIA accelerata, Wi-Fi, Bluetooth, webcam.

### Filesystem
- FAT32, per la partizione EFI e le chiavette.
- OMNIFS: journal da v1, checksum dei metadati, snapshot dopo K9.
- Il VFS separa i nomi dai driver.

### Grafica
- Sempre disponibile: framebuffer GOP con compositore software.
- In VM: virtio-gpu.
- L'accelerazione 3D su hardware reale si valuterà solo per GPU con documentazione aperta
  (AMD/Intel), come progetto a parte.

### Servizi
- `omni-init`: avvio dei servizi, dipendenze, riavvio in caso di errore.
- Servizi di log, configurazione, sessione, input, compositore, rete, archiviazione,
  aggiornamenti e pacchetti.
- IPC tipizzato con interfacce descritte in un file di definizione OMNI, non D-Bus.

## Punti di decisione già previsti

| Quando | Decisione |
|---|---|
| prima di K1 | ADR 0007–0011: linguaggio, modello del kernel, caricatore, formati, dipendenze |
| prima di K5 | struttura su disco di OMNIFS |
| prima di K7 | toolkit OMNI UI proprio, oppure porting di un toolkit esistente (es. porting di Qt tramite un plugin QPA: licenza LGPL, dipendenza da una libc) |
| prima di K8 | stack TCP/IP e libreria TLS |
| prima di K11 | PC di prova dedicato e procedura di avvio (USB di prova, nessun disco dell'utente) |
| prima di K12 | strategia libc/POSIX e browser |
