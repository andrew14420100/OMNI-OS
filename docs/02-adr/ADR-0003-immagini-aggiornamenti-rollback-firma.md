# ADR-0003 — bootc, rpm-ostree, aggiornamenti, rollback e firma delle immagini

- **Stato:** Proposto
- **Data:** 2026-11-05
- **Decisioni approvate correlate:** 15 (Update Center), 47 (Recovery), 50, 54
- **Requisiti correlati:** RF-04, RNF "aggiornamenti riproducibili e verificabili"

## Contesto

Fedora Kinoite è un sistema *atomico*: il sistema operativo (`/usr`) è un
albero immutabile gestito da **ostree**; ogni aggiornamento crea un nuovo
*deployment* e il precedente resta disponibile nel menu di avvio. Oggi lo stesso
albero può essere distribuito come **immagine container OCI** ("bootable
container"). Esistono due client che gestiscono questi deployment.

> Le pagine di documentazione Fedora (docs.fedoraproject.org, forge.fedoraproject.org)
> non erano raggiungibili dall'ambiente di analisi (protezione anti-bot). Le
> affermazioni marcate **[D]** vanno confermate sulla documentazione ufficiale
> prima di M1.

## Analisi separata

### 1. rpm-ostree

| Aspetto | Descrizione |
|---|---|
| Ruolo | Client storico di Fedora Atomic: aggiorna, effettua rebase, gestisce layering di RPM sul client, argomenti kernel |
| Sorgenti supportate | Repository ostree classici e immagini container (`ostree-unverified-registry:`, `ostree-image-signed:docker://...`) |
| Rollback | `rpm-ostree rollback` imposta il deployment precedente come predefinito; in alternativa scelta dal menu di avvio |
| Automazione | Timer `rpm-ostreed-automatic` con politiche (`none`, `check`, `stage`) [D] |
| API | Demone `rpm-ostreed` con API D-Bus — utile per `omni-updated` |
| Punti deboli | Il layering lato client rende ogni macchina diversa dall'immagine di riferimento (meno riproducibile); aggiornamenti più lenti se ci sono pacchetti stratificati |

### 2. bootc

| Aspetto | Descrizione |
|---|---|
| Ruolo | Client "container-native": aggiornamenti transazionali in-place usando immagini OCI come formato di trasporto. CLI e API dichiarate stabili; backend predefinito ostree; backend composefs richiesto per immagini "sealed" (fonte: bootc.dev) |
| Comandi | `bootc status`, `bootc upgrade`, `bootc switch <immagine>`, `bootc rollback` [D: sintassi da confermare sulla versione inclusa in F45] |
| Verifica firme | Usa la configurazione standard `containers-policy.json` / `registries.d` (sigstore) [D] |
| Automazione | Timer `bootc-fetch-apply-updates` [D] |
| Punti deboli | Sulle Atomic Desktops il supporto è più recente di rpm-ostree; incompatibilità o limitazioni con i pacchetti stratificati lato client [D]; meno integrazione con gli strumenti desktop (es. Discover) [D] |

### 3. Rapporto fra i due

Entrambi operano sugli stessi deployment ostree della macchina. Un'immagine
costruita come bootable container può essere gestita da entrambi. La scelta
riguarda **quale client usa OMNI Update Center** e **se consentire il layering
lato client**.

### 4. Aggiornamenti

Modello proposto: **tutto nell'immagine, niente layering lato client** in produzione.

```
Containerfile (repo Git)
    │  CI: build riproducibile (versioni base fissate per digest)
    ▼
Immagine OCI  ──► test automatici in VM (boot, login, rete, rollback)
    │
    ▼  firma cosign + SBOM + attestazione di provenienza
Registry (canali: :testing, :stable, + tag immutabili per data/versione)
    │
    ▼  client sul PC verifica la firma (policy sigstoreSigned)
Nuovo deployment ostree ─► riavvio ─► (se problemi) rollback
```

- **Canali** (Regola 15: separazione sperimentale/test/stabile): `:dev` (solo VM), `:testing`, `:stable`. Un'immagine passa a `:stable` solo dopo i test di accettazione.
- **Tag immutabili** (es. `45.20261201.0`): permettono di tornare a qualsiasi versione pubblicata, non solo all'ultima precedente.
- **Applicazioni utente** separate dal sistema: Flatpak, aggiornate indipendentemente.
- **Ambienti di sviluppo**: Toolbx, mai layering sul sistema.

### 5. Rollback

| Livello | Meccanismo | Quando |
|---|---|---|
| R1 — immediato | Deployment precedente nel menu di avvio / `rpm-ostree rollback` / `bootc rollback` | Aggiornamento che non avvia o regressione evidente |
| R2 — fissato | `ostree admin pin` su un deployment noto come buono, che non viene rimosso dagli aggiornamenti [D] | Prima di ogni aggiornamento importante (es. cambio release Fedora) |
| R3 — remoto | Rebase/switch a un tag immutabile precedente nel registry | Regressione scoperta dopo più aggiornamenti |
| R4 — recupero | Supporto USB OMNI Recovery / live Fedora: accesso al disco cifrato, ripristino del deployment, backup | Sistema che non avvia nessun deployment |

**Limite importante:** il rollback ostree riguarda `/usr` (il sistema). `/etc`
viene unito a tre vie e `/var` e `/home` **non** vengono ripristinati. Per i
dati serve il backup (Storage Center, decisione 26). Questo limite va mostrato
all'utente nell'Update Center.

### 6. Firma delle immagini

| Opzione | Descrizione | Valutazione |
|---|---|---|
| F1 — cosign con chiave | Chiave privata OMNI nei segreti della CI; chiave pubblica inclusa nell'immagine in `/etc/pki/containers/` e richiesta da `policy.json` | **Proposta**: semplice, funziona offline sul client, usata da Universal Blue |
| F2 — cosign "keyless" (Fulcio/Rekor) | Firma legata all'identità OIDC della CI, registro pubblico di trasparenza | Valutare dopo; dipende da servizi pubblici sigstore per la verifica [D] |
| F3 — nessuna firma (`ostree-unverified-registry`) | Solo per sviluppo in VM | Vietata in `:testing` e `:stable` |

Elementi aggiuntivi proposti:

- **Pin per digest** dell'immagine base Fedora nel Containerfile, aggiornato da un processo controllato (riproducibilità).
- **SBOM** (es. formato SPDX) generato a ogni build: utile anche per l'analisi licenze.
- **Rotazione e revoca della chiave**: vedi `../03-sicurezza/requisiti-sicurezza.md` §5.1 (SEC-KEY). L'immagine può contenere due chiavi pubbliche durante la transizione [D: supporto a più chiavi nella policy da verificare sulla versione di containers/image inclusa in F45].

> **Separazione delle firme.** La firma cosign riguarda **solo l'immagine di
> sistema** (verificata da rpm-ostree/bootc al momento dell'aggiornamento). Non
> ha alcun effetto su Secure Boot né sul caricamento dei moduli kernel: quella è
> la firma **MOK** trattata in ADR-0004. Sono due chiavi distinte, con custodia,
> rotazione e revoca distinte (SEC-KEY-01).
- **Bootstrap della fiducia:** la prima installazione deve avvenire da un supporto costruito dall'immagine firmata, che contiene già policy e chiave, così da evitare il passaggio iniziale "non verificato" usato da alcuni progetti.

## Proposta

1. Formato: **bootable container OCI** costruito da `Containerfile`.
2. Client: **rpm-ostree come client primario in M1** (maturo sulle Atomic Desktops, API D-Bus per l'Update Center); **bootc valutato in parallelo in M1** con gli stessi test. Il divieto di layering lato client mantiene aperta la migrazione a bootc.
3. Firma: **cosign con chiave OMNI (F1)**, policy che rifiuta immagini non firmate.
4. Canali `:dev` / `:testing` / `:stable` + tag immutabili.
5. Rollback a quattro livelli (R1–R4) con prove in M1 (R1–R3) e M2 (R4).
6. Produzione dei supporti di installazione (in M1/M2, non ora): strumenti Fedora image-builder / bootc-image-builder [D].

## Conseguenze

- Serve un registry pubblico o privato (es. GHCR, gratuito per immagini pubbliche): un registry privato richiede credenziali sul client.
- Serve custodire la chiave cosign (rischio R-07).

## Verifiche richieste in M1

- Upgrade da tag N a N+1 e rollback R1, R2, R3 in VM.
- Rifiuto di un'immagine non firmata o firmata con chiave errata.
- Ricostruzione della stessa immagine da commit Git e confronto contenuto (riproducibilità funzionale).
- Confronto rpm-ostree vs bootc su: upgrade, rollback, rifiuto firma, tempi.

## Decisione del proprietario

_In attesa. Restano aperte: client di aggiornamento (rpm-ostree/bootc) e metodo di firma (F1/F2)._
