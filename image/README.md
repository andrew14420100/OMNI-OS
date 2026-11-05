# Immagine OMNI OS (prototipo M1, solo VM)

- `Containerfile`: immagine derivata dalla base Kinoite 45 approvata, con le prime aggiunte OMNI (`/usr/lib/omni-os/build-info`).
- `base.lock`: base OCI approvata dal proprietario, **fissata per digest**. Stato attuale: `PENDING_OWNER_DECISION`, quindi **nessuna build è consentita** (controllo `tests/static/check_image.sh`).
- `files/`: file copiati nell'immagine.

Il `Containerfile` **non è mai stato costruito**. Non destinato agli utenti, non installare su hardware reale.
