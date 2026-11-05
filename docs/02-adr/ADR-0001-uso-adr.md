# ADR-0001 — Uso degli ADR e processo decisionale

- **Stato:** Proposto
- **Data:** 2026-11-05
- **Decisioni approvate correlate:** 51, 54, 55

## Contesto
Le specifiche v1.0 fissano 55 decisioni di prodotto ma lasciano aperte molte
scelte tecniche (base, firma, driver, toolchain). Servono tracciabilità e un
punto di approvazione esplicito (Regola operativa 14).

## Proposta
1. Ogni scelta tecnica non banale viene registrata in `docs/02-adr/`.
2. Gli ADR distinguono **fatti verificati con fonte**, **fatti da verificare** e **proposte**.
3. Un ADR passa ad "Accettato" solo con approvazione esplicita del proprietario, annotata nella sezione finale.
4. Gli ADR accettati non si modificano: si sostituiscono con un nuovo ADR.
5. Le fonti sono elencate in `docs/fonti.md` con data di consultazione.

## Conseguenze
Più documentazione, ma nessuna scelta implicita; facilita la revisione via PR.

## Decisione del proprietario
_In attesa._
