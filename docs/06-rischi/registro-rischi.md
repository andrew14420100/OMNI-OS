# Registro dei rischi

- **Stato:** aggiornato al 2026-11-05 (M0).
- **Scala:** Probabilità (P) e Impatto (I) da 1 (basso) a 5 (alto); Punteggio = P × I.
- I rischi R-01…R-13 derivano dalla spec §7; i successivi sono emersi in M0.

| ID | Rischio | P | I | Punt. | Mitigazione | Responsabile | Milestone | Stato |
|---|---|---|---|---|---|---|---|---|
| R-01 | Ampiezza delle 55 funzionalità | 5 | 4 | 20 | Milestone progressive, matrice di tracciabilità, moduli indipendenti | Claude + proprietario | Tutte | Aperto |
| R-02 | Compatibilità NVIDIA RTX 5070 Ti | 4 | 5 | 20 | Solo moduli open; versione driver fissata; test M3; banco di prova con immagine nota (ADR-0002) | Claude | M3 | Aperto |
| R-03 | Secure Boot e avvio UEFI | 3 | 5 | 15 | ADR-0004 opzione SB-A; procedura MOK; supporto di recupero; foto impostazioni UEFI | Claude + proprietario | M2–M3 | Aperto |
| R-04 | Modifica accidentale di Windows | 2 | 5 | 10 | **SEC-INST-01 (scollegamento obbligatorio)**, SEC-INST-02..07 | Proprietario | M2–M3 | Aperto |
| R-05 | Problemi HDR/VRR sul monitor ASUS 4K | 4 | 2 | 8 | Test specifici M3/M5; profili di fallback; nessun supporto presunto | Claude | M3, M5 | Aperto |
| R-06 | Giochi incompatibili con Linux (anti-cheat, DRM) | 4 | 3 | 12 | Matrice per singolo gioco; nessuna garanzia universale; Windows resta disponibile in dual boot | Proprietario + Claude | M8 | Aperto |
| R-07 | Compromissione o perdita delle chiavi di firma (cosign, MOK) | 2 | 5 | 10 | Chiavi distinte; segreti CI con job di firma protetti; backup offline cifrato; rotazione e revoca (SEC-KEY-01…17) | Proprietario | M1+ | Aperto |
| R-08 | Esaurimento VRAM (16 GB) con gaming + AI | 4 | 3 | 12 | Piano benchmark combinato; budget VRAM; scaricamento modelli; priorità Gaming | Claude | M6 | Aperto |
| R-09 | Errori o abusi degli agenti AI (prompt injection) | 4 | 4 | 16 | SEC-AI-01..14; livelli R0–R3; audit; arresto globale | Claude | M6–M7 | Aperto |
| R-10 | Ripristino incompleto (dati non coperti dal rollback ostree) | 3 | 4 | 12 | Backup separati; avvisi in Update Center; prove reali di ripristino | Claude | M2, M5 | Aperto |
| R-11 | Vulnerabilità delle estensioni | 3 | 4 | 12 | SEC-EXT-01..05 | Claude | M8 | Aperto |
| R-12 | Dipendenza da API e servizi esterni | 3 | 2 | 6 | Integrazioni facoltative; modalità offline (RF-08) | Claude | M6–M8 | Aperto |
| R-13 | Licenze e redistribuzione | 3 | 4 | 12 | Analisi licenze; SBOM; restare in D0/D1 fino a M9 | Proprietario | M9 | Aperto |
| R-14 | **Conflitto con marchio "OMNI OS"**; esiste già il sistema operativo **OmniOS** (illumos) | 4 | 3 | 12 | REQ-TM-01a…d prima di ogni ulteriore passo pubblico; nomi tecnici centralizzati | Proprietario | Subito / prima di D2 | Aperto |
| R-15 | Dipendenza da immagini Universal Blue che possono essere ridotte o rimosse | 3 | 3 | 9 | ADR-0002 opzione C; Universal Blue solo come riferimento o banco di prova | Claude | M1 | Aperto |
| R-16 | Fedora 45 appena rilasciata (3/11/2026, confermato): regressioni iniziali, supporto NVIDIA per il kernel della release da confermare | 3 | 3 | 9 | Checklist F45-02..06; F44 come riserva | Claude | Pre-M1 | Aperto |
| R-17 | Instabilità di specifiche versioni del driver NVIDIA open su RTX 50 (segnalazioni Xid su 580.x) | 3 | 4 | 12 | Fissare versione driver; test di stabilità prolungati in M3; rollback di immagine | Claude | M3 | Aperto |
| R-18 | Cambio stato Secure Boot o firmware che attiva il ripristino BitLocker di Windows | 2 | 4 | 8 | Procedura controllata BitLocker (procedura prima installazione, parte F); SEC-INST-07; SEC-BOOT-05 | Proprietario | M3 | Aperto |
| R-19 | Documentazione Fedora non consultabile dall'ambiente di sviluppo (anti-bot) | 3 | 2 | 6 | Verifiche manuali del proprietario o fonti mirror; marcare i punti [D] | Claude | Pre-M1 | Aperto |
| R-20 | Limiti di GitHub Actions/registry per build di immagini (spazio, minuti) | 3 | 2 | 6 | Repository già pubblico (minuti Actions gratuiti); cache; valutazione in M1 | Claude | M1 | Aperto |
| R-21 | Repository GitHub senza branch di base: impossibile aprire PR | 5 | 2 | 10 | `main` creato sul commit vuoto `25f607b` su autorizzazione del proprietario (opzione 1) | Proprietario | M0 | **Chiuso** (2026-11-05) |
| R-22 | Perdita del lavoro non pubblicato nel container effimero di Claude | 3 | 2 | 6 | Branch di lavoro pubblicato su GitHub | Claude | M0 | **Chiuso** (2026-11-05) |

| R-23 | Nome "OMNI OS" già pubblico prima della verifica del marchio | 3 | 3 | 9 | REQ-TM-01a…d; nome dichiarato provvisorio | Proprietario | Subito | Aperto |
| R-24 | Pubblicazione accidentale di segreti o dati personali nel repository pubblico | 2 | 4 | 8 | REQ-PUB-03/04/06; dati sensibili solo in locale; scansione prima di ogni push | Claude + proprietario | Tutte | Aperto |
| R-25 | Furto di segreti CI tramite PR da fork in un repository pubblico | 2 | 5 | 10 | SEC-KEY-04: firma solo su push a `main`/tag, environment protetto, mai su `pull_request_target` | Claude | M1+ | Aperto |
| R-26 | Assenza di licenza in un repository pubblico (ambiguità per terzi e contributori) | 3 | 2 | 6 | REQ-PUB-01/02; decisione DA-07 | Proprietario | M0 | Aperto |
| R-27 | Nessun controllo automatico sulle PR (CI non configurata): errori di formato o segreti non intercettati automaticamente | 3 | 2 | 6 | Verifiche manuali documentate nel rapporto M0; CI proposta da M1 | Claude | M1 | **Mitigato** (CI con controlli statici dal 2026-11-05, M1) |

| R-28 | Base OCI Kinoite 45 ufficiale non firmata e con solo tag mobili: provenienza non verificabile, build non ripetibile se il digest viene rimosso | 4 | 4 | 16 | Build bloccata da `image/base.lock` finché il proprietario non sceglie (A1–A5); eventuale eccezione solo per prototipo VM | Proprietario | M1 | Aperto |
| R-29 | Runner GitHub Actions senza KVM o con spazio disco insufficiente per build e VM | 3 | 3 | 9 | Verifica del runner a ogni esecuzione: KVM presente, 4 CPU, 15 GB, 86–99 GB liberi (2026-11-05) | Claude | M1 | **Mitigato** |
| R-30 | Workflow CI in repository pubblico usato per eseguire codice da PR esterne | 2 | 3 | 6 | Solo `pull_request` (mai `pull_request_target`), `permissions: contents: read`, nessun segreto, azioni fissate per SHA | Claude | M1+ | Mitigato |

| R-31 | Guasti di rete transitori del registry esterno (osservato: EOF dal CDN di quay.io) | 3 | 2 | 6 | Fino a 3 tentativi in P1, controllo del digest obbligatorio | Claude | M1 | Mitigato |
| R-32 | Con bootc la verifica delle firme va richiesta esplicitamente; persistenza negli aggiornamenti successivi non verificata | 3 | 4 | 12 | Test T1 prima della scelta del gestore; raccomandazione provvisoria rpm-ostree | Claude | M1 | Aperto |

## Rischi principali (punteggio ≥ 15)

R-01, R-02, R-03, R-09, R-28: vanno riesaminati a ogni rapporto di milestone.
