# ADR-0010 — Formati: ELF64, GPT/FAT32, OMNIFS

- **Stato:** Proposto
- **Data:** 2026-11-10
- **Decisioni approvate correlate:** 1, 26

## Contesto

Servono un formato per gli eseguibili, una tabella delle partizioni e dei filesystem.

## Opzioni considerate

- **Eseguibili:** ELF64 (supporto nativo di LLVM) oppure PE/COFF (formato UEFI e Windows).
- **Dischi:** GPT (obbligatoria per UEFI).
- **Filesystem:** FAT32 per la partizione EFI e le chiavette; per i dati, un filesystem
  proprio (OMNIFS) oppure il porting di uno esistente.

## Proposta

- ELF64 per kernel e programmi OMNI; il caricatore resta PE, come richiede UEFI.
- GPT e FAT32 scritti da zero.
- **OMNIFS** proprio, con progetto su disco da presentare prima di K5.

ELF è uno standard aperto, non una dipendenza da Linux.

## Conseguenze

Toolchain standard senza adattamenti. OMNIFS richiede cura (journal, checksum, fuzzing).

## Verifiche richieste

- **K1:** parser ELF con test.
- **K5:** prove di consistenza dopo arresti simulati.

## Decisione del proprietario

—
