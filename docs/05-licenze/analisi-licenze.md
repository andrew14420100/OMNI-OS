# Analisi licenze, redistribuzione e marchi

- **Stato:** analisi preliminare M0. **Non costituisce consulenza legale.** Prima di qualsiasi distribuzione pubblica è consigliata una verifica da parte di un professionista.
- **Riferimenti:** spec §7 (rischio "Licenze e redistribuzione"), Regola 9 e 12; [`../04-dipendenze/catalogo-dipendenze.md`](../04-dipendenze/catalogo-dipendenze.md).

## 1. Scenari di distribuzione

Gli obblighi dipendono da come viene distribuito OMNI OS:

| Scenario | Descrizione | Obblighi principali |
|---|---|---|
| D0 — Uso personale | Immagine usata solo sul PC del proprietario | Minimi; le licenze copyleft si attivano con la distribuzione |
| D1 — Repository pubblico senza immagini | Solo codice sorgente e Containerfile | Licenza del codice OMNI; nessuna redistribuzione di binari di terzi |
| D2 — Immagine pubblica nel registry | Chiunque può scaricare l'immagine | Obblighi GPL/LGPL (disponibilità del sorgente corrispondente), licenze proprietarie NVIDIA, codec, **marchi** |
| D3 — ISO di installazione pubblica | Come D2 + supporti | Come D2 |

**Proposta:** restare in D0/D1 fino a M9; valutare D2/D3 solo dopo completamento di questa analisi e della verifica del marchio.

## 2. Categorie di licenza e implicazioni

| Categoria | Esempi | Implicazione per OMNI |
|---|---|---|
| Copyleft forte (GPL-2.0/3.0) | Kernel, GRUB, molti strumenti KDE | Se si distribuisce il binario: fornire o rendere disponibile il sorgente corrispondente. Riutilizzare i sorgenti Fedora (SRPM) facilita l'adempimento |
| Copyleft debole (LGPL, MPL-2.0) | Qt, systemd, Firefox, LibreOffice | Il codice OMNI può collegarsi a queste librerie con licenza diversa, rispettando le condizioni (collegamento dinamico, modifiche ai file MPL pubblicate) |
| Permissive (MIT, BSD, Apache-2.0) | llama.cpp, Podman, tooling Universal Blue | Conservare avvisi di copyright; Apache-2.0: indicare le modifiche e conservare il file NOTICE |
| Proprietaria redistribuibile con condizioni | Driver NVIDIA user-space, firmware GSP | Verificare la licenza NVIDIA sulla redistribuzione in immagini derivate; RPM Fusion nonfree li distribuisce, ma i termini vanno letti per il caso OMNI |
| Proprietaria non redistribuibile | Steam client (si installa dall'utente, Flathub) | Non includere nell'immagine; installazione su richiesta dell'utente |
| Brevetti multimediali | Alcuni codec (es. H.264/H.265 in alcune giurisdizioni) | Fedora non li include per questo motivo; inclusione via RPM Fusion da valutare per D2/D3 |
| Licenze dei modelli AI | Pesi LLM, modelli vocali | Ogni modello ha una licenza propria, spesso con limiti d'uso: **non includere pesi nell'immagine**; scaricamento su scelta dell'utente con licenza mostrata |

## 3. Licenza del codice OMNI

**Decisione aperta** (richiede il proprietario). Opzioni:

| Opzione | Effetto |
|---|---|
| GPL-3.0-or-later | Le modifiche distribuite restano libere; coerente con molti componenti KDE |
| Apache-2.0 | Permissiva, con concessione esplicita di brevetti; facilita il riuso di codice Universal Blue |
| MPL-2.0 | Copyleft a livello di file |
| Nessuna licenza (riservato) | Tutti i diritti riservati; impedisce contributi esterni chiari |

Per la documentazione si può valutare CC BY-SA 4.0 o la stessa licenza del codice.

## 4. Marchi di terzi

| Marchio | Vincolo da verificare |
|---|---|
| Fedora | Le linee guida sul marchio Fedora limitano l'uso del nome e dei loghi per derivati modificati; solitamente si sostituiscono i pacchetti di logo/branding (es. `fedora-logos` con alternative generiche) e non si presenta il derivato come "Fedora". Da verificare sulla policy ufficiale |
| KDE, Plasma | Uso descrittivo ("basato su KDE Plasma") generalmente accettato; verificare le linee guida KDE |
| NVIDIA, GeForce, RTX | Solo uso descrittivo di compatibilità |
| Universal Blue, Aurora, Bazzite, Bluefin | Non usare nel nome del prodotto |
| Windows, Microsoft | Solo uso descrittivo (es. "compatibile con applicazioni Windows tramite Wine/Proton") |

## 5. Verifica del marchio "OMNI OS" — requisito obbligatorio

> **REQ-TM-01:** prima di **qualsiasi distribuzione pubblica** (scenari D2/D3,
> e anche prima di pubblicare il repository con il nome come prodotto) deve
> essere completata e approvata dal proprietario la verifica del marchio
> "OMNI OS" e dei nomi dei moduli "OMNI …".

Motivazione: "Omni" è un termine molto diffuso nel software e nell'elettronica;
esiste il rischio di conflitto con marchi registrati o prodotti esistenti con
nomi simili.

### Checklist di verifica (da eseguire, non eseguita in M0)

| # | Verifica | Strumento | Esito |
|---|---|---|---|
| TM-01 | Ricerca marchi UE | EUIPO (eSearch plus), TMview | Da fare |
| TM-02 | Ricerca marchi Italia | UIBM | Da fare |
| TM-03 | Ricerca marchi internazionali | WIPO Global Brand Database | Da fare |
| TM-04 | Ricerca marchi USA (se distribuzione globale) | USPTO | Da fare |
| TM-05 | Classi di Nizza rilevanti: 9 (software), 42 (servizi software) | — | Da fare |
| TM-06 | Prodotti/progetti esistenti chiamati "Omni OS", "OmniOS" o simili (sistemi operativi, firmware, distribuzioni) | Ricerca web, GitHub, DistroWatch | Da fare |
| TM-07 | Disponibilità dei nomi: dominio, organizzazione GitHub, namespace del registry | — | Da fare |
| TM-08 | Valutazione di un professionista se emergono somiglianze | — | Da fare |
| TM-09 | Decisione: mantenere il nome, registrarlo o rinominare | Proprietario | Da fare |

Fino al completamento: il nome "OMNI OS" è un **nome di lavoro**; i nomi
tecnici (D-Bus `org.omnios.*`, pacchetti `omni-*`) sono concentrati in pochi
punti per facilitare un eventuale cambio.

## 6. Azioni per milestone

| Milestone | Azione |
|---|---|
| M1 | SBOM automatico della prima immagine; elenco licenze generato dai metadati RPM |
| M3 | Lettura dei termini di licenza del driver NVIDIA per la redistribuzione |
| M6 | Registro delle licenze dei modelli AI proposti |
| Prima di D2/D3 | REQ-TM-01 completato; verifica obblighi GPL (sorgenti); branding Fedora sostituito; revisione legale consigliata |
