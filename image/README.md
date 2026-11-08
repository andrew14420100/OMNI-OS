# Immagine OMNI OS (prototipo M1, solo VM)

- `Containerfile`: immagine derivata dalla base Kinoite 45 approvata, con le prime aggiunte OMNI (`/usr/lib/omni-os/build-info`).
- `base.lock`: base OCI approvata dal proprietario, **fissata per digest**. Stato attuale: `APPROVED`, eccezione A1 (non firmata, `SCOPE=VM_ONLY`).
- `files/`: file copiati nell'immagine.

Costruito e provato **solo nella CI** (`.github/workflows/m1-vm.yml`). Non destinato agli utenti, non installare su hardware reale.
