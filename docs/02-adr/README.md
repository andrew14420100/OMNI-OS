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
| [0006](ADR-0006-linguaggi-ipc-privilegi.md) | Linguaggi, IPC e separazione dei privilegi | Proposto |
