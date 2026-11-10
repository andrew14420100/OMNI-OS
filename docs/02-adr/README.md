# Architecture Decision Records (ADR)

Ogni decisione tecnica rilevante è registrata come ADR numerato.
Un ADR **non modifica** le 55 decisioni approvate: se una proposta ne toccasse
una, la variazione deve essere evidenziata e approvata dal proprietario
(Regola operativa 2).

## Stati

| Stato | Significato |
|---|---|
| Proposto | Analisi completata, in attesa di decisione del proprietario |
| Accettato | Approvato dal proprietario (indicare data) |
| Respinto | Valutato e scartato |
| Sostituito | Superato da un ADR successivo (indicare quale) |

## Indice

| ADR | Titolo | Stato |
|---|---|---|
| [0000](ADR-0000-modello.md) | Modello di ADR | — |
| [0001](ADR-0001-uso-adr.md) | Uso degli ADR e processo decisionale | Proposto |
| [0002](ADR-0002-base-kinoite-vs-universal-blue.md) | Base: Fedora Kinoite ufficiale vs Universal Blue | **Proposto — richiede decisione** |
| [0003](ADR-0003-immagini-aggiornamenti-rollback-firma.md) | bootc, rpm-ostree, aggiornamenti, rollback e firma | Proposto |
| [0004](ADR-0004-nvidia-open-secure-boot.md) | Driver NVIDIA open, Secure Boot e firma dei moduli | **Proposto — richiede decisione** |
| [0005](ADR-0005-release-fedora-riferimento.md) | Release Fedora di riferimento (Kinoite 45) | Proposto — verifica prima di M1 |
| [0006](ADR-0006-linguaggi-ipc-privilegi.md) | Linguaggi, IPC e separazione dei privilegi | Proposto (vale solo per le versioni 0.x su Fedora; per il sistema autonomo è sostituito da 0007/0008) |
| [0007](ADR-0007-linguaggio-sistema-autonomo.md) | Linguaggio del sistema OMNI autonomo (Rust) | **Accettato (2026-11-10)** |
| [0008](ADR-0008-modello-kernel.md) | Modello del kernel (ibrido orientato al microkernel) | **Accettato (2026-11-10)** |
| [0009](ADR-0009-caricatore-uefi.md) | Caricatore di avvio OMNI Boot (UEFI) | **Accettato (2026-11-10)** |
| [0010](ADR-0010-formati-standard.md) | Formati: ELF64, GPT/FAT32, OMNIFS | Proposto |
| [0011](ADR-0011-dipendenze-licenze.md) | Dipendenze di terze parti e licenza del codice OMNI | **Accettato (2026-11-10)** |
