# Struttura del repository e flusso di lavoro Git

- **Stato:** proposta M0. In M0 esistono solo `docs/` e un `README.md`, nella PR #1 (non ancora unita a `main`). Le altre cartelle saranno create **solo** nelle milestone che le richiedono, con autorizzazione.
- **Stato attuale:** repository pubblico; `main` contiene solo il commit iniziale vuoto; protezione di `main` e controlli automatici **non ancora configurati** (vedi `inizializzazione-repository.md`).

## 1. Struttura proposta (monorepo)

```
OMNI-OS/
├── README.md
├── docs/                      # M0: specifiche, architettura, ADR, sicurezza, ...
├── image/                     # M1: Containerfile, configurazioni dell'immagine
│   ├── Containerfile
│   ├── files/                 # file copiati in /usr e /etc
│   └── packages/              # elenchi pacchetti
├── kmods/                     # M1/M3: build e firma kmod NVIDIA (nessuna chiave privata!)
├── installer/                 # M2: configurazioni installer, kickstart
├── recovery/                  # M2: supporto di recupero
├── services/                  # M5: servizi Rust (workspace Cargo)
├── desktop/                   # M4: plasmoid, temi, script KWin (QML)
├── apps/                      # M5+: applicazioni OMNI
├── ai/                        # M6+: motore AI (Python)
├── tests/                     # test di integrazione, VM, sicurezza
└── .github/workflows/         # M1: CI
```

Alternativa da rivalutare in M5: repository separati per immagine, servizi,
desktop e AI. Il monorepo è proposto per l'inizio perché semplifica revisione
e tracciabilità.

## 2. Branch (Regola 15: sperimentale / test / stabile separati)

| Branch | Ruolo | Chi scrive | Protezione proposta |
|---|---|---|---|
| `main` | Stato integrato e approvato | Solo merge di PR approvate dal proprietario | PR obbligatoria, nessun push diretto, nessun force-push |
| `claude/<nome>` | Lavoro di Claude per una milestone o attività | Claude | Nessuna; sempre tramite PR in bozza |
| `release/x.y` (da M9) | Release stabile | Merge approvati | Come `main` |

Canali delle immagini (ADR-0003): `:dev` da branch di lavoro (solo VM),
`:testing` da `main`, `:stable` da `release/*` o tag approvati.

## 3. Regole per le PR

1. Ogni PR riguarda una milestone o un'attività indipendente (Regola 6).
2. La descrizione distingue implementato / testato / proposto (Regola 4).
3. Nessun merge senza approvazione del proprietario.
4. Le modifiche alle specifiche approvate sono evidenziate esplicitamente (Regola 2).
5. Nessun segreto (chiavi, token) né dato sensibile nel repository, che è pubblico (REQ-PUB-03/04).
6. Finché non esiste la CI, ogni PR riporta le verifiche manuali eseguite.

## 4. Commit

Formato proposto: `tipo(ambito): descrizione` (es. `docs(adr): ...`, `feat(image): ...`).
