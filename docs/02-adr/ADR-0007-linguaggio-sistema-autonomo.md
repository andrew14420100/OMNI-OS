# ADR-0007 — Linguaggio del sistema OMNI autonomo

- **Stato:** Accettato (2026-11-10, dal proprietario)
- **Data:** 2026-11-10
- **Decisioni approvate correlate:** 1, 51, 54 (sostituisce ADR-0006 per il sistema autonomo, se accettato)

## Contesto

Il proprietario vuole un sistema operativo con un kernel originale. I criteri, in ordine,
sono: sicurezza, prestazioni, manutenzione e sviluppo gratuito. Valutazione completa in
`docs/16-omni-autonomo/linguaggi-e-strumenti.md`.

## Opzioni considerate

1. Rust stabile.
2. C17.
3. C++.
4. Zig.
5. Ada/SPARK.

## Proposta

**Rust stabile** per tutto il codice OMNI: caricatore, kernel, servizi, toolkit e app.
Assembly x86-64 solo dove inevitabile. Nessuna toolchain nightly.

## Conseguenze

- **Positive:** le intere classi di errori di memoria, causa principale delle vulnerabilità
  dei kernel, sono escluse dal codice sicuro; test e gestione dei pacchetti sono integrati.
- **Negative:** il codice `unsafe` resta necessario nei moduli dell'hardware; i tempi di
  compilazione sono più alti; ci sono meno esempi di sistemi operativi Rust completi.
- **Rischi:** RK-04, RK-08.

## Verifiche richieste

K1 compila con Rust stabile, nessun avviso clippy, `unsafe` contato e motivato.

## Decisione del proprietario

**Accettato il 2026-11-10:** Rust stabile come linguaggio principale, assembly dove tecnicamente necessario. Per il sistema autonomo sostituisce l'ADR-0006 (che resta valido solo per le versioni 0.x su Fedora).
