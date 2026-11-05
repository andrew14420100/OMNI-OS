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
| R-07 | Compromissione o perdita delle chiavi di firma (cosign, MOK) | 2 | 5 | 10 | Segreti CI, backup offline cifrato della chiave, procedura di rotazione e revoca | Proprietario | M1+ | Aperto |
| R-08 | Esaurimento VRAM (16 GB) con gaming + AI | 4 | 3 | 12 | Piano benchmark combinato; budget VRAM; scaricamento modelli; priorità Gaming | Claude | M6 | Aperto |
| R-09 | Errori o abusi degli agenti AI (prompt injection) | 4 | 4 | 16 | SEC-AI-01..14; livelli R0–R3; audit; arresto globale | Claude | M6–M7 | Aperto |
| R-10 | Ripristino incompleto (dati non coperti dal rollback ostree) | 3 | 4 | 12 | Backup separati; avvisi in Update Center; prove reali di ripristino | Claude | M2, M5 | Aperto |
| R-11 | Vulnerabilità delle estensioni | 3 | 4 | 12 | SEC-EXT-01..05 | Claude | M8 | Aperto |
| R-12 | Dipendenza da API e servizi esterni | 3 | 2 | 6 | Integrazioni facoltative; modalità offline (RF-08) | Claude | M6–M8 | Aperto |
| R-13 | Licenze e redistribuzione | 3 | 4 | 12 | Analisi licenze; SBOM; restare in D0/D1 fino a M9 | Proprietario | M9 | Aperto |
| R-14 | **Conflitto con marchio "OMNI OS"** | 3 | 3 | 9 | REQ-TM-01 prima di ogni distribuzione pubblica; nomi tecnici centralizzati | Proprietario | Prima di D2 | Aperto |
| R-15 | Dipendenza da immagini Universal Blue che possono essere ridotte o rimosse | 3 | 3 | 9 | ADR-0002 opzione C; Universal Blue solo come riferimento o banco di prova | Claude | M1 | Aperto |
| R-16 | Fedora 45 appena rilasciata: regressioni iniziali, supporto NVIDIA per kernel 7.2 da confermare | 3 | 3 | 9 | Checklist F45-01..06; F44 come riserva | Claude | Pre-M1 | Aperto |
| R-17 | Instabilità di specifiche versioni del driver NVIDIA open su RTX 50 (segnalazioni Xid su 580.x) | 3 | 4 | 12 | Fissare versione driver; test di stabilità prolungati in M3; rollback di immagine | Claude | M3 | Aperto |
| R-18 | Cambio stato Secure Boot che attiva il ripristino BitLocker di Windows | 2 | 4 | 8 | Chiave di recupero BitLocker disponibile (SEC-INST-07); evitare SB-D | Proprietario | M3 | Aperto |
| R-19 | Documentazione Fedora non consultabile dall'ambiente di sviluppo (anti-bot) | 3 | 2 | 6 | Verifiche manuali del proprietario o fonti mirror; marcare i punti [D] | Claude | Pre-M1 | Aperto |
| R-20 | Limiti di GitHub Actions/registry per build di immagini (spazio, minuti) | 3 | 2 | 6 | Repository pubblico o runner alternativo; cache; valutazione in M1 | Claude | M1 | Aperto |
| R-21 | Repository GitHub senza branch di base: impossibile aprire PR | 5 | 2 | 10 | Inizializzazione `main` su autorizzazione del proprietario (`../09-repository/inizializzazione-repository.md`) | Proprietario | M0 | Aperto |
| R-22 | Perdita del lavoro non pubblicato nel container effimero di Claude | 3 | 2 | 6 | Push del branch di lavoro appena autorizzato | Claude | M0 | Aperto |

## Rischi principali (punteggio ≥ 15)

R-01, R-02, R-03, R-09: vanno riesaminati a ogni rapporto di milestone.
