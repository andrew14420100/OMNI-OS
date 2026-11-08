# M1 — Verifica della base OCI Fedora Kinoite 45

- **Data della verifica:** 2026-11-05 (circa 17:15 UTC).
- **Esito:** **nessuna base approvata.** Nessuna delle due immagini OCI disponibili soddisfa insieme i requisiti di provenienza verificabile, supporto ufficiale e riproducibilità. Come previsto dalla condizione 4 dell'autorizzazione M1, la build **non è stata avviata** e le alternative sono presentate al proprietario (§5).
- **Metodo:** sola lettura tramite API pubbliche di quay.io (API REST e Registry v2) e del repository ostree di Fedora. Nessuna immagine è stata scaricata o costruita.

## 1. Requisiti della base (da ADR-0003, ADR-0005, SEC-UPD)

| ID | Requisito |
|---|---|
| B-01 | Fedora Kinoite 45, x86_64 |
| B-02 | Immagine "bootable container" utilizzabile con bootc/rpm-ostree (etichette `containers.bootc=1`, `ostree.bootable=true`) |
| B-03 | Pubblicata da Fedora (non da terzi) |
| B-04 | Provenienza verificabile crittograficamente (firma) |
| B-05 | Fissabile per digest e ancora scaricabile in futuro (riproducibilità della build) |
| B-06 | Canale dichiarato supportato da Fedora |

## 2. Candidate trovate

### 2.1 `quay.io/fedora/fedora-kinoite:45`

| Campo | Valore rilevato |
|---|---|
| Organizzazione | `fedora` su quay.io (pubblica) |
| Tag disponibili per F45 | Solo `45`, `45-x86_64`, `45-aarch64` (tag **mobili**). Gli ultimi tag datati del repository risalgono a luglio 2025 (versioni 41–43) |
| Digest indice multi-architettura (`45`) | `sha256:53027091f3ab31dafa68137d4704ddde4c478a3326747d042b9db348f9722a61` |
| Digest manifest amd64 | `sha256:0e0649d7c3bc07cfd42c2daa0a0b81c3291a09721179f6f0355cbb70618925ee` |
| Ultimo aggiornamento del tag | 2026-11-05 01:00:37 UTC |
| Creazione (config) | 2026-11-05T00:39:01Z |
| Etichette | `containers.bootc=1`, `ostree.bootable=true`, `org.opencontainers.image.version=45.20261105.0`, `ostree.linux=7.2.15-300.fc45.x86_64`, `ostree.commit=7060deaa9bb8…` |
| Dimensione | 65 layer, ≈ 3,34 GB compressi |
| Firma sigstore/cosign | **Assente**: nessun tag `sha256-<digest>.sig` per l'indice né per il manifest amd64 (HTTP 404) |
| Corrispondenza con l'ostree firmato GPG di Fedora | **No**: il commit `7060deaa…` non esiste nel repository `kojipkgs.fedoraproject.org/ostree/repo` (HTTP 404) |

### 2.2 `quay.io/fedora-ostree-desktops/kinoite:45`

| Campo | Valore rilevato |
|---|---|
| Descrizione su quay.io | "Experimental ostree container images. See gitlab.com/fedora/ostree/ci-test for details." |
| Tag | `45` (mobile) e tag datati giornalieri (`45.20261020.0` … ) |
| Digest indice (`45`) | `sha256:117d8e93aaae8e9cf0ca7f6244c602d5780c5908b9dfa6cde17a7193d748d9a8` |
| Digest manifest amd64 | `sha256:7cd7b18bae6c05a9e5765f045b87c4e6fd3be509890fd5b747c8f4d6e0b55647` |
| Etichette | `containers.bootc=1`, `ostree.bootable=true`, versione `45.20261105.0`, kernel `7.2.15-300.fc45.x86_64`, **`quay.expires-after=4w`** |
| Firma cosign | **Presente** (tag `.sig` con annotazioni `dev.cosignproject.cosign/signature` e `dev.sigstore.cosign/bundle`); chiave pubblica pubblicata in `gitlab.com/fedora/ostree/ci-test` (`quay.io-fedora-ostree-desktops.pub`, HTTP 200). **La firma non è stata verificata crittograficamente** (cosign non disponibile nell'ambiente di analisi) |
| Stato dichiarato | Il manutentore del SIG Atomic Desktops: "Those are not official Fedora images" (Fedora Discussion, luglio 2024); "Experimental project… Expect rebase and push --force" (febbraio 2025) |

### 2.3 Riferimento ostree ufficiale (non OCI)

| Campo | Valore rilevato |
|---|---|
| Ref | `fedora/45/x86_64/kinoite` su `kojipkgs.fedoraproject.org/ostree/repo` |
| Commit | `83719586c6fd744488c7bf64eff79c98fda6e8b7ba92151ec18b59c70346b9d8` |
| Versione | `45.20261105.0` |
| Firma | File `.commitmeta` presente (firma GPG di Fedora: **non verificata** in questa analisi) |

## 3. Valutazione rispetto ai requisiti

| Requisito | 2.1 `fedora/fedora-kinoite` | 2.2 `fedora-ostree-desktops/kinoite` | 2.3 ostree ufficiale |
|---|---|---|---|
| B-01 Kinoite 45 x86_64 | Sì | Sì | Sì |
| B-02 Bootable container | Sì | Sì | No (va incapsulato in OCI) |
| B-03 Pubblicata da Fedora | Sì (organizzazione `fedora`) | Progetto del SIG Fedora, dichiarato non ufficiale | Sì |
| B-04 Provenienza verificabile | **No** (nessuna firma) | Sì in principio (cosign), da verificare | Sì in principio (GPG), da verificare |
| B-05 Riproducibilità | **Debole**: solo tag mobili; un digest non più etichettato può essere rimosso dal registry [D] | **Debole**: tag che scadono dopo 4 settimane | Buona: i commit storici restano nel repository [D] |
| B-06 Canale supportato | **Non confermato**: la documentazione Fedora non era consultabile da questo ambiente; secondo le indicazioni del proprietario la transizione alle immagini ufficiali è ancora in corso | No (sperimentale) | Sì (è il canale di aggiornamento delle installazioni Kinoite) |

Contesto storico (fonte secondaria, post del manutentore del SIG, ottobre 2024):
le immagini su `quay.io/fedora` erano "mirrored from the ostree repository" e
sarebbero state sostituite dalle immagini bootable container ufficiali. Le
etichette `containers.bootc=1` e il commit diverso dal ref ostree indicano che
oggi l'immagine 2.1 è costruita in modo nativo come container, ma questo **non**
è confermato da una fonte ufficiale.

## 4. Conclusione

- La candidata **2.1** è la più vicina alla base desiderata (pubblicata da Fedora, aggiornata, bootc), ma **non è firmata** e non ha tag immutabili: viola SEC-UPD-02 solo in parte (si può fissare il digest) e non permette di verificarne la provenienza.
- La candidata **2.2** è firmata ma sperimentale, con tag a scadenza: inadatta come base stabile.
- Il ref ostree **2.3** è firmato e ufficiale, ma richiede un passaggio in più per diventare una base OCI.

Nessuna base viene sostituita automaticamente.

## 5. Alternative concrete per il proprietario

| # | Alternativa | Cosa comporta | Vantaggi | Svantaggi / rischi |
|---|---|---|---|---|
| **A1** | Usare 2.1 `quay.io/fedora/fedora-kinoite` **fissata per digest**, accettando l'assenza di firma solo per il prototipo in VM | `FROM quay.io/fedora/fedora-kinoite@sha256:0e0649d7…`; registrare il digest; copia locale dell'immagine nella cache della CI per ripetere la build | Più semplice; immagine Fedora più recente; percorso più vicino a quello futuro ufficiale | Provenienza non verificabile crittograficamente; il digest può sparire dal registry; non adatta oltre il prototipo |
| **A2** | Usare 2.2 `quay.io/fedora-ostree-desktops/kinoite` con **verifica cosign** della firma, fissata per digest | Verificare la firma con la chiave pubblicata dal SIG prima di ogni build | Provenienza verificabile | Immagini dichiarate non ufficiali e sperimentali; tag a scadenza (4 settimane) |
| **A3** | Costruire la base OCI dal **commit ostree ufficiale firmato GPG** (2.3), verificando la firma con le chiavi Fedora, e incapsularlo in OCI (`rpm-ostree compose container-encapsulate`) [D] | Passaggio aggiuntivo nella CI; chiavi GPG Fedora 45 da ottenere da fonte ufficiale | Base ufficiale e verificabile; commit storici disponibili | Più complessità; da verificare che il risultato sia pienamente compatibile con bootc |
| **A4** | Costruire l'albero da zero con `rpm-ostree compose` dalla configurazione ufficiale Kinoite (repository `workstation-ostree-config`) e RPM Fedora firmati [D] | Composizione completa nella CI | Massimo controllo; ogni RPM verificato con GPG | Molto più lavoro e tempo di build; si discosta dall'opzione C preferita |
| **A5** | **Attendere** la conclusione della transizione alle immagini ufficiali firmate | Nessuna build fino ad allora | Nessun compromesso | M1 bloccata per un tempo non prevedibile |

### Raccomandazione (non vincolante)

**A1 per il solo prototipo in VM, con verifica incrociata e criterio di uscita esplicito**, oppure **A3** se vuoi provenienza verificabile fin da subito:

- A1 è adeguata a un prototipo che gira **solo in VM**, non viene distribuito e non tocca il PC: il rischio di una base non firmata è contenuto. Va registrato come eccezione temporanea a SEC-UPD-01/02 (rischio R-28) e **non** è accettabile per M3 o per qualsiasi immagine destinata al PC reale.
- In ogni caso, prima di M3 serve una base verificabile (A2 con stato ufficiale, A3, A4, o immagini ufficiali firmate quando disponibili).

## 6. Decisione richiesta al proprietario

Scegliere A1, A2, A3, A4 o A5 (eventualmente A1 ora e A3 prima di M3). Fino
alla decisione `image/base.lock` resta in stato `PENDING_OWNER_DECISION` e la CI
rifiuta qualsiasi build dell'immagine.

## Fonti

- quay.io, API pubbliche: `quay.io/api/v1/repository/fedora/fedora-kinoite`, `…/fedora-ostree-desktops/kinoite` e Registry v2 (consultate il 2026-11-05).
- Repository ostree Fedora: `https://kojipkgs.fedoraproject.org/ostree/repo/refs/heads/fedora/45/x86_64/kinoite`.
- Fedora Discussion, "HowTo: Test the Fedora Atomic container images by rebasing" — https://discussion.fedoraproject.org/t/howto-test-the-fedora-atomic-container-images-by-rebasing/124526
- "What's new for Fedora Atomic Desktops in Fedora 41" (siosm, ottobre 2024) — https://planet.kde.org/siosms-blog-2024-10-29-whats-new-for-fedora-atomic-desktops-in-fedora-41/
- Danathar/atomic-image-builder, issue #354 (settembre 2026, fonte di terze parti) — https://github.com/Danathar/atomic-image-builder/issues/354
- Documentazione Fedora (docs.fedoraproject.org): **non consultabile** da questo ambiente (protezione anti-bot).
