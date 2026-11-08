# Checklist dei prerequisiti prima di M1 (spec §11)

- **Stato:** da compilare. Queste verifiche **non autorizzano** modifiche al computer o al repository.
- Le rilevazioni sul PC devono essere **in sola lettura** ed eseguite dal proprietario. Claude non ha accesso al computer.
- **Il repository è pubblico:** i valori sensibili (numeri di serie, chiavi BitLocker **e relativi ID**, identificativi univoci) vanno conservati **solo in locale** dal proprietario. In questo file si riportano al massimo modello e capacità, oppure "rilevato" / "sì/no".

## 1. Rilevazioni sul PC (dal proprietario, in sola lettura)

| # | Dato | Come rilevarlo (Windows, sola lettura) | Valore |
|---|---|---|---|
| H-01 | Modello, seriale e capacità dell'SSD destinato a OMNI | PowerShell: `Get-PhysicalDisk \| Format-List FriendlyName,SerialNumber,Size,MediaType,BusType` | |
| H-02 | Modello, seriale e capacità dell'SSD Windows | Come sopra | |
| H-03 | Schema delle partizioni dei dischi presenti | Gestione disco (`diskmgmt.msc`), solo osservazione | |
| H-04 | Slot M.2 in cui è montato ciascun SSD | Manuale della scheda madre + osservazione fisica | |
| H-05 | Possibilità di scollegare l'SSD Windows in sicurezza (SEC-INST-01) | Valutazione fisica (dissipatori, GPU sopra lo slot) | |
| H-06 | Stato Secure Boot | `msinfo32` → "Stato avvio protetto" | |
| H-07 | Modalità BIOS (UEFI) | `msinfo32` → "Modalità BIOS" | |
| H-08 | Versione BIOS/UEFI della scheda madre | `msinfo32` → "Versione/data BIOS" | |
| H-09 | Stato BitLocker e disponibilità chiave di recupero: qui solo "sì/no", mai chiave né ID | `manage-bde -status` (prompt amministratore, sola lettura; non mostra la password); per l'ID vedere la procedura `../03-sicurezza/procedura-prima-installazione.md` parte F, solo in locale | |
| H-10 | Situazione dei backup Windows (data ultimo backup, supporto) | — | |
| H-11 | Scheda Wi-Fi/Bluetooth (modello) | Gestione dispositivi | |
| H-12 | Controller audio, microfoni, webcam | Gestione dispositivi | |
| H-13 | Collegamento monitor (DisplayPort/HDMI, versione cavo) | Osservazione | |
| H-14 | Periferiche USB essenziali (tastiera, mouse, cuffie, controller) | — | |
| H-15 | ID dispositivo della GPU (`PCI\VEN_10DE&DEV_....`) | Gestione dispositivi → Dettagli → ID hardware | |

## 2. Verifiche documentali (Claude, prima di M1)

| # | Verifica | Riferimento | Esito |
|---|---|---|---|
| D-01 | Release Fedora scelta e supporto effettivo (F45-01..05, F45-06a/06b secondo la base) | ADR-0005 | Parziale: rilascio ufficiale F45 verificato (F45-01); F45-02..06 da verificare |
| D-02 | Compatibilità preliminare NVIDIA: device ID nell'elenco README della versione driver; pacchetti RPM Fusion per F45 | ADR-0004 NV-02/NV-03 | Da verificare |
| D-03 | Tecnica di costruzione e distribuzione dell'immagine | ADR-0003 | Proposta, attende approvazione |
| D-04 | Strategia aggiornamenti, firma e ripristino | ADR-0003 | Proposta, attende approvazione |
| D-05 | Licenze dei componenti distribuiti | `../05-licenze/analisi-licenze.md` | Preliminare |
| D-06 | Base: Kinoite ufficiale vs Universal Blue | ADR-0002 | Attende decisione |
| D-07 | Opzione Secure Boot | ADR-0004 | Attende decisione |
| D-08 | Repository Git inizializzato con branch di base (PR #1 unita il 2026-11-05, `main` = `4198f0b`) | `../09-repository/inizializzazione-repository.md` | **Completato** (opzione 1, 2026-11-05): `main` = commit vuoto `25f607b`, PR #1 in bozza |

## 3. Requisiti di compatibilità applicativa (dal proprietario)

| # | Gioco / programma prioritario | Piattaforma | Anti-cheat / DRM | Requisito (deve funzionare / opzionale) |
|---|---|---|---|---|
| A-01 | | | | |
| A-02 | | | | |
| A-03 | | | | |

Questi elenchi alimentano la matrice di compatibilità (RF-09) e il piano di
benchmark.
