# ADR-0009 — Caricatore di avvio: OMNI Boot (UEFI)

- **Stato:** Proposto — richiede decisione
- **Data:** 2026-11-10
- **Decisioni approvate correlate:** 1, 15, 47

## Contesto

Il kernel deve essere caricato dal firmware UEFI su x86-64. Nessuna ISO e nessuna modifica
al firmware del PC del proprietario.

## Opzioni considerate

1. **OMNI Boot:** applicazione UEFI propria in Rust, con binding UEFI scritti per OMNI.
2. Limine (BSD-2).
3. GRUB (GPLv3).

## Proposta

Opzione 1, con Limine come piano B documentato.

## Conseguenze

- **Positive:** pieno controllo di formato e verifiche; più avanti, ripristino A/B e firma
  del kernel (K9).
- **Negative:** circa 1–2 mila righe da scrivere e provare.
- **Rischi:** RK-02 (firmware reali con difetti).

## Verifiche richieste

Criteri K1-01 e K1-02 in QEMU+OVMF.

## Decisione del proprietario

—
