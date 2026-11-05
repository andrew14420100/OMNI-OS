# M1 — Percorso di build e test in VM (proposta da approvare)

- **Stato:** **proposta**. Nessun passo di build o di avvio in VM è stato eseguito.
- **Prerequisito bloccante:** decisione sulla base OCI (`verifica-base-oci.md` §6).
- **Ambito:** prototipo **solo per macchina virtuale**. Esclusi: installer fisici, ISO, release pubbliche, immagini per utenti, modifiche al PC, a Windows, ai dischi, al firmware o a Secure Boot (autorizzazione M1, punti 8–9).

## 1. Vincoli dell'ambiente rilevati

| Ambiente | Situazione verificata | Conseguenza |
|---|---|---|
| Container di Claude | Ubuntu 24.04; 4 CPU, 15 GB RAM; **niente `/dev/kvm`**; niente podman, skopeo, qemu, cosign; demone Docker **non** disponibile | Qui non si possono costruire immagini né avviare VM in modo utile. Usato solo per documentazione e controlli statici |
| GitHub Actions (`ubuntu-24.04`) | Disponibilità di KVM, spazio disco e tempo massimo **da verificare** con un job di prova [D] | Ambiente proposto per build e test in VM |

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
