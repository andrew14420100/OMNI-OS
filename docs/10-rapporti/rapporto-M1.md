# Rapporto di milestone — M1 preliminare

- **Data:** 2026-11-05
- **Autorizzazione:** M1 preliminare autorizzata dal proprietario il 2026-11-05: Fedora Kinoite 45 come riferimento; opzione C dell'ADR-0002 preferita ma **non definitiva**; prototipo **solo in VM**.
- **Stato attuale (avanzamento n. 3, 2026-11-06):** **bloccato**: il digest della base A1 approvata è stato rimosso da quay.io; nessuna build possibile senza una nuova decisione del proprietario (§13).
- **Avanzamento n. 2:** **prima immagine sperimentale OMNI OS costruita e avviata in VM**; tutti i passi P1–P9 superati nell'esecuzione 42099981099. M1 **non è conclusa**: alcuni criteri di accettazione sono parziali o non verificati (§8).
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

---

# Avanzamento n. 3 — completamento di M1 (2026-11-06): bloccato

## 13. Stato

- Autorizzazione del 2026-11-06 al completamento dei test mancanti (AC-M1-03, 05, 07, 08 e T1–T3), solo in VM.
- **Preparato** (commit `623f27e`, `fc535fd`): workflow `m1-completamento` con 10 job, script `desktop_test.sh`, `recovery_test.sh`, `managers_test.sh`, `timing_test.sh`, `repro_collect.sh`/`repro_compare.py`, `sbom_check.py`, libreria `lib.sh`. Controlli statici e lint superati; verifiche locali dei calcoli statistici, del confronto di riproducibilità e del controllo SBOM su dati sintetici (positivi e negativi).
- **Eseguito**: nessun test in VM. La prima esecuzione (42183152118) si è fermata nella preparazione: il digest approvato `sha256:0e0649d7…` non esiste più su quay.io (dettagli in `../11-m1/risultati-test-vm.md` §6).
- La condizione 4 dell'autorizzazione M1 vieta di sostituire la base automaticamente: **attendo una decisione**.

## 14. Alternative per la base (decisione del proprietario)

| # | Alternativa | Disponibilità verificata | Pro | Contro |
|---|---|---|---|---|
| B1 | A1 con il **nuovo** digest `45.20261106.0` (amd64 `sha256:5bd1be0e…`), conservato per la durata delle prove nella **cache di GitHub Actions** del repository (non è un registry e non è scaricabile dall'esterno) | Oggi sì; domani il digest sparirà da quay.io | Il più rapido; stessa fonte di P1–P9 | Ancora non firmata; la cache dura al massimo 7 giorni senza uso; la riproducibilità resta limitata alla cache; P1–P9 vanno ripetuti con la nuova base |
| B2 | A2: `quay.io/fedora-ostree-desktops/kinoite` con tag datato e **verifica cosign** | Tag datati conservati circa 4 settimane | Firmata; tag datati | Dichiarata sperimentale e non ufficiale; richiede la chiave pubblica del SIG |
| B3 | A3: base OCI costruita dal **commit ostree ufficiale firmato** (repository Fedora), con verifica GPG | Il commit di ieri è ancora presente con la firma | Ufficiale, verificabile, commit storici disponibili; è la direzione preferita prima di M3 | Più lavoro (incapsulamento OCI e verifica GPG); implementazione **non ancora autorizzata** |

**Raccomandazione (non vincolante):** **B3**, perché risolve insieme provenienza e riproducibilità, e perché comunque servirà prima di M3. Se preferisci completare subito M1, **B1** come soluzione temporanea per le sole prove in VM, accettando che AC-M1-07 venga dimostrato solo sulla durata della cache.

---

# Avanzamento n. 4 — rapporto finale di M1 sulla base B3 (2026-11-08)

## 15. Base

Base **B3**, approvata dal proprietario: commit OSTree Fedora 45 Kinoite `5a4ff74f…` (45.20261106.0), con firma GPG Fedora verificata, convertito in OCI con digest fissato `sha256:34ee4c0b…`. La provenienza e le verifiche (equivalenza dei contenuti, reimportazione ostree, metadati, prove negative) sono in `../11-m1/base-b3.md`.

## 16. Criteri di accettazione M1 — valutazione finale

| Criterio | Esito | Esecuzioni GitHub di riferimento | Problemi e limiti |
|---|---|---|---|
| AC-M1-01 Build da commit con base fissata per digest | **Superato** | m1-vm 42473555885 (P1–P4); m1-completamento 42476148840, 42478499478, 42480227200, 42493088051, 42495967226, 42498047150 | La base è un artefatto derivato: la firma Fedora copre il commit OSTree, non l'OCI (catena di fiducia in `base-b3.md` §4) |
| AC-M1-02 Avvio UEFI con Secure Boot emulato | **Superato** | 42473555885 (P6, P6b) | Secure Boot **emulato** in OVMF con le chiavi Microsoft predefinite; nessuna prova su firmware reale (M3) |
| AC-M1-03 Accesso, desktop Plasma Wayland, rete | **Superato** | 42478499478 (20/20 controlli); rete in 42473555885 P6 | Il criterio cita SDDM; Fedora Kinoite 45 usa **plasmalogin** (plasma-login-manager 6.8.2), verificato come gestore di accesso reale. Prima esecuzione 42476148840 fallita per un errore del test (socket `wayland-0` presunto) |
| AC-M1-04 Aggiornamento N → N+1 | **Superato** | 42473555885 (P8 U1, bootc e rpm-ostree); 42476148840 (R2.1, R2.3) | — |
| AC-M1-05 Rollback R1, R2, R3 | **Superato** | R1: 42473555885 (P8); R2/R3: 42476148840 (bootc e rpm-ostree) | R3 provato con un registro temporaneo solo loopback, non con un registro pubblico |
| AC-M1-06 Rifiuto di immagini non firmate o con firma errata | **Superato** (chiavi di prova) | 42473555885 (P9 S1–S6); 42480227200 e 42493088051 (T1/T2) | Chiavi cosign **effimere**, nessun registro di trasparenza; custodia e firma definitive restano decisioni aperte |
| AC-M1-07 Ricostruzione equivalente (elenco pacchetti identico) | **Superato** (riproducibilità funzionale) | 42498047150 | Due build su runner diversi: 1746 pacchetti, 472 244 voci del filesystem e 402 151 file con contenuto e metadati identici. **Identità binaria non raggiunta**: 2 layer su 67 diversi, 12 413 date di modifica diverse. La variante `--timestamp 0` è in ripetizione senza cache (vedi §17) |
| AC-M1-08 SBOM | **Superato** | 42495967226 | SPDX 2.3 e CycloneDX 1.7 (syft 1.55.0): 1746 RPM in entrambi, 0 pacchetti installati mancanti, 0 in eccesso. Licenze non ancora riesaminate (M9) |
| AC-M1-09 Confronto rpm-ostree / bootc documentato | **Superato** | 42473555885, 42476148840, 42480227200, 42493088051 | Tempi (T3) senza differenze significative. Finalizzazione intermittente con bootc (R-34, 1 caso su 2 esecuzioni di T1/T2). La scelta del gestore resta del proprietario |
| AC-M1-10 NVIDIA dichiarato non verificato | **Superato** | — | **Dichiarazione:** nessun driver o hardware NVIDIA è stato provato. Le VM usano grafica virtuale QEMU; RTX 5070 Ti, driver open, MOK e Secure Boot reale restano per M3 |

## 17. Valutazione

- **10 criteri su 10 superati in VM**, con i limiti indicati.
- **Aperti, ma non bloccanti per i criteri:**
  - R-34: finalizzazione intermittente con bootc;
  - variante `--timestamp 0` di AC-M1-07, in ripetizione per misurare l'identità binaria. La riproducibilità funzionale, che è quanto chiede il criterio, è già dimostrata.
- **Non verificato e fuori ambito M1:** hardware reale, NVIDIA, Secure Boot reale, installer, dati utente.
- M1 si conclude formalmente solo con l'approvazione del proprietario e il merge della PR #2, che **non** è stato fatto.
