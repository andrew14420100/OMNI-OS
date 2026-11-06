# M1 — Base B3: commit OSTree ufficiale Fedora verificato con GPG

- **Decisione del proprietario:** B3, 2026-11-06. La base A1 non è più autorizzata.
- **Ambito:** solo prototipo in VM (`SCOPE=VM_ONLY`), nessuna pubblicazione.
- **Configurazione:** `image/base.lock`; procedura: `tests/vm/base_b3.sh`.

## 1. Commit scelto

| Campo | Valore |
|---|---|
| Repository | `https://kojipkgs.fedoraproject.org/ostree/repo` (repository OSTree di Fedora) |
| Ref | `fedora/45/x86_64/kinoite` (punta al 2026-11-06) |
| Commit | `5a4ff74fe7c41650bde359ab7b1e30fc7f80ad3eac97e492ed45d067cf19f06a` |
| Versione | `45.20261106.0` (data del commit 2026-11-06 00:37:22 UTC) |
| Genitore | `83719586c6fd…` (45.20261105.0) |
| ContentChecksum | `a1e26cb219444e3eec19a154f7f200181dc557672d7994a24d901e3aa4a690b8` |

## 2. Chiave di verifica

Chiave **Fedora 45 primary**, RSA 4096, ID `655A4B02F577861E`, creata il 2025-07-29.

Impronta **`4F50 A611 4CD5 C697 6A7F 1179 655A 4B02 F577 861E`**, verificata **concordante su tre fonti ufficiali** il 2026-11-06:

| Fonte | Esito |
|---|---|
| `src.fedoraproject.org/rpms/fedora-repos` → `RPM-GPG-KEY-fedora-45-primary` | Stessa impronta |
| `fedoraproject.org/fedora.gpg` (portachiavi delle release) | Stessa impronta, con le chiavi 43, 44, 46 |
| `fedoraproject.org/security` (pagina delle chiavi) | Stessa impronta pubblicata come testo |

In CI la procedura controlla le prime due fonti a ogni preparazione e si ferma se l'impronta differisce da `GPG_FINGERPRINT` in `base.lock`.

## 3. Verifica della firma (eseguita in locale il 2026-11-06, ostree 2024.5)

| Prova | Comando | Esito |
|---|---|---|
| Firma con la chiave Fedora 45 | `ostree pull` (remoto con `gpg-verify=true` e `gpgkeypath`) + `ostree show --gpg-verify-remote` | `Good signature from "Fedora <fedora-45-primary@fedoraproject.org>"`, `RSA key ID 655A4B02F577861E` |
| Negativa: chiave sbagliata (Fedora 44) | `ostree pull` | **Rifiutato** (codice 1, "public key not found") |
| Negativa: nessuna chiave fidata | `ostree pull` con `gpg-verify=true` | **Rifiutato** (codice 1) |
| Negativa: oggetto di firma manomesso | `ostree show --gpg-verify-remote` | `BAD signature` |

**Problema rilevato e gestito:** `ostree show --gpg-verify-remote` termina con codice **0** anche con `Can't check signature` e con `BAD signature`. Il suo codice di uscita **non** è quindi una verifica. La procedura usa due controlli indipendenti: il pull con `gpg-verify=true`, che rifiuta i commit non firmati correttamente, e l'analisi rigorosa dell'output. Questa richiede `Good signature` dalla chiave `655A4B02F577861E` e l'assenza di `BAD`, `Can't check`, `EXPIRED` e `REVOKED`.

**Conservazione:** la catena dei genitori del ref è scaricabile con le firme almeno fino al 2026-10-25 (15 commit verificati, fra cui la release `45.1.4`). Il commit scelto resta quindi disponibile anche dopo lo spostamento del ref, a differenza dei digest A1 su quay.io.

## 4. Catena di fiducia e proprietà conservate

| Passo | Strumento | Proprietà garantita | Limite |
|---|---|---|---|
| 1. Chiave | gpg sul runner | Impronta uguale su due fonti ufficiali e a quella fissata in git | Si presume che le fonti Fedora non siano tutte compromesse insieme |
| 2. Firma del commit | `ostree pull` con `gpg-verify=true` | Il commit è stato firmato da Fedora con la chiave 45 primary | — |
| 3. Integrità del contenuto | `ostree fsck` | Ogni oggetto corrisponde alla sua impronta; il checksum del commit (firmato) copre l'intero albero (Merkle) | — |
| 4. Conversione in OCI | `rpm-ostree compose container-encapsulate` in `quay.io/fedora/fedora:45` (rpm-ostree installato da dnf con verifica GPG dei pacchetti) | — | Il container dello strumento **non** è verificato crittograficamente; per questo il passo 5 non si fida della conversione |
| 5. Verifica del risultato | `ostree checkout` del commit verificato e `podman image mount` dell'OCI, sul runner Ubuntu (strumenti diversi da quelli della conversione) | Ogni file del commit è presente nell'OCI con lo **stesso SHA-256**; elencati i file aggiunti dalla conversione | Non copre i metadati OCI (etichette, configurazione) oltre l'etichetta `ostree.commit`, che deve essere uguale al commit |
| 6. Autenticazione dell'artefatto derivato | Digest del manifest OCI (`index.json`) | Dopo la revisione il digest viene **fissato in `base.lock`** (`DERIVED_OCI_DIGEST`); ogni job lo ricalcola e rifiuta un archivio diverso | La cache di Actions è scrivibile dai workflow del repository: per questo conta il digest fissato in git, non la cache |

**Cosa NON viene conservato:** la firma GPG di Fedora riguarda il commit OSTree, non l'immagine OCI. L'OCI derivata **non porta una firma di Fedora**. È autenticata indirettamente (passi 5 e 6): contenuto identico a un commit firmato e digest fissato in git da una revisione. Non ha firma cosign di progetto, perché in M1 le chiavi definitive non sono autorizzate.

## 5. Recupero per le esecuzioni successive

1. **Cache di GitHub Actions** (chiave `omni-base-b3-<commit>-v1`, solo per i workflow di questo repository, non pubblica). Contiene solo l'archivio OCI e il file informativo.
2. **Ri-derivazione** dal repository Fedora, se la cache scade (7 giorni senza uso). La modalità `base-riverifica` del workflow `m1-completamento` ripete l'intera procedura senza cache; il risultato deve avere lo stesso `DERIVED_OCI_DIGEST`.

## 6. Esiti in CI

_Da completare con le esecuzioni: digest derivato, equivalenza dei contenuti, tempi, differenze rispetto ad A1._
