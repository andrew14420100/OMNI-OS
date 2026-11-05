# ADR-0002 — Base: Fedora Kinoite ufficiale vs Universal Blue

- **Stato:** Proposto — **la scelta definitiva spetta al proprietario** (richiesta 1 dell'autorizzazione M0)
- **Data:** 2026-11-05
- **Decisioni approvate correlate:** 50 (Base Linux: Fedora Kinoite), 2, 15, 32, 51
- **Requisiti correlati:** RF-04, RF-08, Regola operativa 9, 12

> Nota di coerenza con la decisione 50: tutte le opzioni restano basate su
> Fedora Kinoite. Universal Blue **non** è una distribuzione diversa: produce
> immagini derivate da Kinoite. La scelta riguarda *da quale immagine partire
> e chi mantiene i livelli aggiuntivi* (driver, codec, strumenti), non la
> sostituzione di Kinoite.

## Contesto

OMNI OS deve essere costruito come immagine personalizzata (vedi ADR-0003). La
RTX 5070 Ti richiede i moduli kernel NVIDIA open (ADR-0004), che **non** sono
inclusi in Fedora per ragioni di licenza e vanno aggiunti da un repository
esterno (RPM Fusion) o da un'immagine che li includa già.

### Fatti verificati

| Fatto | Fonte |
|---|---|
| Il repository `ublue-os/main` produce (da settembre 2025) solo le immagini `base`, `kinoite` e `silverblue`; sway, budgie e cosmic sono state rimosse | README `github.com/ublue-os/main` (consultato 2026-11-05) |
| Universal Blue dichiara di ridurre il supporto alle immagini intermedie non usate dai propri prodotti finali (Aurora, Bazzite, Bluefin) | README `ublue-os/main` |
| Licenza del codice di build di `ublue-os/main` e `ublue-os/aurora`: Apache-2.0; le immagini sono firmate con cosign (`cosign.pub` nel repository) | GitHub `ublue-os/main`, `ublue-os/aurora` |
| `ublue-os/akmods` fornisce kmod precompilati, incluso il gruppo `nvidia-open`, e il pacchetto `ublue-os-akmods-addons` con la chiave di firma | GitHub `ublue-os/akmods` |
| Aurora (derivato KDE) ha Secure Boot supportato con chiave propria: al primo avvio si registra la chiave MOK con password `universalblue` | README `ublue-os/aurora` |
| Un utente ha segnalato che l'installer registrava una chiave diversa da quella usata per firmare il modulo NVIDIA, risolto importando a mano `akmods-ublue.der` | Forum Universal Blue, "Secure Boot Notice" (fonte comunitaria, non ufficiale) |
| RPM Fusion: serie driver 595+ predefinita su Fedora 44 e successive; `kmod-nvidia` usa per default un modulo open precompilato; su sistemi OSTree serve un pacchetto chiave separato per la firma | `rpmfusion.org/Howto/NVIDIA` |

### Fatti da verificare prima di M1

- Esistenza e tag delle immagini OCI ufficiali Fedora Kinoite 45 sul registry Fedora (la documentazione Fedora non era raggiungibile dall'ambiente di analisi: protezione anti-bot).
- **Solo per l'opzione B** (o per il banco di prova in M3): disponibilità delle immagini Universal Blue per Fedora 45 e dei kmod `nvidia-open` per il kernel di Fedora 45; politica attuale di Universal Blue sulle varianti NVIDIA delle immagini intermedie (rischio di rimozione). Verifica F45-06a in ADR-0005.
- **Per l'opzione C**: l'opzione non dipende dalla disponibilità di immagini o kmod Universal Blue; va verificato solo che il codice e le tecniche riusati siano compatibili con Fedora 45 e con la licenza Apache-2.0. Verifica F45-06b in ADR-0005.

## Opzioni considerate

### Opzione A — Fedora Kinoite ufficiale, tutto costruito da OMNI

Immagine `FROM` Kinoite ufficiale; i kmod NVIDIA open vengono compilati nella
CI OMNI (pacchetti RPM Fusion) e firmati con una chiave MOK di proprietà del
progetto.

| Aspetto | Valutazione |
|---|---|
| Vantaggi | Massimo controllo e trasparenza; catena di fiducia minima (Fedora + RPM Fusion + OMNI); aderenza letterale alla decisione 50; nessuna dipendenza dalle scelte di prodotto di un terzo |
| Svantaggi | Più lavoro iniziale: build dei kmod nella CI, gestione della chiave di firma, codec multimediali da aggiungere; ogni rottura kernel/driver va gestita da OMNI |
| Dipendenze | Registry Fedora, repository Fedora, RPM Fusion (free e nonfree), servizio CI (es. GitHub Actions), registry di pubblicazione |
| Licenze | Pacchetti Fedora: licenze libere varie. Driver NVIDIA user-space: proprietario, redistribuzione secondo licenza NVIDIA (da analizzare, vedi `../05-licenze/`). Marchi Fedora: un derivato modificato deve rimuovere/sostituire il branding Fedora (da verificare sulle linee guida del marchio) |
| Manutenzione | Alta per il progetto: monitorare aggiornamenti kernel e driver a ogni build; rischio di build rotte quando il kernel avanza prima del driver |

### Opzione B — Universal Blue come base diretta

Immagine `FROM ghcr.io/ublue-os/kinoite-...` (variante con NVIDIA open se
disponibile) oppure Aurora/Bazzite.

| Aspetto | Valutazione |
|---|---|
| Vantaggi | Driver NVIDIA open già integrati e firmati; codec, udev rules e utilità già presenti; CI matura; tempo di arrivo a M1/M3 molto ridotto; comunità numerosa che individua i problemi presto |
| Svantaggi | Fiducia in una chiave Secure Boot e in un'infrastruttura di terzi; le immagini intermedie possono essere ridotte o rimosse (dichiarato dal progetto); scelte di prodotto (pacchetti, default) non controllate da OMNI; Aurora/Bazzite aggiungono molto software da rimuovere o mantenere |
| Dipendenze | Tutte quelle dell'opzione A **più** GitHub/ghcr di Universal Blue, chiave akmods Universal Blue, loro calendario di build |
| Licenze | Codice di build Apache-2.0 (compatibile). Le immagini contengono codec e componenti di terze parti: la redistribuzione di un'immagine derivata eredita i relativi obblighi (da verificare pacchetto per pacchetto). Marchi Universal Blue/Aurora/Bazzite da non usare nel nome del prodotto |
| Manutenzione | Bassa nel breve periodo; rischio strategico se Universal Blue cambia struttura (già avvenuto nel 2025) |

### Opzione C — Ibrida: Kinoite ufficiale + tecniche Universal Blue (riferimento, non dipendenza)

Base `FROM` Kinoite ufficiale come A; per i kmod NVIDIA si riutilizzano, dove
utile, script e metodi open source di `ublue-os/akmods` (Apache-2.0, con
attribuzione) ma con **chiave di firma OMNI** e build nella CI OMNI.
Transitoriamente, in M1 (solo VM, nessuna GPU NVIDIA reale), il problema
NVIDIA non si pone ancora.

| Aspetto | Valutazione |
|---|---|
| Vantaggi | Catena di fiducia controllata come A; tempo di sviluppo ridotto riusando soluzioni già collaudate; nessuna dipendenza operativa dalle immagini di terzi |
| Svantaggi | Bisogna comunque mantenere la build dei kmod; serve seguire le modifiche a monte manualmente |
| Dipendenze | Come A; Universal Blue solo come riferimento di codice |
| Licenze | Apache-2.0 richiede conservazione delle note di copyright/licenza e indicazione delle modifiche per i file riusati |
| Manutenzione | Media |

## Confronto sintetico

| Criterio | A — Kinoite puro | B — Universal Blue | C — Ibrida |
|---|---|---|---|
| Aderenza alla decisione 50 | Piena | Piena (derivato Kinoite) | Piena |
| Controllo catena di fiducia Secure Boot | OMNI | Universal Blue | OMNI |
| Sforzo iniziale | Alto | Basso | Medio |
| Sforzo di manutenzione | Alto | Basso (ma rischio strategico) | Medio |
| Rischio dipendenza da terzi | Basso | Alto | Basso |
| Tempo per M3 (hardware reale) | Più lungo | Più breve | Intermedio |
| Coerenza con "nessun servizio a pagamento obbligatorio" | Sì | Sì | Sì |

## Proposta (provvisoria, non vincolante)

Raccomando l'**opzione C** come direzione di lavoro, per queste ragioni:

1. mantiene la chiave Secure Boot sotto il controllo del proprietario, coerente con il principio "Controllo" e con la sicurezza;
2. evita la dipendenza dalle immagini intermedie Universal Blue, che il progetto stesso dichiara di ridurre;
3. permette di riusare lavoro esistente senza riscritture inutili (spec §3.5).

**Alternativa ragionevole:** usare l'opzione B **solo come banco di prova** in
M3, per separare i problemi hardware dai problemi della nostra build (se una
immagine Universal Blue con NVIDIA open funziona sul PC e la nostra no, il
difetto è nella nostra build). Questo uso non implica adottarla come base.

## Conseguenze

- C richiede la gestione di una chiave di firma dei moduli (vedi ADR-0004, rischio R-07).
- C richiede una pipeline CI che compili i kmod per ogni kernel (rischio R-04).

## Verifiche richieste (prima di M1 / in M1)

1. Confermare le immagini ufficiali Kinoite 45 sul registry Fedora.
2. Build di prova della sola immagine base (senza NVIDIA) in M1 — **richiede autorizzazione M1**.
3. Prima di M3: compilazione kmod `nvidia-open` per il kernel Fedora 45 nella CI.

## Decisione del proprietario

_In attesa. Opzioni: A, B, C, oppure B come banco di prova + C come base. Nessuna scelta definitiva: la decisione resta aperta fino alla revisione della documentazione._
