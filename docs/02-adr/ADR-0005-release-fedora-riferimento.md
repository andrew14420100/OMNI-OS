# ADR-0005 — Release Fedora di riferimento: Fedora Kinoite 45

- **Stato:** Proposto — **verifica obbligatoria del supporto effettivo prima di M1**
- **Aggiornamento 2026-11-05:** rilascio ufficiale di Fedora Linux 45 (incluso Kinoite 45) **confermato** su fonti ufficiali Fedora (vedi §"Conferma ufficiale"). La conferma del rilascio **non** costituisce approvazione dell'architettura né della scelta della base (ADR-0002) o di Secure Boot (ADR-0004).
- **Data:** 2026-11-05
- **Decisioni approvate correlate:** 50
- **Riferimento:** richiesta 4 dell'autorizzazione M0

## Contesto

Il proprietario indica Fedora Kinoite 45 come possibile riferimento iniziale.

### Stato rilevato al 2026-11-05

| Elemento | Stato | Affidabilità della fonte |
|---|---|---|
| Decisione "GO" per Fedora 45 Final (RC 1.4) al meeting Go/No-Go del 29 ottobre 2026 | Riportata | Phoronix (secondaria, attendibile) |
| Data di rilascio: martedì 3 novembre 2026 (dopo due rinvii: 20 ottobre → 27 ottobre → 3 novembre) | Riportata | Phoronix, warp2search, linuxcompatible (secondarie) |
| Annuncio ufficiale Fedora (Fedora Magazine) | **Verificato**: "Announcing Fedora Linux 45", 3 novembre 2026 | Fedora Magazine (ufficiale) |
| Kinoite 45 disponibile per il download, data di rilascio 3 novembre 2026, ISO `Fedora-Kinoite-Installer-45-1.4.x86_64.iso` | **Verificato** | fedoraproject.org (ufficiale) |
| Contenuti (da Beta): kernel Linux 7.2, KDE Plasma 6.7 | Riportati per la Beta del 15 settembre 2026 | linuxiac, debugpoint (secondarie) |
| Atomic Desktops: ISO costruite con image-builder al posto di lorax; immagini raw e qcow2 disponibili; installer Anaconda web | Riportato per la Beta | linuxiac (secondaria) |
| Verifica delle firme RPM imposta per default (pacchetti non firmati rifiutati) | Riportato per la Beta | linuxiac (secondaria) |
| Fine supporto Fedora 43: 9 dicembre 2026 | Riportato | endoflife.ai (secondaria) |

### Ciclo di vita (regola Fedora)

Una release Fedora è supportata fino a circa quattro settimane dopo il rilascio
della release N+2 (circa 13 mesi). **Stima** per Fedora 45: fine supporto
intorno a fine 2027, dopo il rilascio di Fedora 47. Data da confermare sul
calendario ufficiale.

## Conferma ufficiale (2026-11-05)

| Fonte ufficiale | Contenuto rilevato |
|---|---|
| Fedora Magazine, "Announcing Fedora Linux 45" — https://fedoramagazine.org/announcing-fedora-linux-45/ | Pubblicato il 3 novembre 2026 (autori: Aoife Moloney, Jef Spaleta): "The Fedora Project is pleased to announce the release of Fedora Linux 45!"; le Atomic Desktops, inclusa Kinoite, sono disponibili |
| Fedora Project, pagina download Kinoite — https://fedoraproject.org/atomic-desktops/kinoite/download/ | "Download Fedora Kinoite 45", "RELEASE DATE: Tuesday, November 3, 2026", ISO `Fedora-Kinoite-Installer-45-1.4.x86_64.iso` (compose RC 1.4, coerente con la decisione GO) |
| Fedora Project, pagina Kinoite — https://fedoraproject.org/atomic-desktops/kinoite/ | "Each version is updated for approximately 13 months." |

**Anomalia da ricontrollare:** al momento della consultazione la pagina di
download mostrava ancora l'etichetta "BETA" accanto a Kinoite 45, pur indicando
la data di rilascio finale e il compose 1.4. Probabile residuo della pagina;
da ricontrollare prima di M1.

Kernel e versione di Plasma della release finale **non** sono indicati
nell'annuncio: i valori 7.2 e 6.7 restano quelli riportati per la Beta, da
confermare sull'immagine effettiva in M1.

## Implicazioni per OMNI

- **Kernel 7.2:** va verificato che il driver NVIDIA open fissato (ADR-0004) compili e funzioni con il kernel effettivamente distribuito.
- **Firme RPM obbligatorie:** eventuali RPM OMNI propri dovranno essere firmati (impatto sulla pipeline, ADR-0003).
- **Plasma 6.7:** le API per plasmoid/KWin script usate da M4 andranno fissate su questa versione.
- Una release appena uscita può avere regressioni iniziali: il primo mese dopo il rilascio è il periodo con più aggiornamenti correttivi.

## Proposta

Adottare **Fedora Kinoite 45** come riferimento iniziale (proposta, non ancora approvata), **condizionato** al
superamento di questa checklist prima dell'avvio di M1:

| # | Verifica | Esito |
|---|---|---|
| F45-01 | Annuncio ufficiale di rilascio su canali Fedora | **Superata** (2026-11-05, Fedora Magazine + fedoraproject.org) |
| F45-02 | Immagine OCI ufficiale Kinoite 45 disponibile sul registry Fedora (tag e digest) | Da verificare |
| F45-03 | Data di fine supporto sul calendario Fedora | Parziale: "circa 13 mesi" (fedoraproject.org); data esatta da verificare |
| F45-04 | Pacchetti NVIDIA RPM Fusion disponibili per F45 e per il kernel corrente | Da verificare |
| F45-05 | Problemi noti (Common Issues) di Kinoite 45 rilevanti per NVIDIA, KDE, Wayland, bootc | Da verificare |
| F45-06a | **Solo per l'opzione B** di ADR-0002 (Universal Blue come base) o per l'uso di Universal Blue come banco di prova in M3: disponibilità di immagini Universal Blue per Fedora 45 con kmod `nvidia-open` per il kernel F45, firmate, con tag e digest | Da verificare solo se si sceglie B o il banco di prova |
| F45-06b | **Per l'opzione C** (riuso di codice e tecniche): **nessuna** dipendenza dalla disponibilità di immagini o kmod Universal Blue, perché l'immagine parte da Kinoite ufficiale e i kmod sono compilati dalla CI OMNI (dipende invece da F45-04). Da verificare solo che il codice riusato (es. script di `ublue-os/akmods`) funzioni con F45 e che siano rispettati gli obblighi Apache-2.0 (avvisi di copyright, NOTICE, indicazione delle modifiche) | Da verificare solo se si sceglie C |
| — | Per l'opzione A nessuna delle due verifiche è necessaria | — |

**Alternativa di riserva:** Fedora Kinoite 44 (supportata fino a circa quattro
settimane dopo il rilascio di Fedora 46), se F45 presentasse problemi bloccanti
con NVIDIA. Con questa scelta si dovrebbe pianificare il passaggio a F45/F46
entro pochi mesi.

## Decisione del proprietario

_In attesa._
