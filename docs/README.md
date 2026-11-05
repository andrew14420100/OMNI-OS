# Documentazione tecnica OMNI OS — M0

> Fase attuale: **M1 preliminare — base Linux in macchina virtuale**, autorizzata il 2026-11-05.
> M0 conclusa. Nessuna immagine costruita finora: la base OCI attende la decisione del proprietario.
> Nessuna ISO, nessun installer fisico, nessuna modifica al PC.

| Cartella | Contenuto |
|---|---|
| [`00-specifiche/`](00-specifiche/specifiche-funzionali-v1.0.md) | Specifiche funzionali v1.0 approvate (55 decisioni) — riferimento principale |
| [`01-architettura/`](01-architettura/architettura.md) | Architettura a livelli, interfacce, [tracciabilità delle 55 decisioni](01-architettura/tracciabilita-decisioni.md) |
| [`02-adr/`](02-adr/README.md) | Decisioni tecniche (ADR): base, aggiornamenti e firma, NVIDIA e Secure Boot, release Fedora |
| [`03-sicurezza/`](03-sicurezza/requisiti-sicurezza.md) | Requisiti di sicurezza, [procedura prima installazione](03-sicurezza/procedura-prima-installazione.md) |
| [`04-dipendenze/`](04-dipendenze/catalogo-dipendenze.md) | Catalogo delle dipendenze |
| [`05-licenze/`](05-licenze/analisi-licenze.md) | Licenze, redistribuzione, verifica del marchio |
| [`06-rischi/`](06-rischi/registro-rischi.md) | Registro dei rischi |
| [`07-verifiche/`](07-verifiche/) | Checklist pre-M1, piano benchmark gaming+AI, strategia di test |
| [`08-accettazione/`](08-accettazione/criteri-accettazione.md) | Criteri di accettazione M0–M9 |
| [`09-repository/`](09-repository/struttura-repository.md) | Struttura del repository, flusso Git, inizializzazione |
| [`10-rapporti/`](10-rapporti/rapporto-M0.md) | Rapporti di milestone ([M0](10-rapporti/rapporto-M0.md), [M1](10-rapporti/rapporto-M1.md)) |
| [`11-m1/`](11-m1/verifica-base-oci.md) | M1: [verifica della base OCI](11-m1/verifica-base-oci.md), [percorso di build e test in VM](11-m1/percorso-build-vm.md) |
| [`fonti.md`](fonti.md) | Fonti consultate |

Convenzioni: **[P]** proposta, **[V]** verificato con fonte, **[D]** da verificare.

Inventario M0 (26 file) in `10-rapporti/rapporto-M0.md` §1.
