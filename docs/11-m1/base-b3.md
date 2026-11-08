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
| 6. Autenticazione dell'artefatto derivato | Digest del manifest OCI (`index.json`) e sha256 di manifest, configurazione e ogni layer | Digest **fissato in `base.lock`** (`DERIVED_OCI_DIGEST`); ogni job lo ricalcola, verifica i blob e rifiuta un archivio diverso o manomesso (prove negative N1–N3) | La cache di Actions è scrivibile dai workflow del repository: per questo conta il digest fissato in git, non la cache |
| 7. Verifica autorevole per l'installazione | Reimportazione con ostree-ext (`ostree container image pull`, lo stesso meccanismo di bootc/rpm-ostree) in un repository nuovo | Il repository contiene il commit verificato (fsck ok) e l'**albero del commit installabile** (commit di unione creato da ostree-ext) è identico a quello del commit verificato: checksum di ogni file e dei metadati di ogni cartella (permessi, proprietari, xattr) | Eseguita in ogni job base, anche dall'archivio in cache |
| 8. Controllo nel sistema avviato | `vm_checks.sh` in P6 | Permessi di `grub.d`, `audit`, `nftables`, `selinux/targeted/active` e gruppo di `cups` in `/usr/etc` e `/etc` uguali al commit | — |

**Cosa NON viene conservato:** la firma GPG di Fedora riguarda il commit OSTree, non l'immagine OCI. L'OCI derivata **non porta una firma di Fedora**. È autenticata indirettamente (passi 5 e 6): contenuto identico a un commit firmato e digest fissato in git da una revisione. Non ha firma cosign di progetto, perché in M1 le chiavi definitive non sono autorizzate.

## 5. Recupero per le esecuzioni successive

1. **Cache di GitHub Actions** (chiave `omni-base-b3-<commit>-v1`, solo per i workflow di questo repository, non pubblica). Contiene solo l'archivio OCI e il file informativo.
2. **Ri-derivazione** dal repository Fedora, se la cache scade (7 giorni senza uso). La modalità `base-riverifica` del workflow `m1-completamento` ripete l'intera procedura senza cache; il risultato deve avere lo stesso `DERIVED_OCI_DIGEST`.

## 6. Esiti in CI

| Run | Data | Esito | Evidenze principali |
|---|---|---|---|
| 42185110369 | 2026-11-06 | Fallita (solo equivalenza, errore dello script) | Firma Good, fsck ok, conversione riuscita, digest `sha256:34ee4c0b…` |
| 42468076171 | 2026-11-08 | Riuscita | Firma Good (key ID 655A4B02F577861E), fsck ok, **stesso digest**, 134 517/134 517 file con contenuto identico, pull in 757 s |
| 42470569732 | 2026-11-08 | Fallita (nuovo controllo dei metadati) | Conversione da zero: **stesso digest per la terza volta**. File, contenuti, tipi e 40 721 collegamenti identici; nella **vista container** dell'OCI 456 cartelle sotto `etc/` appaiono 755/root (es. `etc/grub.d` 700, `etc/audit` 750, gruppo 7 di `etc/cups`) |
| 42472526145 | 2026-11-08 | Riuscita | Reimportazione ostree-ext: commit verificato presente, fsck ok; prove negative 3/3 sull'archivio reale |
| 42473035782 | 2026-11-08 | Riuscita | Albero del commit installabile (`68f8b9cc…`) **identico** all'albero del commit verificato: 190 155 voci con checksum di contenuto e metadati |

### Interpretazione della differenza nella vista container

Aggiornamento (run 42501784476, nuova derivazione sul branch d'integrazione, stesso digest): le cartelle con valori predefiniti nella vista container sono 458, cioè 452 sotto `etc/` e 6 sotto `usr/` (`usr/lib/bootupd/updates`, `usr/lib/containers/storage/overlay-images` e `overlay-layers`, `usr/lib/efi/grub2/…/EFI/fedora`, `usr/libexec/initscripts/legacy-actions/auditd`, `usr/libexec/utempter` con gruppo 35). Si tratta sempre e solo di cartelle. La tolleranza vale ora per le cartelle in qualunque percorso, sempre a condizione che la reimportazione dia metadati identici (in quella run: sì, 190 155 voci). In VM si controllano anche `utempter` e `legacy-actions/auditd`.


`podman image mount` mostra l'OCI come filesystem del container: è la vista usata dai passi `RUN` del Containerfile durante la build. In questa vista 456 cartelle sotto `etc/` hanno permessi e proprietario predefiniti. Il sistema installato invece viene ricostruito da ostree-ext dagli oggetti ostree inclusi nell'immagine, e la run 42473035782 dimostra che quell'albero coincide con il commit firmato.

**Rischio residuo (registrato):** un passo del Containerfile che scrive dentro una di quelle cartelle di `/etc` potrebbe riportare nel layer derivato i permessi della vista container. Per questo i permessi di quelle cartelle sono controllati nel sistema avviato (passo 8) e il Containerfile non deve modificarle senza verifica.

### Riesecuzione completa

La modalità `base-riverifica` ripete la procedura completa senza cache: chiave, pull con GPG, fsck, conversione, confronto, reimportazione e prove negative. Sono già state fatte tre conversioni indipendenti con lo stesso digest; la riesecuzione con tutte le regole attuali in un'unica run resta disponibile e va lanciata alla scadenza della cache o a ogni modifica di `base_b3.sh`.
