# Criteri di accettazione per milestone

- **Stato:** proposta M0. Ogni criterio deve essere dimostrato da un test registrato nel rapporto di milestone (Regola 5: niente dichiarazioni senza verifica).
- I criteri di uscita della spec §5 sono riportati **invariati**; le voci "AC" li dettagliano.

## M0 — Preparazione tecnica e documentazione

**Criterio spec:** ogni componente prioritario ha responsabilità, dipendenze, modalità di test e condizioni di completamento documentate.

| ID | Criterio | Evidenza |
|---|---|---|
| AC-M0-01 | Le 55 decisioni sono riportate integralmente e tracciate | `00-specifiche/`, `01-architettura/tracciabilita-decisioni.md` (55 righe) |
| AC-M0-02 | Architettura a livelli con confini di privilegio | `01-architettura/architettura.md` |
| AC-M0-03 | Componenti prioritari con le quattro voci richieste | `architettura.md` §8 |
| AC-M0-04 | Requisiti di sicurezza, incluso SEC-INST-01 | `03-sicurezza/` |
| AC-M0-05 | Catalogo dipendenze e analisi licenze, incluso REQ-TM-01 | `04-dipendenze/`, `05-licenze/` |
| AC-M0-06 | Registro dei rischi | `06-rischi/` |
| AC-M0-07 | Confronto Kinoite/Universal Blue, strategia immagini, NVIDIA/Secure Boot, release F45 | ADR-0002…0005 |
| AC-M0-08 | Piano benchmark gaming + AI | `07-verifiche/piano-benchmark-gaming-ai.md` |
| AC-M0-09 | Struttura e inizializzazione del repository | `09-repository/` |
| AC-M0-10 | Rapporto M0 con decisioni aperte | `10-rapporti/rapporto-M0.md` |
| AC-M0-11 | **Approvazione del proprietario** della documentazione M0 | Revisione PR |

## M1 — Base Linux avviabile in VM

**Criterio spec:** una base avviabile in VM, con aggiornamento e rollback dimostrati.

| ID | Criterio |
|---|---|
| AC-M1-01 | L'immagine OMNI si costruisce dalla CI partendo da un commit, con base fissata per digest |
| AC-M1-02 | Avvio UEFI in VM (OVMF) con Secure Boot emulato attivo |
| AC-M1-03 | Login SDDM, desktop Plasma Wayland, rete funzionanti in VM |
| AC-M1-04 | Upgrade da immagine N a N+1 completato |
| AC-M1-05 | Rollback R1, R2, R3 (ADR-0003) dimostrati |
| AC-M1-06 | Il client rifiuta un'immagine non firmata o con firma errata |
| AC-M1-07 | Ricostruzione dallo stesso commit con contenuto equivalente (elenco pacchetti identico) |
| AC-M1-08 | SBOM generato |
| AC-M1-09 | Confronto rpm-ostree vs bootc documentato |
| AC-M1-10 | Dichiarazione esplicita: NVIDIA **non** verificato in VM |

## M2 — Installer sicuro e recupero preliminare

**Criterio spec:** test distruttivi superati esclusivamente su supporti di prova, senza modifiche a dischi non autorizzati.

| ID | Criterio |
|---|---|
| AC-M2-01 | In VM con due dischi (uno "esca" con NTFS, ESP Microsoft simulata e intestazione BitLocker simulata) l'installer rifiuta l'esca (SEC-INST-03) |
| AC-M2-02 | Il disco esca ha checksum identico prima e dopo ogni test |
| AC-M2-03 | Conferma digitata dell'identificativo del disco (SEC-INST-04) |
| AC-M2-04 | Supporto USB di recupero avvia, sblocca LUKS, ripristina un deployment |
| AC-M2-05 | Procedura di prima installazione (`03-sicurezza/procedura-prima-installazione.md`) rivista e approvata |

## M3 — Compatibilità con il computer reale

**Criterio spec:** sistema stabile sul solo SSD OMNI, con avvio indipendente e Windows preservato.

| ID | Criterio |
|---|---|
| AC-M3-01 | Prima installazione eseguita con SSD Windows scollegato **o** con procedura alternativa approvata per iscritto (SEC-INST-01) |
| AC-M3-02 | Avvio dall'SSD OMNI con Secure Boot secondo l'opzione approvata (ADR-0004) |
| AC-M3-03 | Driver NVIDIA open caricato (`modinfo` → Dual MIT/GPL), `nvidia-smi` funzionante |
| AC-M3-04 | 4K al refresh nativo supportato; altre modalità documentate |
| AC-M3-05 | Wi-Fi, Ethernet, Bluetooth, audio, microfoni, USB essenziali funzionanti (elenco da H-11..H-14) |
| AC-M3-06 | Sospensione/ripresa e riavvio ripetuti (almeno 10 cicli) senza errori |
| AC-M3-07 | Prova di stabilità prolungata (durata da definire) senza errori Xid |
| AC-M3-08 | Recupero da mancato avvio dimostrato |
| AC-M3-09 | Windows avvia normalmente dopo il ricollegamento, senza richiesta BitLocker, con tabella partizioni invariata |
| AC-M3-10 | HDR/VRR: stato documentato, **non** dichiarato supportato senza test |

## M4 — Desktop OMNI

**Criterio spec:** utilizzo quotidiano delle funzioni desktop fondamentali senza componenti AI obbligatori.

AC-M4-01 branding; AC-M4-02 tema chiaro/scuro; AC-M4-03 dock; AC-M4-04 launcher; AC-M4-05 widget; AC-M4-06 impostazioni; AC-M4-07 notifiche; AC-M4-08 gestione finestre; AC-M4-09 personalizzazione; AC-M4-10 tutto funzionante con motore AI **disinstallato**; AC-M4-11 accessibilità di base (lettore schermo, zoom, contrasto) funzionante senza AI (RF-10); AC-M4-12 test a 4K e scale 100–200%.

## M5 — Servizi e applicazioni fondamentali

**Criterio spec:** applicazioni di base, installazioni, aggiornamenti, rete, gestione file e recupero verificati.

Un criterio per ogni elemento della lista M5 della spec, con test d'integrazione e prova di recupero (backup → ripristino).

## M6 — AI locale

**Criterio spec:** l'assistente risponde offline e usa strumenti limitati senza poter compiere modifiche non autorizzate.

AC-M6-01 risposta con rete scollegata; AC-M6-02 casi TS-AI-01…07 superati; AC-M6-03 benchmark B-00…B-C8 eseguiti e soglie approvate; AC-M6-04 memoria ispezionabile ed eliminabile; AC-M6-05 disattivazione completa dell'AI senza effetti sul desktop.

## M7 — Agenti e automazioni

**Criterio spec:** più compiti coordinati correttamente, rispettando i permessi e senza compromettere i dati.

AC-M7-01 esecuzione concorrente con dipendenze; AC-M7-02 limiti di risorse rispettati; AC-M7-03 arresto globale; AC-M7-04 recupero dopo errore; AC-M7-05 registro di audit completo e verificabile.

## M8 — Funzionalità avanzate

**Criterio spec:** ogni modulo dispone di test, documentazione, gestione degli errori e integrazione con la sicurezza del sistema.

Per ogni modulo: test, documentazione, gestione errori, revisione di sicurezza; per il gaming, matrice di compatibilità per singolo titolo (RF-09).

## M9 — Consolidamento e distribuzione

**Criterio spec:** rilascio approvato sulla base di test reali, con limitazioni note e documentate.

AC-M9-01 regressione completa su hardware reale; AC-M9-02 build riproducibili; AC-M9-03 analisi licenze completata; AC-M9-04 **REQ-TM-01 (marchio) completato prima di ogni distribuzione pubblica**; AC-M9-05 documentazione di installazione, manutenzione e ripristino; AC-M9-06 limitazioni note pubblicate.

## Requisiti funzionali RF → criteri

| RF | Criteri principali |
|---|---|
| RF-01 | AC-M3-02, AC-M3-09 |
| RF-02 | AC-M2-01..03, AC-M3-01 |
| RF-03 | AC-M4-10, AC-M6-05 |
| RF-04 | AC-M1-04..05, AC-M2-04 |
| RF-05 | AC-M6-02, TS-AI-04 |
| RF-06 | AC-M7-01..03 |
| RF-07 | SEC-EXT, AC-M8 |
| RF-08 | AC-M6-01 |
| RF-09 | AC-M8 matrice compatibilità |
| RF-10 | AC-M4-11 |
