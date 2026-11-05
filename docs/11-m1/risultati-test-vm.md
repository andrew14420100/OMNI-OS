# M1 — Risultati dei test in macchina virtuale

- **Ambito:** prototipo OMNI OS **solo in VM** (QEMU/KVM su runner GitHub Actions `ubuntu-24.04`). Nessuna installazione fisica, nessuna immagine pubblicata.
- **Base:** `quay.io/fedora/fedora-kinoite@sha256:0e0649d7c3bc07cfd42c2daa0a0b81c3291a09721179f6f0355cbb70618925ee` (Fedora Kinoite 45.20261105.0, kernel 7.2.15-300.fc45) — **eccezione A1: non firmata, solo VM**.
- **Workflow:** `.github/workflows/m1-vm.yml`. Tutti i dati qui sotto provengono dai log delle esecuzioni indicate; nulla è stato dichiarato superato senza un'esecuzione reale.

## 1. Esecuzione di riferimento

| Campo | Valore |
|---|---|
| Esecuzione completa superata | [42099981099](https://github.com/andrew14420100/OMNI-OS/actions/runs/42099981099), commit `2bae45f`, 2026-11-05 20:05–20:36 UTC (31 min) |
| Esito | **Tutti i passi P1–P9 e P6b superati** |
| Esecuzioni precedenti usate per §3 | [42080528120](https://github.com/andrew14420100/OMNI-OS/actions/runs/42080528120) (`96560c1`): P1–P8 superati; P1–P8 superati anche in 42085279880 e 42094583863 (risultati ripetuti in 4 esecuzioni) |
| Runner | 4 CPU, 15 GB RAM, KVM disponibile, 99 GB liberi su `/`, podman 4.9.3, QEMU 8.2.2 |

## 2. Risultati per passo

| Passo | Verifica | Esito | Dati rilevati |
|---|---|---|---|
| P1 | Download della base per digest e confronto | **Superato** | Digest scaricato = digest approvato; tag `45` punta ancora allo stesso manifest amd64; etichette `45.20261105.0`, `containers.bootc=1`, kernel `7.2.15-300.fc45.x86_64` |
| P2 | Build dell'immagine OMNI | **Superato** | `bootc container lint` nella build: 14 controlli superati, 1 saltato |
| P3 | `bootc container lint` esplicito | **Superato** | 14 superati, 1 saltato |
| P4 | Contenuto dell'immagine | **Superato** | `build-info` 0.1.0-m1-dev; Fedora 45, variante kinoite; plasma-workspace 6.8.2, kwin 6.8.2, NetworkManager 1.58.1; gestore di accesso **plasmalogin** (non SDDM) |
| P5 | Disco di prova con `bootc install to-disk --via-loopback` | **Superato** | Disco raw 30 GB (7,1 GB occupati), bootloader GRUB via bootupd, filesystem XFS |
| P6 | Avvio UEFI e controlli nel sistema | **Superato** | SSH dopo 22 s; avvio UEFI; `/run/ostree-booted`; systemd `degraded` **solo** per `mcelog.service` (atteso in VM); `graphical.target` attivo; `plasmalogin` attivo; NetworkManager attivo con IPv4; `bootc status` e `rpm-ostree status` mostrano l'immagine OMNI 0.1.0-m1-dev |
| P7 | Schermata via monitor QMP | **Superato** | PNG di 565 KB catturato (artefatto di diagnosi, 3 giorni). **Contenuto non verificato automaticamente**: il test prova che lo schermo è catturabile, non cosa mostra |
| P6b | Avvio con Secure Boot emulato (OVMF, chiavi Microsoft) | **Superato** | Variabile EFI `SecureBoot` = 1 nella VM; kernel 7.2.15 avviato; SSH dopo 27 s |
| P8 bootc | Aggiornamento, rollback, errori | **Superato** | Vedi §3 |
| P8 rpm-ostree | Aggiornamento, rollback, errori | **Superato** | Vedi §3 |
| P9 | Firme con chiavi effimere | **Superato** (42099981099) | Vedi §3.1 |

## 3. P8 — confronto bootc / rpm-ostree

Test identici, ciascuno su una copia **mai avviata** dello stesso disco. N = 0.1.0-m1-dev, N+1 = 0.1.1-m1-dev (stessa base, solo versione diversa), trasferita nella VM come archivio OCI locale.

| Passo | bootc | rpm-ostree |
|---|---|---|
| E1 — archivio corrotto | Rifiutato; deployment invariati | Rifiutato; deployment invariati |
| E2 — aggiornamento preparato, poi spegnimento forzato della VM | Riavvio riuscito su N (aggiornamento non applicato), sistema coerente | Riavvio riuscito su N, sistema coerente |
| U1 — aggiornamento a N+1 e riavvio | Versione 0.1.1-m1-dev | Versione 0.1.1-m1-dev |
| R1 — rollback e riavvio | Versione 0.1.0-m1-dev, gestore di accesso attivo | Versione 0.1.0-m1-dev, gestore di accesso attivo |
| Durata totale del test | 253 s | 211 s |
| Preparazione E2 | 74 s | 55 s |
| Comando di aggiornamento | `bootc switch --transport oci-archive …` | `rpm-ostree rebase ostree-unverified-image:oci-archive:…` |
| Comando di rollback | `bootc rollback` | `rpm-ostree rollback` |

**Osservazioni (non ancora una raccomandazione definitiva):**

- Nei casi provati i due gestori si comportano **allo stesso modo**: nessuna differenza funzionale osservata.
- rpm-ostree è risultato un po' più rapido in questa singola esecuzione (211 s contro 253 s), ma una sola misura non basta per concludere; i tempi dipendono anche dal runner.
- Entrambi vedono lo stesso deployment: dopo l'installazione `rpm-ostree status` mostra l'immagine come `ostree-unverified-registry:localhost/omni-os:m1-ci`, coerente con `bootc status`.
- Con le firme (P9) entrambi rifiutano immagini non firmate o firmate con chiavi sconosciute e accettano quelle firmate correttamente; cambia il modo di richiedere la verifica (vedi §3.1).
- Non provati: pacchetti stratificati sul client, aggiornamenti automatici con timer, persistenza dell'obbligo di firma negli aggiornamenti successivi.

### Raccomandazione provvisoria (richiesta dal proprietario, non è una decisione)

**rpm-ostree come gestore primario per i passi successivi, mantenendo la compatibilità con bootc**, per questi motivi osservati:

1. nessuna differenza funzionale nei test di aggiornamento, rollback ed errori;
2. con rpm-ostree l'obbligo di firma è scritto nel riferimento dell'immagine (`ostree-image-signed:`), quindi non dipende dal ricordarsi un'opzione a ogni comando; con bootc va richiesto esplicitamente e la sua persistenza non è ancora verificata;
3. rpm-ostree espone l'API D-Bus prevista per OMNI Update Center (ADR-0003).

Prima di una decisione definitiva propongo tre test aggiuntivi: (T1) `bootc upgrade` dopo uno switch con `--enforce-container-sigpolicy`, per verificare se la firma resta obbligatoria; (T2) aggiornamento automatico con i timer dei due gestori; (T3) ripetizione delle misure di tempo su più esecuzioni.

### 3.1 P9 — verifica delle firme (esecuzione 42099981099)

Chiavi cosign **effimere**, generate e distrutte nel job; firma senza registro di trasparenza pubblico (`--tlog-upload=false`); registro OCI locale in ascolto solo su `127.0.0.1:5000` del runner, raggiunto dalla VM come `10.0.2.2:5000`. Nella VM: policy `default: reject` e `sigstoreSigned` con la chiave pubblica di prova per `10.0.2.2:5000/omni-os`.

| Passo | Esito |
|---|---|
| Registro locale attivo (solo loopback) | OK |
| Immagine firmata (0.1.1) e non firmata (0.1.2) caricate, digest diversi | OK |
| Firma con chiave effimera, identità `10.0.2.2:5000/omni-os` | OK |
| Verifica sull'host: firmata valida / non firmata rifiutata | OK / OK |
| S1 bootc — immagine **non firmata** | **Rifiutata** ("A signature was required, but no signature exists") |
| S2 rpm-ostree — immagine **non firmata** | **Rifiutata** |
| S3 bootc — firma con **chiave non riconosciuta** | **Rifiutata** ("invalid signature when validating ASN.1 encoded signature") |
| S4 rpm-ostree — firma con **chiave non riconosciuta** | **Rifiutata** |
| S5 rpm-ostree — immagine firmata con la chiave corretta | **Accettata** (aggiornamento preparato) |
| S6 bootc — immagine firmata con la chiave corretta | **Accettata**, riavvio, sistema avviato su **0.1.1-m1-dev** |
| Chiavi effimere distrutte | OK |

Differenza rilevata fra i gestori: con **bootc** la verifica della policy va richiesta esplicitamente (`bootc switch --enforce-container-sigpolicy`); con **rpm-ostree** è espressa nel riferimento stesso (`ostree-image-signed:docker://…`). **Non è stato verificato** se, dopo lo switch, i successivi `bootc upgrade` continuino a imporre la verifica.

## 4. Problemi incontrati e correzioni (in ordine)

| # | Esecuzione | Problema | Causa | Correzione |
|---|---|---|---|---|
| 1 | 42074869664 | P4 fallito: `sddm` non installato | **Ipotesi errata del test**: Kinoite 45 usa `plasmalogin` | Il test legge `display-manager.service` invece di presumere SDDM |
| 2 | 42076095926 | P5 fallito: `bootc install` "no such object" | `bootc install` esegue il podman dell'host con la configurazione predefinita: lo storage personalizzato usato nel workflow non era visibile | Storage predefinito `/var/lib/containers` (invocazione documentata di bootc) |
| 3 | 42077152935 | P2 fallito: immagine "non trovata" per nome subito dopo la build | **Non determinata**. Nell'esecuzione successiva, con passi diagnostici e ri-etichettatura di riserva, P2 è riuscito | P2 registra l'ID con `--iidfile` e verifica nome e ID; resta da capire la causa |
| 4 | 42078680056 | P6 fallito: systemd in `starting` | Il test controllava troppo presto | Attesa con `systemctl is-system-running --wait`; `degraded` accettato solo per guasti attesi in VM elencati e motivati |
| 5 | 42080528120 | P9 fallito: registro locale non attivo | Da determinare (output del servizio non registrato) | Diagnostica aggiunta; esecuzione ripetuta |
| 6 | 42085279880 | P9 fallito di nuovo (P1–P8 di nuovo tutti superati: risultati ripetibili) | Il pacchetto Ubuntu `docker-registry` abilita per default l'autenticazione `htpasswd`: ogni richiesta riceveva `401`. Il servizio era attivo e in ascolto **solo su 127.0.0.1:5000** (verificato con `ss`) | Configurazione minima scritta per intero: nessuna autenticazione, solo loopback, dati in cartella temporanea |
| 7 | 42094016024 | P1 fallito: download interrotto | Guasto di rete esterno: il CDN di quay.io ha chiuso la connessione durante il download di un blob (`unexpected EOF`). Non legato al codice OMNI | P1 ritenta fino a 3 volte; il controllo del digest resta obbligatorio |
| 8 | 42094583863 | P9: S1–S4 superati (rifiuto di immagini non firmate e di chiavi sconosciute con entrambi i gestori), S5–S6 falliti: immagine firmata correttamente rifiutata con `Signature for identity "127.0.0.1:5000/omni-os" is not accepted` | **Errore del test**: con `remapIdentity` il nome rimappato mantiene il tag `:signed`, mentre la firma cosign contiene solo il repository; la corrispondenza esatta fallisce | Firma con `--sign-container-identity 10.0.2.2:5000/omni-os` e policy `matchRepository` |
| 9 | 42099981099 | — | — | **Tutti i passi superati** |

## 5. Cosa NON è stato verificato

- Contenuto visivo della schermata di accesso (P7 prova solo la cattura).
- Accesso utente a una sessione Plasma (nessun utente grafico creato sul disco di prova).
- Driver NVIDIA (assenti in VM, AC-M1-10), hardware reale, HDR/VRR.
- Aggiornamenti da registry remoto e pacchetti stratificati sul client.
- Ripetibilità statistica dei tempi (P8 eseguito con successo in 4 esecuzioni, ma i tempi riportati sono di una sola).
- Causa dell'anomalia di P2 (immagine non trovata per nome in una esecuzione): non riprodotta né spiegata.
- Persistenza dell'obbligo di firma con bootc dopo lo switch (T1).
