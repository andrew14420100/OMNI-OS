# Rapporto di milestone — M0 Preparazione tecnica e documentazione

- **Data:** 2026-11-05
- **Autorizzazione:** M0 autorizzata dal proprietario il 2026-11-05, esclusivamente per documentazione tecnica.
- **Stato M0:** documentazione completata, **in attesa di revisione e approvazione** (AC-M0-11).
- **M1:** **non avviata**; richiede approvazione esplicita.

## 1. Cosa è stato fatto (solo documentazione)

| Area | Documento |
|---|---|
| Specifiche v1.0 (55 decisioni integrali) | `00-specifiche/specifiche-funzionali-v1.0.md` |
| Architettura e tracciabilità 55 decisioni | `01-architettura/` |
| ADR 0001–0006 | `02-adr/` |
| Sicurezza (incl. SEC-INST-01) e procedura prima installazione | `03-sicurezza/` |
| Catalogo dipendenze | `04-dipendenze/` |
| Licenze e verifica marchio (REQ-TM-01) | `05-licenze/` |
| Registro rischi (22 rischi) | `06-rischi/` |
| Checklist pre-M1, piano benchmark gaming+AI, strategia di test | `07-verifiche/` |
| Criteri di accettazione M0–M9 | `08-accettazione/` |
| Struttura repository e inizializzazione Git | `09-repository/` |

## 2. Cosa NON è stato fatto (conforme ai divieti)

Nessun codice operativo, nessuna ISO, nessuna build, nessuna installazione,
nessuna modifica al computer, nessun avvio di M1, nessuna modifica a `main`
(che non esiste ancora).

## 3. Esito delle richieste dell'autorizzazione M0

| # | Richiesta | Esito |
|---|---|---|
| 1 | Confronto Kinoite ufficiale vs Universal Blue, senza scelta definitiva | ADR-0002: tre opzioni confrontate; raccomandazione provvisoria C (ibrida); decisione al proprietario |
| 2 | Analisi separata bootc, rpm-ostree, aggiornamenti, rollback, firma | ADR-0003: strategia proposta (immagine OCI, rpm-ostree primario + bootc valutato, cosign, canali, rollback R1–R4) |
| 3 | Requisiti NVIDIA open per RTX 5070 Ti, opzioni Secure Boot | ADR-0004: verificato su README NVIDIA 595.84 che Blackwell richiede moduli open; opzioni SB-A…SB-E; proposta SB-A |
| 4 | Fedora Kinoite 45 come riferimento, con verifica del supporto | ADR-0005: GO e rilascio 3/11/2026 riportati da fonti secondarie; annuncio ufficiale **non verificato** (siti Fedora inaccessibili dall'ambiente); checklist F45-01..06 |
| 5 | SSD Windows scollegato alla prima installazione fisica | SEC-INST-01 obbligatorio con condizione di blocco; procedura dedicata |
| 6 | Verifica marchio prima della distribuzione pubblica | REQ-TM-01 con checklist TM-01..09; rischio R-14 |
| 7 | Benchmark gaming + AI con attenzione ai 16 GB VRAM | Piano con scenari B-00…B-C8 e politiche P-1…P-5 |
| 8 | Verifica reale del repository GitHub | Repository totalmente vuoto, nessun branch remoto: PR impossibile senza `main`; opzioni in `09-repository/inizializzazione-repository.md` |

## 4. Test eseguiti

Nessun test software (M0 è documentale). Verifiche effettuate:

- Conteggio delle 55 decisioni nel documento delle specifiche e nella matrice di tracciabilità.
- Consultazione delle fonti elencate in `../fonti.md`.

## 5. Decisioni aperte che richiedono il proprietario

| # | Decisione | Documento | Proposta di Claude |
|---|---|---|---|
| DA-01 | Base: Kinoite puro (A), Universal Blue (B), ibrida (C) | ADR-0002 | C; B solo come banco di prova in M3 |
| DA-02 | Opzione Secure Boot | ADR-0004 | SB-A (chiave MOK di progetto) |
| DA-03 | Client aggiornamenti primario | ADR-0003 | rpm-ostree in M1, bootc valutato in parallelo |
| DA-04 | Firma immagini | ADR-0003 | cosign con chiave (F1) |
| DA-05 | Release di riferimento | ADR-0005 | F45, condizionata alla checklist; F44 riserva |
| DA-06 | Inizializzazione di `main` | `09-repository/inizializzazione-repository.md` | Opzione 1 |
| DA-07 | Licenza del codice e della documentazione OMNI | `05-licenze/analisi-licenze.md` §3 | Da discutere (GPL-3.0+ o Apache-2.0) |
| DA-08 | Visibilità del repository e del registry (pubblico/privato) | `04-dipendenze/` §7 | Influisce su costi CI e REQ-TM-01 |
| DA-09 | Custodia delle chiavi di firma (segreti CI, token hardware) | ADR-0004, SEC-BOOT-02 | Segreti CI + copia offline cifrata |
| DA-10 | Struttura monorepo | `09-repository/struttura-repository.md` | Monorepo iniziale |
| DA-11 | Approvazione degli ADR-0001 e ADR-0006 | `02-adr/` | Accettare |

## 6. Informazioni da raccogliere (dal proprietario)

Checklist H-01…H-15 e A-01… in `07-verifiche/checklist-prerequisiti-m1.md`
(SSD, Secure Boot, BitLocker, backup, periferiche, giochi prioritari).

## 7. Problemi aperti e limiti

- Documentazione Fedora (docs.fedoraproject.org, forge, liste) non accessibile dall'ambiente di analisi: i punti marcati **[D]** vanno confermati prima di M1 (R-19).
- Le informazioni su Fedora 45 provengono da fonti secondarie.
- Le segnalazioni di instabilità del driver su RTX 50 sono comunitarie, non ufficiali.
- PR non creata: manca il branch di base (R-21).

## 8. Criteri di accettazione M0

AC-M0-01…AC-M0-10: soddisfatti dalla documentazione prodotta, **salvo revisione
del proprietario**. AC-M0-11 (approvazione): in attesa.
