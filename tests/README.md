# Test OMNI OS

| Comando | Cosa verifica | Stato |
|---|---|---|
| `bash tests/run_static.sh` | Specifiche invariate (impronta in `static/spec.sha256`), 55 decisioni e 55 righe di tracciabilità, collegamenti Markdown, assenza di segreti e chiavi private, blocco della base in `image/base.lock` | Attivo in CI (`ci-statica`) |
| Test in VM (build, avvio UEFI, upgrade, rollback, firma di prova) | Vedi `docs/11-m1/percorso-build-vm.md` | **Non implementati**: attendono l'approvazione della base OCI e del percorso di build |

Se l'impronta delle specifiche deve cambiare, serve un'approvazione esplicita del
proprietario (Regola operativa 2): aggiornare `static/spec.sha256` nella stessa PR
che modifica le specifiche, motivandolo.
