# 15 — Evoluzione 0.4.0 (sperimentale, solo macchina virtuale)

Questa fase parte dalla **0.3.0 verificata** (commit 558927f, run 42736225432) senza
ricominciare da capo. La 0.3.0 resta intatta: branch `claude/omni-desktop-reale`, PR #6 e
pacchetto VM.

La 0.4.0 aggiunge:
- interventi sulle prestazioni, decisi a partire da misure reali;
- le app di sistema OMNI;
- l'integrazione delle app nella shell, la personalizzazione dal vivo e il multitasking
  tramite KWin.

> Vincoli rispettati:
> - niente ISO, installer, USB o dual boot; nessuna modifica a Windows o all'hardware;
> - nessuna funzione IA e nessun servizio IA in background;
> - nessun costo obbligatorio;
> - nessuna installazione automatica di software;
> - nessun privilegio amministrativo concesso automaticamente;
> - nessun aggiornamento automatico;
> - nessun merge e nessuna release.

## 1. Metodo

1. **Diagnosi prima degli interventi**: `tests/vm/diagnosi_avvio.sh` (VM 4K, scala 200%,
   grafica software). Per ogni app separa:
   - primo avvio dopo l'accesso;
   - riapertura;
   - avvio senza `gio`;
   - avvio dalla shell OMNI;
   - avvio a freddo, con le cache svuotate;
   - avvio a freddo con lettura anticipata dei file;
   - per Impostazioni, anche Qt Quick con renderer software.

   Per ciascun caso misura il tempo alla finestra, il tempo all'**utilizzabilità** (CPU
   dell'app a riposo dopo la comparsa della finestra) e i MB letti dal disco.
2. **Interventi solo sulle cause misurate**. Nessuna animazione usata per mascherare
   l'attesa.
3. **Confronto prima/dopo con la stessa procedura**: `tests/vm/prestazioni.sh`, sulla 0.3.0
   (commit fissato) e sulla 0.4.0, nella stessa esecuzione e sullo stesso runner.

## 2. Diagnosi (run 42771351471, immagine 0.3.0)

| App | Riapertura: finestra / utilizzabile | Senza gio | A freddo | Primo dopo l'accesso |
|---|---|---|---|---|
| Konsole | 0,41 / 0,59 s | 0,48 / 0,73 s | 0,87 / 1,12 s (58 MB) | 0,42 / 0,64 s |
| Dolphin | 0,48 / 1,43 s | 0,45 / 1,55 s | 1,07 / 1,69 s (58 MB) | 1,21 / 2,02 s |
| Firefox | 1,30 / 9,0 s¹ | 1,02 / 5,8 s¹ | 1,54 / 7,2 s (580 MB) | 2,76 / 12,2 s¹ (752 MB) |
| Impostazioni (KDE) | 0,98 / 2,24 s | 1,02 / 2,32 s | 1,51 / 2,66 s (326 MB) | 1,97 / 3,17 s |
| Impostazioni, Qt Quick software | **0,80 / 1,01 s** | | | |

¹ In questa run la misura dell'utilizzabilità contava anche lo script di misura (la sua riga
di comando contiene il nome dell'app). L'errore è corretto: questi valori vanno letti come
limite superiore.

**Cause trovate:**
- **Rendering di Qt Quick su llvmpipe.** Con OpenGL software in 4K, le app Qt Quick spendono
  più di un secondo a disegnare. Con il renderer software di Qt Quick lo stesso pannello
  Impostazioni è utilizzabile in 1,0 s invece di 2,2 s.
- **Processi di Plasma inutili nella sessione OMNI:**
  - Centro di benvenuto di Plasma: circa 1 GB di RSS, attivo durante le prime aperture;
  - tastiera su schermo: circa 0,5 GB.
  Entrambi rallentano soprattutto il primo avvio dopo l'accesso.
- **Firefox al primo avvio**: crea il profilo, legge 752 MB e apre la pagina di benvenuto
  remota.
- **Non sono cause:**
  - `gio`: la differenza rispetto all'avvio diretto è dentro il rumore;
  - la lettura anticipata dei file: a freddo guadagna soltanto 0,2–0,3 s.

## 3. Interventi

| Causa | Intervento | Dove |
|---|---|---|
| Qt Quick su llvmpipe | Se la shell rileva grafica software, le app avviate dalla shell usano il renderer software di Qt Quick. KWin e la shell non cambiano. Con accelerazione 3D non cambia nulla. Si può disattivare in *Impostazioni → Personalizzazione*. | `ui/src/main.cpp`, `ShellSettings::softwareQuickApps` |
| Centro di benvenuto di Plasma | `ExecCondition` solo nella sessione OMNI. La modalità sicura resta invariata. | `app-org.kde.plasma-welcome@.service.d/10-omni.conf` |
| Primo avvio di Firefox | Criteri di sistema: nessuna pagina iniziale remota, nessun controllo del browser predefinito. Telemetria, studi e funzioni IA disattivati per impostazione predefinita. Non sono bloccati: l'utente può cambiarli. | `/etc/firefox/policies/policies.json` |
| Errore di misura | Lo script esclude sé stesso. `/proc/<pid>/stat` viene letto correttamente anche per i nomi con spazi. | `tests/vm/misura_app.sh` |

I risultati prima/dopo sono in `confronto-prestazioni.md`, nel pacchetto e nelle evidenze
della run finale.

## 4. App OMNI

Le quattro app usano lo stesso eseguibile della shell (`omni-shell --app <nome>`). L'app_id
Wayland corrisponde al file `.desktop`. Le finestre sono di KWin, con bordi e
affiancamento uguali a quelli di tutte le altre app.

| App | Funzioni reali | Limiti dichiarati |
|---|---|---|
| **Impostazioni** (16 sezioni) | Schermo (KScreen), audio (PipeWire), notifiche, energia (PowerDevil), archiviazione, rete (NetworkManager), Bluetooth (BlueZ), mouse/tastiera/touchpad (KWin), personalizzazione, app predefinite e avvio, account (AccountsService), data/ora/lingua (timedated), privacy e sicurezza (firewalld, SELinux, permessi Flatpak), aggiornamenti (rpm-ostree con ripristino), backup e ripristino, informazioni | Le operazioni privilegiate chiedono l'autorizzazione con polkit. Ogni modifica è confermata solo dopo la risposta del sistema. |
| **Gestione attività** | Processi da `/proc` (CPU, memoria, utente), grafici di CPU per core, memoria, disco e rete; app aperte (KWin); app all'avvio | Termina solo i processi dell'utente, dopo una conferma. GPU: soltanto i dati pubblicati dal driver. Nella VM la GPU è virtuale. |
| **Esplora file** | KIO (come Dolphin): schede, cronologia, indirizzo, ricerca, anteprima, Dettagli/Icone, copia/sposta con rinomina automatica, cestino con ripristino, eliminazione definitiva con conferma, rinomina, nuova cartella, proprietà e permessi, ZIP (KArchive), appunti condivisi, trascinamento, avanzamento e annullamento | Solo file locali e unità montate. |
| **OMNI Store** | Catalogo AppStream reale delle sorgenti Flatpak, installazione, rimozione e aggiornamento con `flatpak`, avanzamento e annullamento, permessi mostrati prima dell'installazione | Senza catalogo scaricato lo Store è vuoto e lo spiega: nessun dato inventato. Flathub si aggiunge solo su richiesta, per il solo utente. |

## 5. Shell e coerenza

- **Personalizzazione dal vivo**: tema, accento, movimento ridotto, altezza della barra e
  sfondo cambiano senza un nuovo accesso. Il file è condiviso con Impostazioni e controllato
  con `QFileSystemWatcher`.
- **Schemi di colori** OMNI Scuro e OMNI Chiaro per le app Qt/KDE. Lo scuro è predefinito,
  come la shell.
- **Collegamenti alle app OMNI**:
  - il pannello rapido apre la pagina corrispondente di OMNI Settings;
  - "OMNI Store" sostituisce Discover nel pannello;
  - le cartelle si aprono in Esplora file.
- **Start senza doppioni**: le app KDE sostituite restano installate e si trovano con la
  ricerca.
- **Multitasking con KWin**, dal menu della barra: affianca a sinistra o a destra,
  ingrandisci, sposta sul desktop successivo. Panoramica e desktop virtuali come nella 0.3.0.

## 6. Prove

- **Prove locali** (`ctest`, 11 test, anche nel container Fedora 45 con KIO e KArchive):
  - operazioni reali sui file in una cartella temporanea, con cestino di prova;
  - catalogo AppStream nel formato di Flathub;
  - caricamento di tutte le pagine delle app;
  - Gestione attività con dati reali da `/proc`;
  - personalizzazione applicata dal vivo alla barra;
  - nessun riferimento all'IA nell'interfaccia.
- **Prove in VM** (`tests/vm/omni_desktop_test.sh`): oltre alle prove della 0.3.0, le
  quattro app aperte da Start, dal pannello rapido e via D-Bus; Esplora file come
  applicazione predefinita per le cartelle; catalogo Flatpak reale; nessun errore QML nel
  registro.
- **Sicurezza** (`tests/vm/personale_sicurezza.sh`): oltre ai controlli della 0.3.0,
  nessuna regola polkit OMNI, nessun avvio privilegiato, funzioni IA di Firefox disattivate.

L'esito della run finale è in `prove-reali.md` e `controlli-di-sicurezza.md`, nel pacchetto.
