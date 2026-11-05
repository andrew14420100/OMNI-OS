# Procedura di sicurezza per la prima installazione fisica

- **Stato:** proposta M0. **Non eseguire**: la prima installazione fisica avverrà solo in M3, dopo M1 e M2 e dopo autorizzazione esplicita.
- **Requisito vincolante:** SEC-INST-01 ([`requisiti-sicurezza.md`](requisiti-sicurezza.md) §3).

## Condizione di blocco

> Se l'SSD Windows **non** può essere scollegato in sicurezza, la procedura si
> interrompe al punto B. L'installazione non procede finché il proprietario non
> approva per iscritto una diversa procedura di isolamento.

## A. Preparazione (giorni prima)

1. Backup completo di Windows su supporto esterno, verificato aprendo alcuni file dal backup.
2. Salvare la **chiave di recupero BitLocker** (account Microsoft o stampa) se BitLocker è attivo.
3. Annotare (foto) le impostazioni UEFI attuali: ordine di avvio, Secure Boot, CSM, slot M.2.
4. Annotare modello, numero di serie e capacità di **entrambi** gli SSD (da Windows: `Get-PhysicalDisk` in PowerShell, sola lettura).
5. Identificare fisicamente quale slot M.2 / connettore contiene l'SSD Windows (manuale MSI B850A Gaming Plus WiFi).
6. Preparare il supporto USB di installazione OMNI e il supporto USB di recupero (prodotti in M2).

## B. Scollegamento dell'SSD Windows

Prerequisiti di sicurezza per scollegarlo:

- PC spento e **scollegato dalla corrente**; attendere la scarica.
- Scarico elettrostatico (braccialetto antistatico o contatto con parte metallica del case).
- Attrezzi adatti; nessuna forza sul connettore M.2 o sul dissipatore.
- Se un passaggio non è chiaro o richiede di smontare la GPU o il dissipatore in modo rischioso: **fermarsi** e valutare l'alternativa con il proprietario.

Esito:

- [ ] SSD Windows scollegato in sicurezza → proseguire al punto C.
- [ ] Non possibile in sicurezza → **STOP**. Documentare il motivo e proporre una procedura alternativa (vedi requisiti §3, nota) per approvazione.

## C. Installazione

1. Avviare il PC: verificare nel firmware che **sia visibile solo l'SSD OMNI** (e la chiavetta USB).
2. Avviare il supporto OMNI. Nell'installer verificare modello, seriale e capacità del disco di destinazione (SEC-INST-02).
3. Confermare digitando l'identificativo del disco (SEC-INST-04).
4. Installare con cifratura LUKS2 (SEC-DATA-01).
5. Registrazione chiave MOK se previsto dall'opzione Secure Boot scelta (ADR-0004 §4).
6. Primi test di M3 con l'SSD Windows ancora scollegato.

## D. Ricollegamento di Windows

1. PC spento e scollegato dalla corrente, ricollegare l'SSD Windows.
2. Nel firmware: verificare che entrambi i dischi siano visibili; impostare l'ordine di avvio desiderato.
3. Avviare **Windows**: verificare avvio normale, nessuna richiesta BitLocker, Secure Boot attivo (`msinfo32`), integrità dei dati.
4. Avviare **OMNI** dal menu di avvio del firmware: verificare che non abbia modificato l'SSD Windows (confronto della tabella delle partizioni letta prima e dopo, in sola lettura).
5. Registrare gli esiti nel rapporto M3.

## E. Registro

| Data | Passo | Esito | Note | Esecutore |
|---|---|---|---|---|
| | | | | |
