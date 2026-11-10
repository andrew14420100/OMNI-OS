# ADR-0011 — Dipendenze di terze parti e licenza del codice OMNI

- **Stato:** Proposto — richiede decisione
- **Data:** 2026-11-10
- **Decisioni approvate correlate:** 1, 54

## Contesto

L'autonomia riguarda il sistema finale, non gli strumenti. Restano due domande:
1. quali librerie esterne possono entrare nel codice **eseguito** dal sistema;
2. con quale licenza il proprietario pubblica il codice OMNI.

## Opzioni considerate (dipendenze)

1. **Zero dipendenze** nel codice eseguito: tutto scritto per OMNI.
2. **Registro approvato:** solo crate con licenze permissive (MIT, Apache-2.0, BSD,
   0BSD, Zlib; MPL-2.0 a livello di file), nessuna libreria GPL/LGPL nel kernel, ciascuna
   approvata per nome e sostituibile, controllo automatico con `cargo-deny`.

## Opzioni considerate (licenza del codice OMNI)

1. Proprietaria (tutti i diritti riservati).
2. Permissiva (Apache-2.0 o MIT).
3. Copyleft debole (MPL-2.0).
4. Copyleft forte (GPLv3).

## Proposta

- **Dipendenze:** opzione 2, con **zero dipendenze nel kernel per K1**.
  - Candidati futuri da valutare uno per uno: `acpi`/`aml` per ACPI (K2), `smoltcp` per
    TCP/IP (K8), una libreria TLS (K8).
- **Licenza:** decisione del proprietario. Questo ADR non ne sceglie una.

## Conseguenze

Il registro rende esplicito e verificabile ciò che non è OMNI. La licenza determina come
altri potranno usare il codice.

## Verifiche richieste

`cargo-deny` in CI da K0.

## Decisione del proprietario

—
