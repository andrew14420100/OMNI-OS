# Rapporto di milestone — M1 preliminare (avanzamento n. 1)

- **Data:** 2026-11-05
- **Autorizzazione:** M1 preliminare autorizzata dal proprietario il 2026-11-05: Fedora Kinoite 45 come riferimento; opzione C dell'ADR-0002 preferita ma **non definitiva**; prototipo **solo in VM**.
- **Stato:** **bloccato in attesa di decisione** sulla base OCI (condizione 4). Nessuna immagine costruita, nessuna VM avviata.

## 1. Attività svolte

| # | Attività | Esito |
|---|---|---|
| 1 | Verifica della PR #1 prima del merge | Ultimo commit `5b0218f` (quello revisionato), base `25f607b`, nessun conflitto, nessun commento, nessun commit imprevisto |
| 2 | Merge documentale della PR #1 | Eseguito con merge commit `4198f0b`; contenuto di `main` identico a `5b0218f` (diff vuoto); 26 file |
| 3 | Verifica della base OCI Kinoite 45 | Due candidate e un riferimento ostree analizzati; **nessuna base approvabile automaticamente** (`../11-m1/verifica-base-oci.md`) |
| 4 | Branch di lavoro M1 | `claude/zealous-ritchie-hnvev5` ripartito da `main` (`4198f0b`); `main` non modificato direttamente |
| 5 | Struttura di sviluppo | `image/Containerfile`, `image/base.lock` (stato `PENDING_OWNER_DECISION`), `image/files/usr/lib/omni-os/build-info` |
| 6 | Test automatici statici | `tests/run_static.sh`: documentazione (specifiche invariate per impronta SHA-256, 55 decisioni, 55 righe di tracciabilità, collegamenti), segreti, blocco della base |
| 7 | CI | `.github/workflows/ci.yml`: soli controlli statici + lint (hadolint, shellcheck con checksum fissati); nessuna build, nessun segreto, permessi in sola lettura |
| 8 | Proposta del percorso di build e test in VM | `../11-m1/percorso-build-vm.md` — **da approvare** |
| 9 | Documentazione aggiornata | ADR-0005 (F45-02), registro rischi (R-14, R-27, R-28…R-30), licenze (REQ-TM-01e su OmniOS), stato del repository, indici |

## 2. Test effettivamente eseguiti (nel container di Claude)

| Test | Risultato |
|---|---|
| `tests/run_static.sh` sul branch | **Superato** |
| Test negativi (copia temporanea del repository): specifiche modificate, riga di tracciabilità mancante, collegamento rotto, chiave privata nel testo, file `cosign.key`, password di recupero in formato BitLocker, base `APPROVED` con tag invece di digest, base valorizzata in stato `PENDING`, `APPROVED` senza `APPROVED_BY` | **9/9 rilevati** (il controllo fallisce come atteso) |
| Caso positivo: base `APPROVED` con digest valido (valore fittizio, solo nella copia temporanea) | **Superato** |
| hadolint 2.12.0 su `image/Containerfile` | **Superato** (DL3006 escluso con motivazione: la base arriva da `ARG` ed è vincolata al digest da `check_image.sh`) |
| shellcheck 0.10.0 sugli script | **Superato** |
| Sintassi YAML del workflow | **Valida** (parser Python) |
| Esecuzione del workflow su GitHub Actions | Esito riportato nella PR di M1 (vedi §4) |

**Non eseguiti** (e quindi **non** verificati): build dell'immagine, `bootc container lint`, avvio in VM, upgrade, rollback, firma di prova. Il `Containerfile` non è mai stato costruito.

## 3. Vincoli rilevati

- Il container di Claude non ha `/dev/kvm`, podman, qemu né un demone Docker: build e VM sono possibili solo in un altro ambiente (proposto: GitHub Actions, da verificare con un job di prova).
- La documentazione ufficiale Fedora non è consultabile da questo ambiente (protezione anti-bot).

## 4. CI

Il workflow `ci-statica` gira su push al branch di lavoro e sulle PR verso
`main`. L'esito della prima esecuzione è riportato nella descrizione della PR M1.

## 5. Decisioni richieste al proprietario

| # | Decisione | Documento |
|---|---|---|
| M1-D1 | Base OCI: A1 (ufficiale non firmata, solo VM), A2 (SIG firmata, sperimentale), A3 (ostree ufficiale firmato → OCI), A4 (composizione da RPM), A5 (attesa) | `../11-m1/verifica-base-oci.md` §5 |
| M1-D2 | Approvazione del percorso di build e test in VM su GitHub Actions, senza pubblicazione di immagini | `../11-m1/percorso-build-vm.md` |
| M1-D3 | Client per i test di upgrade/rollback in VM (rpm-ostree, bootc o entrambi) | `../11-m1/percorso-build-vm.md` §4 |

Restano aperte anche: licenza definitiva, strategia Secure Boot, custodia delle
chiavi, firma delle immagini definitiva, scelta definitiva della base
(ADR-0002), rischio di confusione con OmniOS (REQ-TM-01e).

## 6. Conformità ai limiti dell'autorizzazione

Nessuna modifica al PC, a Windows, ai dischi, al firmware o a Secure Boot.
Nessun installer, ISO, release o immagine pubblicata. Nessuna chiave generata.
M2 e M3 non avviate.
