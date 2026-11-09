# 14 — Desktop OMNI reale (anteprima 0.3.0, sperimentale)

Obiettivo: OMNI OS usabile ogni giorno in una macchina virtuale, con queste caratteristiche:
- **una sola interfaccia**: un solo Start, una sola barra e nessun pannello duplicato;
- **funzioni reali** collegate ai servizi di Fedora e KDE;
- prestazioni **misurate**, prima e dopo.

Nessuna funzione di intelligenza artificiale in questa fase.

Non è una milestone formale (non M2, M3 o M4) e non è una release. Le 55 decisioni approvate
non cambiano: la base resta Fedora Kinoite atomica con KDE Plasma e KWin su Wayland, e OMNI
Shell resta scritta in Qt/QML.

## 1. Problemi riportati dall'utente sulla 0.2.0 (VirtualBox, 4K a scala 200%)

| # | Problema | Causa | Correzione |
|---|---|---|---|
| 1 | Launcher di OMNI e menu di Plasma visibili insieme; barre e dock di due interfacce | OMNI Shell 0.2 era una finestra a schermo intero avviata *dentro* la sessione Plasma | Sessione "OMNI OS": il pannello di Plasma non parte; OMNI Shell disegna sfondo, barra e pannelli come superfici del desktop (layer-shell) |
| 2 | Sistema lento (avvio, accesso, app, menu, passaggio del mouse) | vedi §4: misure e cause | §4 |
| 3 | Funzioni simulate (rete, audio, Bluetooth, notifiche, schermo, energia) | il prototipo non era collegato ai servizi | collegate ai servizi reali (§3) |
| 4 | Spegnimento non riuscito | nella 0.2 i pulsanti energia di OMNI erano simulati | `org.kde.Shutdown` (ksmserver: chiude le app, che possono salvare) con ripiego su systemd-logind; provato in VM (§5) |

## 2. Architettura

```
plasmalogin ── sessione "OMNI OS" (/usr/share/wayland-sessions/plasma.desktop, la voce predefinita del gestore di accesso)
                 └─ /usr/libexec/omni-os/omni-session → startplasma-wayland
                      ├─ KWin (finestre, effetti, Alt+Tab, desktop virtuali)       [Plasma]
                      ├─ ksmserver, kded, powerdevil, polkit, portali, kglobalaccel  [Plasma]
                      ├─ plasma-plasmashell.service  → SALTATO (ExecCondition)
                      └─ omni-shell.service → OMNI Shell --session
                           sfondo (layer background) · barra (layer top, zona esclusiva 48 px)
                           pannelli Start/rapide/notifiche (layer top) · fumetti (layer overlay)
            ── "OMNI OS – modalità sicura (desktop Plasma)" → Plasma originale, senza OMNI Shell
```

- **Scelta della sessione**: `omni-session` scrive un marcatore con l'id della sessione di
  login. Le condizioni delle due unità (`omni-session-check omni|plasma`) lo confrontano
  con `XDG_SESSION_ID`. Il marcatore viene rimosso all'uscita, quindi una sessione Plasma
  successiva non eredita mai la scelta.
- **Recupero**: `Restart=on-failure`. Dopo 4 arresti in 120 s, `OnFailure` avvia
  `omni-recupero`, che fa partire il desktop Plasma nella stessa sessione: l'utente non
  resta mai senza interfaccia.
- **Tasto Meta**: KWin chiama `org.kde.plasmashell /PlasmaShell activateLauncherMenu`. Nella
  sessione OMNI quel nome è di OMNI Shell (Plasma non è in esecuzione), quindi il tasto apre
  Start. Il nome non viene mai sottratto a Plasma.
- **Avvio delle app**: `gio launch` del file `.desktop`, con ripiego `kstart`. Solo voci
  lette dal sistema, mai comandi arbitrari.

## 3. Funzioni

| Funzione | Servizio reale | Stato in VirtualBox/QEMU |
|---|---|---|
| Barra: app fissate e finestre aperte, attiva/riduci, nuova finestra, chiudi, gruppi | TasksModel di plasma-workspace (protocollo KWin) | reale |
| Desktop virtuali, Visualizzazione attività, Mostra desktop | KWin: VirtualDesktopManager, scorciatoie Overview / Show Desktop | reale |
| Spostare, ridimensionare, massimizzare, Alt+Tab | KWin (bordi e scorciatoie) | reale |
| Start: ricerca, app aggiunte, tutte le app, ricerca di sistema | file .desktop, KRunner | reale |
| Notifiche, cronologia, eliminazione, Non disturbare | server `org.freedesktop.Notifications` di OMNI Shell | reale; le urgenti passano anche con Non disturbare |
| Rete: stato, connessioni, connetti/disconnetti, Wi-Fi, password | NetworkManager, plasma-nm, agente dei segreti di KDE | Ethernet virtuale reale; Wi-Fi assente nella VM (dichiarato) |
| Audio: volume, muto, uscita, microfono, app | PipeWire tramite plasma-pa | reale con scheda audio virtuale |
| Bluetooth: stato, accensione, ricerca, associazione | BlueZ (bluez-qt) | nessun adattatore nella VM: "non disponibile" |
| Schermo: risoluzione, frequenza, scala | KScreen (`kscreen-doctor`), con verifica dello stato effettivo | reale; frequenze solo quelle offerte dal monitor virtuale |
| Luminosità | PowerDevil `org.kde.ScreenBrightness` | non regolabile su monitor virtuale (dichiarato) |
| Profilo energetico | power-profiles-daemon / tuned-ppd | reale se il servizio è presente |
| Batteria | UPower | mostrata solo se presente |
| Spegni, riavvia, disconnetti | `org.kde.Shutdown` (ksmserver), ripiego logind con polkit | reale (provato) |
| Sospendi | logind `Suspend` se `CanSuspend` lo consente | dipende dall'hypervisor; il motivo viene mostrato |
| Blocca | `org.freedesktop.ScreenSaver.Lock` (kscreenlocker) | reale |
| Archiviazione | spazio della cartella personale | reale |
| Sicurezza | SELinux, Secure Boot, firewalld (sola lettura) | reale |
| Gestione applicazioni | Discover | reale |
| Movimento ridotto | OMNI Shell + KDE `AnimationDurationFactor` (anche KWin e app KDE) | reale |
| Tema chiaro/scuro, accento | OMNI Shell | reale (solo OMNI Shell) |
| Intelligenza artificiale | — | **assente** (nessun modello, servizio o collegamento) |

## 4. Prestazioni

Procedura identica per 0.2.0 e 0.3.0 (`tests/vm/prestazioni.sh`), nella stessa esecuzione
e sullo stesso runner (`tests/vm/confronto.py`):
- avvio del sistema (`systemd-analyze`);
- accesso, dal tasto Invio alla shell pronta;
- apertura a freddo (cache del disco svuotate) e riapertura di Konsole, Dolphin, Firefox e
  Impostazioni, misurate con l'ora di KWin all'apertura della finestra;
- CPU di shell, KWin e Plasma a riposo e passando il mouse sulla barra;
- memoria;
- spegnimento.

Condizioni delle misure: QEMU/KVM con 4 CPU, 8 GB e grafica **software** (llvmpipe) in
3840×2160 a scala 200%. È il caso peggiore: in VirtualBox con accelerazione 3D la grafica
passa dalla GPU dell'host.

Interventi:
- **Una sola shell grafica** invece di due (Plasma + OMNI): meno processi, meno memoria,
  meno superfici da comporre.
- **Icone senza buffer multicampione per icona**: Shape.CurveRenderer, con tassellazione
  asincrona.
- **Nessuna animazione continua**: sfondo statico, orologio aggiornato al cambio di minuto.
- **Primo fotogramma prima di tutto**: Start, pannelli, rete, audio e Bluetooth vengono
  creati e collegati dopo il primo fotogramma della barra; le letture D-Bus sono asincrone.
- **Rendering software rilevato**: sfocatura e contrasto di KWin vengono disattivati per la
  sessione.

I risultati misurati sono nel rapporto della PR e in `confronto-prestazioni.md` del pacchetto.

## 5. Prove reali (tests/vm/omni_desktop_test.sh)

Clic e tasti veri (QMP) nella VM 4K a scala 200%:
- sessione predefinita, nessun pannello di Plasma, notifiche e tasto Meta gestiti da OMNI;
- servizi KDE collegati;
- Start con un clic e con il tasto Meta, Esc;
- avvio reale dalla barra e dalla ricerca, con tempo dal clic alla finestra;
- riduzione e ripristino dalla barra;
- desktop virtuali (la barra mostra solo le finestre del desktop corrente);
- notifiche e Non disturbare;
- volume reale (PipeWire), rete reale, Bluetooth assente dichiarato, scala 200%;
- arresto anomalo → riavvio della shell; arresti ripetuti → Plasma di riserva;
- Disconnetti, modalità sicura;
- Arresta con app aperte → nuovo avvio; Riavvia.

## 6. Prove da fare su hardware fisico (non possibili in VirtualBox/QEMU)

| Area | Prova |
|---|---|
| Wi-Fi | reti reali, WPA2/WPA3, password errata, rete nascosta, portale captive |
| Bluetooth | accensione, ricerca, associazione e connessione di cuffie (uscita audio) e mouse |
| Luminosità | regolazione del pannello di un portatile; monitor esterni DDC/CI |
| Energia | batteria, profili energetici, sospensione e ripresa (s2idle/S3), coperchio |
| Schermi | più monitor, 4K OLED a 240 Hz (frequenze reali da KScreen), HDR, VRR |
| Grafica | GPU NVIDIA RTX 5070 Ti con driver adeguato: fluidità di KWin e OMNI Shell, accelerazione video |
| Audio | più uscite (HDMI, USB, Bluetooth), microfono, flussi per app |

Queste prove riguardano l'installazione su hardware, che resta fuori da questa fase
(nessuna installazione fisica senza autorizzazione).
