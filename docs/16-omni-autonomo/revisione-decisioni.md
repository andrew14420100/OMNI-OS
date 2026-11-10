# Le 55 decisioni nel sistema autonomo

Le 55 decisioni restano il **riferimento** e non vengono cancellate. Questa tabella indica
quali valgono così come sono, quali presuppongono Linux/Fedora/KDE e vanno **riviste dal
proprietario**, e quali sono **sospese** per i vincoli attuali: nessuna IA, nessun costo
obbligatorio.

**Legenda:**
- **C** confermata, indipendente dalla piattaforma;
- **R** da rivedere, perché presuppone Linux/KDE (motivo nella tabella);
- **S** sospesa per vincolo del proprietario (nessuna funzione IA);
- **C/R** il concetto resta, la base tecnica indicata in origine va sostituita.

## Decisioni originali da sostituire dopo gli ADR accettati il 2026-11-10

Il proprietario ha accettato gli ADR-0007, 0008, 0009 e 0011. Ha inoltre chiesto un sistema
finale **senza Linux, Fedora o KDE a runtime**.

Quattro decisioni originali sono in **conflitto diretto** con queste scelte: per il sistema
autonomo **devono essere sostituite**. Il testo sostitutivo è una **proposta** e non è in
vigore finché il proprietario non lo approva. Le decisioni originali restano registrate,
invariate, e valgono per le versioni 0.x già prodotte.

| # | Decisione originale | Conflitto | Testo sostitutivo proposto (da approvare) |
|---|---|---|---|
| 4 | Desktop ibrido (KDE Plasma 6 + componenti OMNI) | KDE a runtime escluso | Desktop OMNI completo: compositore, shell e app OMNI, senza componenti KDE |
| 22 | OMNI Window Manager (script/effetti KWin, compositore non sostituito) | KWin a runtime escluso | Compositore e gestore finestre OMNI originali, servizio utente del kernel OMNI (K6–K7) |
| 50 | Base Linux Fedora Kinoite | Linux e Fedora a runtime esclusi | Base: kernel OMNI originale (ADR-0007/0008/0009), avvio tramite OMNI Boot |
| 51 | Architettura (ADR-0006) | ADR-0006 presuppone Linux, systemd e D-Bus | Architettura del sistema autonomo: `docs/16-omni-autonomo/README.md` e ADR-0007/0008 |

**Tutte le altre decisioni contrassegnate "R" o "C/R" nella tabella sotto restano "da
rivedere".** Questa approvazione **non** le modifica. Saranno proposte una per una quando la
roadmap arriverà alle aree che toccano. Per esempio: 10 e 19 prima di K12; 52 dopo K1, con
la nuova roadmap; 11, 12, 15 e 16 prima delle rispettive milestone.

## Tabella completa

| # | Decisione | Esito | Motivo e proposta |
|---|---|---|---|
| 1 | Sistema operativo autonomo | **C (rafforzata)** | ora con kernel e ambiente propri |
| 2 | Hardware iniziale | R | presupponeva i driver NVIDIA per Linux; ora: QEMU, poi un PC di prova; nessuna accelerazione NVIDIA promessa |
| 3 | Installazione su SSD separato | C (rinviata) | resta valida, ma solo dopo K11 e con autorizzazione esplicita |
| 4 | Desktop ibrido | R | era "KDE Plasma + componenti OMNI"; diventa desktop OMNI completo |
| 5 | Identità grafica | C | linguaggio visivo già progettato (riuso) |
| 6 | Desktop intelligente | C/S | dock e widget sì; parte IA sospesa |
| 7 | Multitasking ibrido | C/R | concetto confermato; il gestore finestre diventa il compositore OMNI (non KWin); la parte IA è sospesa |
| 8 | AI ibrida | S | nessuna funzione IA |
| 9 | Assistente avanzato | S | nessuna funzione IA |
| 10 | Compatibilità software | R | Wine/Proton/Flatpak sono Linux; nessuna compatibilità promessa; porting tramite libc in K12 |
| 11 | OMNI Store | C/R | Store sì, su pacchetti OMNI firmati invece che Flatpak |
| 12 | OMNI File Manager | C/R | basato su VFS OMNI invece di KIO/Dolphin; parte IA sospesa |
| 13 | OMNI Performance Center | C/R | dati dal kernel OMNI; NVML (NVIDIA) non disponibile |
| 14 | OMNI Security Center | C/R | capability e sandbox OMNI invece di firewalld/SELinux/LUKS; cifratura del disco da progettare |
| 15 | OMNI Update Center | C/R | aggiornamenti A/B OMNI invece di ostree/bootc |
| 16 | OMNI Identity | C/R | gestione utenti OMNI invece di SDDM/PAM/systemd-homed |
| 17 | OMNI Search | C/R/S | indice OMNI invece di Baloo; indice semantico (IA) sospeso |
| 18 | OMNI Media Suite | R | FFmpeg/Kdenlive/mpv richiedono il porting (K12); formati aperti prima |
| 19 | OMNI Browser | R | Firefox/Chromium non disponibili senza un porting enorme; rischio RK-05 |
| 20 | OMNI Control Center | C | |
| 21 | OMNI Personalization | C/S | la parte IA è sospesa |
| 22 | OMNI Window Manager | R | era "script/effetti KWin, compositor non sostituito"; ora compositore OMNI proprio |
| 23 | OMNI Connect | R | KDE Connect non disponibile; da riprogettare dopo la rete (K8) |
| 24 | OMNI Automation Studio | C/S | automazioni senza IA possibili più avanti; agenti IA sospesi |
| 25 | OMNI Developer Studio | R | Toolbx/IDE esistenti sono Linux; SDK OMNI in K12 |
| 26 | OMNI Storage Center | C/R | OMNIFS e driver OMNI invece di UDisks2 |
| 27 | OMNI Network Center | C/R | stack di rete OMNI invece di NetworkManager |
| 28 | OMNI System Doctor | C/R/S | log OMNI invece di journald; parte IA sospesa |
| 29 | OMNI Installer | R (rinviata) | non Anaconda/bootc; installer OMNI solo dopo K11, con autorizzazione |
| 30 | OMNI Welcome Experience | C/S | parte IA sospesa |
| 31 | OMNI Audio Center | C/R | driver HDA e mixer OMNI invece di PipeWire (K10) |
| 32 | OMNI Gaming Hub | R | Steam/Proton non disponibili; nessuna promessa |
| 33 | OMNI Voice | S | riconoscimento vocale con modelli: sospeso (IA) |
| 34 | OMNI Office Suite | R | LibreOffice richiede un porting; editor di testo OMNI prima |
| 35 | OMNI Productivity Hub | R | Thunderbird/Kontact non disponibili |
| 36 | OMNI Communication Hub | R | client esistenti non disponibili |
| 37 | OMNI Display Center | C/R | modalità GOP/virtio-gpu; HDR/VRR non disponibili |
| 38 | OMNI Maintenance Center | C/R | servizi OMNI |
| 39 | OMNI Accessibility | C/R | AT-SPI/Orca non disponibili: accessibilità integrata in OMNI UI (contrasto, ingrandimento, movimento ridotto; lettore di schermo più avanti) |
| 40 | OMNI Extensions | C | API OMNI stabili e sandbox |
| 41 | OMNI AI Control | S | |
| 42 | OMNI AI Model Center | S | |
| 43 | OMNI AI Memory | S | |
| 44 | OMNI Remote | C (rinviata) | dopo la rete e la sicurezza; disattivata di default |
| 45 | OMNI Device Manager | C/R | gestore dei driver OMNI invece di udev |
| 46 | OMNI Power Center | C/R | ACPI OMNI invece di power-profiles-daemon |
| 47 | OMNI Recovery | C/R | ripristino A/B e avvio di emergenza OMNI invece di ostree e USB live |
| 48 | OMNI Cloud | C (rinviata) | facoltativa, nessun abbonamento obbligatorio |
| 49 | OMNI Terminal | C/R/S | terminale OMNI proprio; la parte IA è sospesa |
| 50 | Base Linux Fedora Kinoite | **R (sostituita, se approvato)** | la base diventa il kernel OMNI. Fedora resta nelle versioni 0.x già prodotte |
| 51 | Architettura | R | ADR-0006 (linguaggi, IPC, privilegi) va sostituito da ADR-0007/0008 |
| 52 | Ordine di sviluppo | R | le milestone M1–M8 lasciano il posto a K0–K12 per il sistema autonomo |
| 53 | Gestione risorse | C/R | limiti di risorse nel kernel OMNI invece di cgroup v2; NVML non disponibile |
| 54 | Qualità | C | CI, QEMU, prove verificabili (l'SSD isolato arriva solo dopo K11) |
| 55 | Claude | C | stesso processo: branch, PR in bozza, nessun merge senza autorizzazione |

**Riepilogo (55 righe):**
- confermate così come sono: 9 (1, 3, 5, 20, 40, 44, 48, 54, 55);
- concetto confermato, ma la base tecnica Linux/KDE va sostituita con componenti OMNI
  (C/R): 20;
- da rivedere, perché il loro contenuto presuppone Linux/KDE o software non disponibile
  (R): 16, tra cui le più importanti sono 4, 10, 19, 22, 50, 51 e 52;
- concetto confermato con la parte IA sospesa (C/S): 4 (6, 21, 24, 30);
- sospese del tutto per il vincolo "nessuna IA" (S): 6 (8, 9, 33, 41, 42, 43).

Fra le C/R, anche 7, 12, 17, 28 e 49 hanno una parte IA sospesa.

Le revisioni diventano effettive solo con l'approvazione del proprietario.
