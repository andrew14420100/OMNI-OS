# M1 — Percorso di build e test in VM (approvato)

- **Stato:** **approvato** dal proprietario il 2026-11-05 (decisioni M1-D1 = A1, M1-D2 = GitHub Actions, M1-D3 = test con bootc e rpm-ostree). In esecuzione; risultati in `risultati-test-vm.md`.
- **Base:** `quay.io/fedora/fedora-kinoite@sha256:0e0649d7…` (eccezione A1, non firmata, solo VM).
- **Ambito:** prototipo **solo per macchina virtuale**. Esclusi: installer fisici, ISO, release pubbliche, immagini per utenti, modifiche al PC, a Windows, ai dischi, al firmware o a Secure Boot (autorizzazione M1, punti 8–9).

## 1. Vincoli dell'ambiente rilevati

| Ambiente | Situazione verificata | Conseguenza |
|---|---|---|
| Container di Claude | Ubuntu 24.04; 4 CPU, 15 GB RAM; **niente `/dev/kvm`**; niente podman, skopeo, qemu, cosign; demone Docker **non** disponibile | Qui non si possono costruire immagini né avviare VM in modo utile. Usato solo per documentazione e controlli statici |
| GitHub Actions (`ubuntu-24.04`) | **Verificato** il 2026-11-05: KVM disponibile (`/dev/kvm`, accesso abilitato con regola udev), 4 CPU, 15 GB RAM, 86 GB liberi su `/`, podman 4.9.3, QEMU 8.2.2, OVMF (anche varianti Secure Boot) | Ambiente usato per build e test in VM |

## 2. Percorso proposto

```
image/base.lock (base approvata, digest)          ← decisione del proprietario
        │
        ▼  CI: controlli statici (già attivi)
image/Containerfile  ──podman build──►  immagine OCI locale al job (mai pubblicata)
        │                                  │
        │                                  ├─ bootc container lint
        │                                  └─ test sul contenuto (file OMNI presenti, versione)
        ▼
bootc-image-builder ──► disco qcow2 (solo artefatto del job, durata limitata)
        │
        ▼
QEMU + OVMF (UEFI) ──► avvio in VM ──► test automatici via console seriale
        │
        ▼
Rapporto di test (log del job)
```

### Passi e verifiche previste

| Passo | Strumento | Verifica automatica | Criterio M1 |
|---|---|---|---|
| P1 Base | `podman pull …@sha256:` | Digest uguale a `base.lock`; per A2 verifica cosign | AC-M1-01 |
| P2 Build | `podman build` | Build riuscita da commit Git | AC-M1-01 |
| P3 Lint | `bootc container lint` | Nessun errore | — |
| P4 Contenuto | `podman run` | File `/usr/lib/omni-os/build-info` presente e corretto | — |
| P5 Disco VM | `bootc-image-builder --type qcow2` | Disco creato | — |
| P6 Avvio UEFI | QEMU + OVMF | Il sistema raggiunge `multi-user.target`/`graphical.target` (console seriale) | AC-M1-02 (Secure Boot emulato in un passo successivo) |
| P7 Desktop | QEMU, screenshot via monitor QEMU | SDDM visibile (verifica visiva sullo screenshot) | AC-M1-03 |
| P8 Upgrade/rollback | `bootc switch`/`rpm-ostree` fra due build locali | Deployment N+1 attivo, poi rollback a N | AC-M1-04, AC-M1-05 |
| P9 Firma di prova | cosign con **chiave effimera generata nel job e distrutta a fine job** | Il client in VM rifiuta immagine non firmata e accetta quella firmata con la chiave di prova | AC-M1-06 |

Regole:

- **Nessuna pubblicazione**: le immagini restano nel job della CI (nessun push su registry, nessun artefatto pubblico permanente). Eventuali artefatti di debug (log, screenshot) con durata minima.
- **Chiavi**: solo effimere, generate e distrutte nello stesso job; nessun segreto nella CI (autorizzazione M1, punto 7).
- **Ordine**: P1–P4 per primi; P5–P9 solo dopo che P1–P4 sono verdi e verificati.
- **NVIDIA**: non incluso in M1 (nessuna GPU NVIDIA in VM; AC-M1-10).

## 3. Primo passo proposto dopo l'approvazione

1. Job di **prova dell'ambiente** (nessuna build): verifica KVM, spazio disco, versioni di podman/qemu sul runner.
2. P1–P4 con la base approvata.
3. Rapporto con i log effettivi prima di proseguire con P5–P9.

## 4. Decisioni richieste

| # | Decisione |
|---|---|
| M1-D1 | Base OCI: A1–A5 (`verifica-base-oci.md` §5) |
| M1-D2 | Approvazione di questo percorso di build (GitHub Actions, nessuna pubblicazione di immagini) |
| M1-D3 | Client per i test di upgrade/rollback in VM: rpm-ostree, bootc o entrambi (ADR-0003 resta aperto: il test serve proprio a confrontarli) |

## 5. Variazioni rispetto alla proposta approvata (Regola operativa 2)

Variazioni tecniche introdotte durante l'esecuzione. Nessuna modifica l'architettura, la base o i limiti di sicurezza.

| # | Proposta | Variazione | Motivo |
|---|---|---|---|
| V1 | P5 con `bootc-image-builder` | P5 con `bootc install to-disk --via-loopback`, eseguito dall'immagine OMNI stessa | Evita un'ulteriore immagine esterna non firmata (bootc-image-builder è un'immagine CentOS separata); usa il bootc già contenuto nella base |
| V2 | — | sshd attivato **solo sul disco di prova** tramite argomento del kernel `systemd.wants=sshd.service`, accesso root con chiave SSH effimera generata nel job | Permette i controlli automatici senza modificare l'immagine OMNI |
| V3 | P6 "Secure Boot emulato in un passo successivo" | Aggiunto P6b: avvio con OVMF Secure Boot (chiavi Microsoft) **solo nella VM** | Criterio AC-M1-02; nessun effetto sul PC del proprietario |
| V4 | P9 con registry non specificato | Registro OCI **locale effimero** sul runner, in ascolto solo su `127.0.0.1` (pacchetto Ubuntu `docker-registry`), distrutto con il runner | Le firme sigstore richiedono un registro; nessuna pubblicazione esterna |
| V5 | P9 con cosign | cosign **2.6.5** (non 3.x), `--tlog-upload=false` | cosign 3.x non offre l'opzione per evitare il registro pubblico di trasparenza Rekor: usarlo avrebbe pubblicato dati della firma |
| V6 | Storage podman | Storage predefinito `/var/lib/containers` | `bootc install` esegue il podman dell'host nel suo namespace: con uno storage personalizzato non trova l'immagine |
