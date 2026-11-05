# ADR-0005 — Release Fedora di riferimento: Fedora Kinoite 45

- **Stato:** Proposto — **verifica obbligatoria del supporto effettivo prima di M1**
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
| Annuncio ufficiale Fedora (Fedora Magazine / lista announce) | **Non verificato**: siti Fedora non raggiungibili dall'ambiente di analisi (protezione anti-bot) | — |
| Contenuti (da Beta): kernel Linux 7.2, KDE Plasma 6.7 | Riportati per la Beta del 15 settembre 2026 | linuxiac, debugpoint (secondarie) |
| Atomic Desktops: ISO costruite con image-builder al posto di lorax; immagini raw e qcow2 disponibili; installer Anaconda web | Riportato per la Beta | linuxiac (secondaria) |
| Verifica delle firme RPM imposta per default (pacchetti non firmati rifiutati) | Riportato per la Beta | linuxiac (secondaria) |
| Fine supporto Fedora 43: 9 dicembre 2026 | Riportato | endoflife.ai (secondaria) |

### Ciclo di vita (regola Fedora)

Una release Fedora è supportata fino a circa quattro settimane dopo il rilascio
della release N+2 (circa 13 mesi). **Stima** per Fedora 45: fine supporto
intorno a fine 2027, dopo il rilascio di Fedora 47. Data da confermare sul
calendario ufficiale.

## Implicazioni per OMNI

- **Kernel 7.2:** va verificato che il driver NVIDIA open fissato (ADR-0004) compili e funzioni con il kernel effettivamente distribuito.
- **Firme RPM obbligatorie:** eventuali RPM OMNI propri dovranno essere firmati (impatto sulla pipeline, ADR-0003).
- **Plasma 6.7:** le API per plasmoid/KWin script usate da M4 andranno fissate su questa versione.
- Una release appena uscita può avere regressioni iniziali: il primo mese dopo il rilascio è il periodo con più aggiornamenti correttivi.

## Proposta

Adottare **Fedora Kinoite 45** come riferimento iniziale, **condizionato** al
superamento di questa checklist prima dell'avvio di M1:

| # | Verifica | Esito |
|---|---|---|
| F45-01 | Annuncio ufficiale di rilascio su canali Fedora | Da verificare |
| F45-02 | Immagine OCI ufficiale Kinoite 45 disponibile sul registry Fedora (tag e digest) | Da verificare |
| F45-03 | Data di fine supporto sul calendario Fedora | Da verificare |
| F45-04 | Pacchetti NVIDIA RPM Fusion disponibili per F45 e per il kernel corrente | Da verificare |
| F45-05 | Problemi noti (Common Issues) di Kinoite 45 rilevanti per NVIDIA, KDE, Wayland, bootc | Da verificare |
| F45-06 | Se si sceglie Universal Blue (ADR-0002 B/C): immagini/kmod F45 disponibili | Da verificare |

**Alternativa di riserva:** Fedora Kinoite 44 (supportata fino a circa quattro
settimane dopo il rilascio di Fedora 46), se F45 presentasse problemi bloccanti
con NVIDIA. Con questa scelta si dovrebbe pianificare il passaggio a F45/F46
entro pochi mesi.

## Decisione del proprietario

_In attesa._
