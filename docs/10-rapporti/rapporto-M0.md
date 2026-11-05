# Rapporto di milestone — M0 Preparazione tecnica e documentazione

- **Data:** 2026-11-05
- **Autorizzazione:** M0 autorizzata dal proprietario il 2026-11-05, esclusivamente per documentazione tecnica.
- **Stato M0:** documentazione completata, **in attesa di revisione e approvazione** (AC-M0-11).
- **M1:** **non avviata**; richiede approvazione esplicita.
- **Repository:** pubblico; `main` = commit iniziale vuoto `25f607b` (0 file); documentazione nella **PR #1 in bozza**, nessun merge.
- **Revisione 1 (2026-11-05):** correzioni richieste dal proprietario dopo l'esame della PR #1 (§9).

## 1. Cosa è stato fatto (solo documentazione)

| Area | Documento |
|---|---|
| Specifiche v1.0 (55 decisioni integrali) | `00-specifiche/specifiche-funzionali-v1.0.md` |
| Architettura e tracciabilità 55 decisioni | `01-architettura/` |
| ADR 0001–0006 | `02-adr/` |
| Sicurezza (incl. SEC-INST-01, gestione chiavi SEC-KEY) e procedura prima installazione (incl. procedura BitLocker) | `03-sicurezza/` |
| Catalogo dipendenze | `04-dipendenze/` |
| Licenze, repository pubblico (REQ-PUB) e verifica marchio (REQ-TM-01a…d) | `05-licenze/` |
| Registro rischi (27 rischi) | `06-rischi/` |
| Checklist pre-M1, piano benchmark gaming+AI, strategia di test | `07-verifiche/` |
| Criteri di accettazione M0–M9 | `08-accettazione/` |
| Struttura repository, stato e inizializzazione Git | `09-repository/` |

### Inventario dei file della PR #1

**26 file in totale:** `README.md` nella cartella principale + **25** documenti in `docs/`.

| Cartella | N. | File |
|---|---|---|
| (principale) | 1 | `README.md` |
| `docs/` | 2 | `README.md`, `fonti.md` |
| `docs/00-specifiche/` | 1 | `specifiche-funzionali-v1.0.md` |
| `docs/01-architettura/` | 2 | `architettura.md`, `tracciabilita-decisioni.md` |
| `docs/02-adr/` | 8 | `README.md`, `ADR-0000` … `ADR-0006` |
| `docs/03-sicurezza/` | 2 | `requisiti-sicurezza.md`, `procedura-prima-installazione.md` |
| `docs/04-dipendenze/` | 1 | `catalogo-dipendenze.md` |
| `docs/05-licenze/` | 1 | `analisi-licenze.md` |
| `docs/06-rischi/` | 1 | `registro-rischi.md` |
| `docs/07-verifiche/` | 3 | `checklist-prerequisiti-m1.md`, `piano-benchmark-gaming-ai.md`, `strategia-test.md` |
| `docs/08-accettazione/` | 1 | `criteri-accettazione.md` |
| `docs/09-repository/` | 2 | `struttura-repository.md`, `inizializzazione-repository.md` |
| `docs/10-rapporti/` | 1 | `rapporto-M0.md` |
| **Totale** | **26** | |

Nota: in una comunicazione precedente erano stati indicati per errore "26 documenti in `docs/` più il README" (27). Il conteggio corretto, verificato sulla PR, è 26.

## 2. Cosa NON è stato fatto (conforme ai divieti)

Nessun codice operativo, nessuna ISO, nessuna build, nessuna installazione,
nessuna modifica al computer, nessun avvio di M1. Su `main` è stato pubblicato
soltanto il commit iniziale vuoto `25f607b`, su autorizzazione del proprietario;
nessun merge è stato eseguito.

## 3. Esito delle richieste dell'autorizzazione M0

| # | Richiesta | Esito |
|---|---|---|
| 1 | Confronto Kinoite ufficiale vs Universal Blue, senza scelta definitiva | ADR-0002: tre opzioni confrontate; raccomandazione provvisoria C (ibrida); decisione al proprietario |
| 2 | Analisi separata bootc, rpm-ostree, aggiornamenti, rollback, firma | ADR-0003: strategia proposta (immagine OCI, rpm-ostree primario + bootc valutato, cosign, canali, rollback R1–R4) |
| 3 | Requisiti NVIDIA open per RTX 5070 Ti, opzioni Secure Boot | ADR-0004: verificato su README NVIDIA 595.84 che Blackwell richiede moduli open; opzioni SB-A…SB-E; proposta SB-A |
| 4 | Fedora Kinoite 45 come riferimento, con verifica del supporto | ADR-0005: rilascio ufficiale del 3/11/2026 **verificato** su Fedora Magazine e fedoraproject.org (F45-01 superata); restano F45-02..06; la conferma non approva l'architettura |
| 5 | SSD Windows scollegato alla prima installazione fisica | SEC-INST-01 obbligatorio con condizione di blocco; procedura dedicata |
| 6 | Verifica marchio prima della distribuzione pubblica | REQ-TM-01a…d (aggiornato: repository già pubblico) con checklist TM-01..09; rischi R-14, R-23 |
| 7 | Benchmark gaming + AI con attenzione ai 16 GB VRAM | Piano con scenari B-00…B-C8 e politiche P-1…P-5 |
| 8 | Verifica reale del repository GitHub | Repository inizialmente vuoto; inizializzato con l'opzione 1 autorizzata: `main` sul commit vuoto `25f607b`, PR in bozza #1; stato in `09-repository/inizializzazione-repository.md` |

## 4. Test eseguiti

Nessun test software (M0 è documentale). Verifiche effettuate:

- Conteggio delle 55 decisioni nel documento delle specifiche e nella matrice di tracciabilità (numerazione 1–55 senza buchi).
- Consultazione delle fonti elencate in `../fonti.md`.
- Verifica dei collegamenti relativi fra documenti.
- Scansione manuale di credenziali e segreti prima di ogni push (nessun risultato).
- Verifica da una copia nuova del repository: `main` con 0 file; branch di lavoro con 26 file.

**Controlli automatici:** **nessuno configurato.** Il repository non ha workflow CI né altri controlli sulle PR e GitHub non riporta alcun check sulla PR #1. Tutte le verifiche sopra sono manuali. L'introduzione della CI è prevista non prima di M1, con autorizzazione (rischio R-27).

## 5. Decisioni aperte che richiedono il proprietario

| # | Decisione | Documento | Proposta di Claude |
|---|---|---|---|
| DA-01 | Base: Kinoite puro (A), Universal Blue (B), ibrida (C) | ADR-0002 | C; B solo come banco di prova in M3 — **aperta** |
| DA-02 | Opzione Secure Boot | ADR-0004 | SB-A (chiave MOK di progetto) — **non adottata, aperta** |
| DA-03 | Client aggiornamenti primario | ADR-0003 | rpm-ostree in M1, bootc valutato in parallelo — **aperta** |
| DA-04 | Firma immagini | ADR-0003 | cosign con chiave (F1) — **aperta** |
| DA-05 | Release di riferimento | ADR-0005 | F45 (rilascio ufficiale verificato), condizionata a F45-02..06; F44 riserva |
| DA-06 | Inizializzazione di `main` | `09-repository/inizializzazione-repository.md` | **Decisa**: opzione 1 autorizzata ed eseguita il 2026-11-05 |
| DA-07 | Licenza del codice e della documentazione OMNI | `05-licenze/analisi-licenze.md` §3 | Da discutere (GPL-3.0+ o Apache-2.0) — **aperta, prioritaria** perché il repository è già pubblico (REQ-PUB-01) |
| DA-08 | Visibilità del registry delle immagini (il repository è già **pubblico**) | `04-dipendenze/` §7 | Influisce su costi CI, licenze (D2) e REQ-TM-01a |
| DA-09 | Custodia, rotazione e revoca delle chiavi di firma (cosign e MOK separate) | `03-sicurezza/requisiti-sicurezza.md` §5.1 | Segreti CI con job protetti + copia offline cifrata; token hardware da valutare per la MOK |
| DA-10 | Struttura monorepo | `09-repository/struttura-repository.md` | Monorepo iniziale |
| DA-11 | Approvazione degli ADR-0001 e ADR-0006 | `02-adr/` | Accettare |
| DA-12 | Protezione del branch `main` (impostazione GitHub, solo il proprietario) | `09-repository/inizializzazione-repository.md` §3 | PR obbligatoria, approvazione, no force-push |
| DA-13 | Uso della sospensione temporanea di BitLocker (F.2) | `03-sicurezza/procedura-prima-installazione.md` parte F | Non usarla per default |

## 6. Informazioni da raccogliere (dal proprietario)

Checklist H-01…H-15 e A-01… in `07-verifiche/checklist-prerequisiti-m1.md`
(SSD, Secure Boot, BitLocker, backup, periferiche, giochi prioritari).

## 7. Problemi aperti e limiti

- Documentazione Fedora (docs.fedoraproject.org, forge, liste) non accessibile dall'ambiente di analisi: i punti marcati **[D]** vanno confermati prima di M1 (R-19).
- Rilascio di Fedora 45 confermato da fonti ufficiali; kernel e versione Plasma della release finale ancora da confermare. La pagina di download mostrava ancora un'etichetta "BETA" (anomalia da ricontrollare).
- Le segnalazioni di instabilità del driver su RTX 50 sono comunitarie, non ufficiali.
- Repository inizializzato su autorizzazione del proprietario (opzione 1): `main` = commit iniziale vuoto `25f607b`; PR in bozza #1 verso `main`, senza merge (R-21 chiuso).

## 8. Criteri di accettazione M0

AC-M0-01…AC-M0-10: soddisfatti dalla documentazione prodotta, **salvo revisione
del proprietario**. AC-M0-11 (approvazione): in attesa.

## 9. Revisione 1 — correzioni richieste dal proprietario (2026-11-05)

| # | Richiesta | Modifica |
|---|---|---|
| 1 | Aggiornare le indicazioni obsolete su repository e commit | `09-repository/inizializzazione-repository.md` riscritto con stato attuale e cronologia; aggiornati questo rapporto, registro rischi, checklist, `struttura-repository.md` |
| 2 | Separare firma cosign e firma MOK; custodia, rotazione, revoca | `03-sicurezza/requisiti-sicurezza.md` §5.1–5.2 (SEC-KEY-01…12); rimandi in ADR-0003 e ADR-0004 |
| 3 | Procedura controllata per la chiave di recupero BitLocker | `03-sicurezza/procedura-prima-installazione.md` parte F; SEC-BOOT-05; R-18 aggiornato |
| 4 | Marchio e licenze con repository già pubblico | `05-licenze/analisi-licenze.md`: REQ-PUB-01…07, REQ-TM-01a…d; R-23…R-26; nota nel `README.md` |
| 5 | Conteggio file uniforme | Inventario §1: 26 file (README + 25 in `docs/`); nessun file aggiunto o rimosso |
| 6 | Assenza di controlli automatici | §4 di questo rapporto, `09-repository/`, `07-verifiche/strategia-test.md`, R-27 |

Decisioni che restano **aperte** (nessuna presa con questa revisione): base
Fedora/Universal Blue (DA-01), Secure Boot (DA-02), client di aggiornamento
(DA-03), firma delle immagini (DA-04), licenza (DA-07).
