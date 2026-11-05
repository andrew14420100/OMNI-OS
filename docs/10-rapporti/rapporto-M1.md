# Rapporto di milestone — M1 preliminare

- **Data:** 2026-11-05
- **Autorizzazione:** M1 preliminare autorizzata dal proprietario il 2026-11-05: Fedora Kinoite 45 come riferimento; opzione C dell'ADR-0002 preferita ma **non definitiva**; prototipo **solo in VM**.
- **Stato attuale (avanzamento n. 2):** **prima immagine sperimentale OMNI OS costruita e avviata in VM**; tutti i passi P1–P9 superati nell'esecuzione 42099981099. M1 **non è conclusa**: alcuni criteri di accettazione sono parziali o non verificati (§8).
- **Avanzamento n. 1:** sotto, invariato (stato al momento della richiesta di decisione sulla base).

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

---

# Avanzamento n. 2 — build e test in VM (2026-11-05)

## 7. Decisioni del proprietario applicate

| # | Decisione | Applicazione |
|---|---|---|
| M1-D1 | A1, solo per prototipo in VM | `image/base.lock`: `quay.io/fedora/fedora-kinoite@sha256:0e0649d7…`, `BASE_SIGNED=false`, `SCOPE=VM_ONLY`; digest ricontrollato prima della build (e a ogni esecuzione, P1). La CI rifiuta una base non firmata senza `SCOPE=VM_ONLY` |
| M1-D2 | GitHub Actions | Workflow `m1-vm.yml`: permessi in sola lettura, nessun segreto, nessuna pubblicazione; runner verificato (KVM, 4 CPU, 15 GB, 86–99 GB liberi) |
| M1-D3 | Test con rpm-ostree e bootc | P8 e P9 eseguiti separatamente per entrambi; confronto in `../11-m1/risultati-test-vm.md` §3 |

## 8. Criteri di accettazione M1 (`../08-accettazione/criteri-accettazione.md`)

| Criterio | Stato | Evidenza |
|---|---|---|
| AC-M1-01 Build da commit con base fissata per digest | **Soddisfatto** | P1–P2, 5 esecuzioni |
| AC-M1-02 Avvio UEFI in VM con Secure Boot emulato attivo | **Soddisfatto** | P6 (UEFI) e P6b (variabile EFI `SecureBoot` = 1) |
| AC-M1-03 Login, desktop Plasma Wayland, rete | **Parziale** | Gestore di accesso `plasmalogin` attivo, `graphical.target` attivo, rete con IPv4. **Non verificati**: accesso di un utente e sessione Plasma Wayland; contenuto della schermata |
| AC-M1-04 Upgrade N → N+1 | **Soddisfatto** | P8 U1 con bootc e rpm-ostree |
| AC-M1-05 Rollback R1, R2, R3 | **Parziale** | R1 (deployment precedente) superato con entrambi; **R2** (deployment fissato) e **R3** (ritorno a un tag precedente nel registry) **non provati** |
| AC-M1-06 Rifiuto immagini non firmate o con firma errata | **Soddisfatto** (chiavi effimere) | P9 S1–S4; accettazione della firma valida S5–S6 |
| AC-M1-07 Ricostruzione equivalente dallo stesso commit | **Non verificato** | — |
| AC-M1-08 SBOM | **Non realizzato** | — |
| AC-M1-09 Confronto rpm-ostree / bootc | **Soddisfatto** | `risultati-test-vm.md` §3, §3.1 |
| AC-M1-10 NVIDIA dichiarato non verificato | **Soddisfatto** | Nessun driver NVIDIA in VM |

## 9. Test effettivamente eseguiti

Elenco completo, dati e problemi in `../11-m1/risultati-test-vm.md`. Sintesi:

- 5 esecuzioni complete di `m1-vm` dopo l'avvio delle prove; ultima completamente superata: **42099981099** (31 minuti).
- 9 problemi incontrati e documentati: 5 dovuti a errori dei miei test o della mia configurazione (SDDM presunto, storage di podman, attesa dell'avvio, autenticazione del registro, identità della firma), 1 di rete esterna (CDN di quay.io), 1 non spiegato (P2, non più riprodotto).
- Nessun test è stato disattivato o saltato per ottenere esiti positivi; l'unica tolleranza introdotta è `mcelog.service` in VM, motivata ed esplicita.

## 10. Raccomandazione sul gestore degli aggiornamenti (non decisione)

Provvisoriamente **rpm-ostree come gestore primario**, mantenendo la compatibilità con bootc: nessuna differenza funzionale osservata; con rpm-ostree l'obbligo di firma è nel riferimento dell'immagine; espone l'API D-Bus prevista. Prima della decisione definitiva: test T1 (persistenza della verifica con `bootc upgrade`), T2 (aggiornamenti automatici), T3 (tempi su più esecuzioni). Dettagli in `risultati-test-vm.md` §3.

## 11. Lavoro restante per concludere M1 (da autorizzare)

1. AC-M1-03: utente di prova e verifica della sessione Plasma Wayland in VM.
2. AC-M1-05: test R2 (`ostree admin pin`) e R3 (ritorno a un'immagine precedente da registry locale).
3. AC-M1-07: doppia build dallo stesso commit e confronto dell'elenco pacchetti.
4. AC-M1-08: generazione dello SBOM.
5. Test T1–T3 per la scelta del gestore.

## 12. Conformità ai limiti

Nessuna modifica al PC, a Windows, ai dischi, al BIOS/UEFI o a Secure Boot reale (Secure Boot è stato **emulato** nel firmware virtuale della VM). Nessun installer fisico, ISO, release o immagine pubblicata: le immagini sono esistite solo nei runner effimeri; il registro di P9 era raggiungibile solo dal loopback del runner. Nessuna chiave definitiva: solo chiavi SSH e cosign effimere, distrutte con il job. M2 e M3 non avviate. Restano aperte: licenza, Secure Boot, custodia delle chiavi, firma definitiva, base definitiva (ADR-0002), gestore definitivo (ADR-0003), confusione con OmniOS.
