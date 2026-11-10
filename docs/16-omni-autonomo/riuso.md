# Riuso del lavoro già fatto: cosa resta, cosa si riscrive

Criteri:
- **legale**: chi possiede il codice e con quale licenza;
- **tecnico**: se può girare senza Linux, KDE e Qt.

Il codice scritto per OMNI in questo repository è del proprietario. Non contiene codice
copiato da Linux, KDE o Qt: li usava come librerie esterne, che **non** vengono portate nel
nuovo sistema.

## 1. Riutilizzabile così com'è (indipendente dal sistema)

| Elemento | Dove si trova oggi | Uso nel sistema autonomo |
|---|---|---|
| Linguaggio visivo OMNI: colori, accenti (Aurora, Iris, Corallo, Giada), spaziature, raggi, durate delle animazioni | `ui/qml/OmniDesign/Theme.qml` | diventa la tabella dei token di OMNI UI (K7) |
| Icone di interfaccia (tracciati SVG 24×24 originali) | `ui/qml/OmniDesign/Icons.qml` | rese dal toolkit OMNI UI; il formato dei tracciati è standard |
| Schemi di colori Scuro e Chiaro | `image/personale/files/usr/share/color-schemes/` (0.4) | valori riusati nei temi |
| Font Inter | pacchetto Fedora `rsms-inter-fonts` | si include il file originale (SIL OFL 1.1, consentito) |
| Progettazione delle app: sezioni, flussi, testi italiani, regole di conferma ("nessun esito prima della risposta del sistema", "eliminazione definitiva solo con conferma") | app 0.4: Impostazioni, Gestione attività, Esplora file, Store | specifica funzionale e di UX delle app OMNI native |
| Schermate e registrazioni della 0.3/0.4 | `docs/12-ui`, `docs/14-desktop-reale`, artifact | riferimento visivo |
| Metodo di prova: QEMU + QMP (clic, tasti, schermate), log seriale, esito OK/FALLITO, confronto prima/dopo | `tests/vm/qmp.py`, `tests/vm/screenshot.py`, `tests/vm/lib.sh`, `tests/vm/confronto.py` | riusati e adattati per K1+ (QEMU senza Linux nella VM) |
| Processo: ADR, PR in bozza, nessun merge senza autorizzazione, controlli di sicurezza | `docs/02-adr`, `docs/09-repository` | invariato |
| Specifiche funzionali e criteri di accettazione | `docs/00-specifiche`, `docs/08-accettazione` | da rivedere dove presuppongono Linux (vedi [`revisione-decisioni.md`](revisione-decisioni.md)) |

## 2. Riutilizzabile come algoritmo, riscrivendolo in Rust

| Elemento | Origine | Nota |
|---|---|---|
| Ordinamento naturale dei nomi file, ricerca nelle cartelle, rinomina automatica senza sovrascrittura | `ui/src/filemanager.cpp` | logica pura, facile da trasferire |
| Calcolo di CPU e memoria per processo, storico per i grafici | `ui/src/systemmonitor.cpp` | i dati arriveranno dal kernel OMNI, non da `/proc` |
| Parsing del catalogo e ordinamento per lo Store | `ui/src/appstream.cpp` | il formato del catalogo OMNI sarà proprio |
| Indice delle app e ricerca nel menu Start, gestione delle app fissate | `ui/qml/OmniDesktop/AppIndex.qml` | |
| Gestione delle notifiche (coda, non disturbare, cronologia) | `ui/src/notificationserver.cpp` | senza D-Bus: IPC OMNI |

## 3. Da riscrivere (legato a Linux/KDE/Qt a runtime)

| Elemento | Perché |
|---|---|
| Tutto il codice QML e C++/Qt delle app e della shell | richiede Qt (e Qt richiede una libc/POSIX e un backend grafico). Senza un porting di Qt, che è una scelta da valutare prima di K7, si riscrive in OMNI UI |
| Integrazione con KWin, layer-shell, TasksModel, plasma-nm, plasma-pa, bluez-qt, KGlobalAccel | componenti KDE |
| KIO, KArchive, Flatpak, AppStream di Flatpak, rpm-ostree, polkit, AccountsService, timedated, NetworkManager, PipeWire, firewalld, SELinux | servizi Linux/freedesktop: i servizi OMNI equivalenti sono nella roadmap |
| Unità systemd, script di sessione, recupero, modalità sicura Plasma | systemd e Plasma |
| Immagine bootc/Containerfile, base B3, build in container Fedora | catena di Fedora |

## 4. Aspetti legali

- Il codice OMNI esistente è del proprietario: lo si può riusare e rilicenziare. La licenza
  del nuovo codice è da decidere (ADR-0011).
- Qt (LGPLv3/GPL) e KDE Frameworks (LGPL) **non** vengono copiati. Se in futuro si
  portasse Qt, andrebbero rispettate le condizioni della LGPL: collegamento dinamico e
  sorgenti delle modifiche.
- Nessun codice da Linux (GPLv2) entra nel kernel OMNI. Le specifiche hardware si leggono
  dai documenti ufficiali (Intel, AMD, UEFI Forum, OASIS virtio, NVM Express, USB-IF), non
  dai sorgenti dei driver Linux. Questo evita problemi di opere derivate.
- Font Inter: la SIL OFL 1.1 ne consente l'inclusione e la ridistribuzione, ma non la
  vendita del font da solo.
- I marchi (Windows, NVIDIA, ecc.) si citano solo per descrivere la compatibilità hardware.
