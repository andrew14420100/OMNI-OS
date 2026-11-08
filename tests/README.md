# Test OMNI OS

| Comando | Cosa verifica | Stato |
|---|---|---|
| `bash tests/run_static.sh` | Specifiche invariate (impronta in `static/spec.sha256`), 55 decisioni e 55 righe di tracciabilità, collegamenti Markdown, assenza di segreti e chiavi private, blocco della base in `image/base.lock` | Attivo in CI (`ci-statica`) |
| `tests/vm/*` tramite `.github/workflows/m1-vm.yml` | Verifica del runner, P1–P9: base per digest, build, lint, contenuto, disco, avvio UEFI e Secure Boot emulato, schermata, aggiornamento/rollback/errori con bootc e rpm-ostree, firme con chiavi effimere | Attivo; risultati in `docs/11-m1/risultati-test-vm.md` |

Se l'impronta delle specifiche deve cambiare, serve un'approvazione esplicita del
proprietario (Regola operativa 2): aggiornare `static/spec.sha256` nella stessa PR
che modifica le specifiche, motivandolo.
