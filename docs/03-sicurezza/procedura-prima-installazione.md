# Procedura di sicurezza per la prima installazione fisica

- **Stato:** proposta M0. **Non eseguire**: la prima installazione fisica avverrà solo in M3, dopo M1 e M2 e dopo autorizzazione esplicita.
- **Requisito vincolante:** SEC-INST-01 ([`requisiti-sicurezza.md`](requisiti-sicurezza.md) §3).

## Condizione di blocco

> Se l'SSD Windows **non** può essere scollegato in sicurezza, la procedura si
> interrompe al punto B. L'installazione non procede finché il proprietario non
> approva per iscritto una diversa procedura di isolamento.

## A. Preparazione (giorni prima)

1. Backup completo di Windows su supporto esterno, verificato aprendo alcuni file dal backup.
2. Preparare la **chiave di recupero BitLocker** secondo la parte F (F.1), se BitLocker è attivo.
3. Annotare (foto) le impostazioni UEFI attuali: ordine di avvio, Secure Boot, CSM, slot M.2.
4. Annotare modello, numero di serie e capacità di **entrambi** gli SSD (da Windows: `Get-PhysicalDisk` in PowerShell, sola lettura). Conservare i numeri di serie **solo in locale**, non nel repository pubblico.
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
3. Avviare **Windows**: verificare avvio normale, Secure Boot attivo (`msinfo32`), integrità dei dati. Se compare la schermata di ripristino BitLocker applicare la parte F (F.3).
4. Avviare **OMNI** dal menu di avvio del firmware: verificare che non abbia modificato l'SSD Windows (confronto della tabella delle partizioni letta prima e dopo, in sola lettura).
5. Registrare gli esiti nel rapporto M3.

## E. Registro

| Data | Passo | Esito | Note | Esecutore |
|---|---|---|---|---|
| | | | | |

## F. Procedura controllata per la chiave di recupero BitLocker

**Perché serve.** Se BitLocker protegge il disco di Windows con il TPM, la
chiave di sblocco è legata a misure dell'avvio (fra cui stato e chiavi di
Secure Boot, configurazione del firmware, ordine di avvio). Cambiare queste
impostazioni, aggiornare il BIOS o aggiungere un disco con un altro bootloader
**può** far comparire all'avvio di Windows la schermata di ripristino che chiede
la chiave di recupero (48 cifre). Non è un danno ai dati, ma senza la chiave
Windows resta inaccessibile.

**Regole fisse**

- La chiave di recupero **non** va mai scritta nel repository (pubblico), nella PR, nei rapporti o nella chat con Claude. Claude non la chiede e non deve riceverla.
- **Anche l'ID della chiave resta solo in locale**, conservato dal proprietario insieme alle sue note private (non nel repository, non nella PR, non nei rapporti, non in chat). Nei documenti del progetto si scrive soltanto se la verifica è stata fatta ("sì/no").
- **Comandi che possono mostrare la password di recupero:** `manage-bde -protectors -get C:` elenca le protezioni con tipo e ID (documentazione Microsoft) e per la protezione "Password numerica" può mostrare anche la **password di recupero completa**; lo stesso vale per l'equivalente PowerShell `(Get-BitLockerVolume -MountPoint C).KeyProtector`, che espone il campo `RecoveryPassword`. Questi comandi li esegue **solo il proprietario, in locale**, senza condividere output, copie, registrazioni dello schermo, fotografie o condivisione schermo con nessuno (Claude compreso), e chiudendo la finestra al termine.
- Claude **non** esegue comandi BitLocker: tutti i comandi di questa parte sono indicazioni per il proprietario.
- Nessuna azione che modifichi la configurazione di BitLocker viene eseguita senza approvazione esplicita del proprietario (Regola operativa 10).

### F.1 Prima di qualsiasi modifica al firmware o all'avvio

1. In Windows, da prompt amministratore, **in sola lettura**: `manage-bde -status` → verificare se la protezione è attiva sul disco di sistema e se fra le protezioni compare "Password numerica". Questo comando non mostra la password.
2. **Solo il proprietario, in locale** (vedi regole fisse): `manage-bde -protectors -get C:` → leggere l'ID della protezione "Password numerica" e annotarlo **solo nelle proprie note locali**. L'output può contenere la password di recupero: non copiarlo, non salvarlo, non fotografarlo, non condividerlo.
3. Verificare che la chiave di recupero con lo stesso ID sia disponibile **fuori dal PC**: account Microsoft (pagina delle chiavi di ripristino BitLocker, che mostra ID e chiave), stampa conservata o file su supporto esterno conservato dal proprietario.
4. Verificare di poterla leggere davvero (non solo che "dovrebbe esserci").
5. Esito: **se la chiave non è disponibile, STOP**. Nessuna modifica al firmware, a Secure Boot o ai dischi finché non è recuperata o salvata.

### F.2 Sospensione temporanea di BitLocker (facoltativa, solo con approvazione)

Microsoft prevede la sospensione temporanea della protezione prima di
aggiornamenti del firmware: la cifratura resta, ma al riavvio successivo il TPM
non viene verificato e la protezione si riattiva automaticamente.

- Comando (solo se approvato): `manage-bde -protectors -disable C: -RebootCount 1`
- È una modifica alla configurazione di Windows: richiede approvazione esplicita e va annotata nel registro (parte E).
- Proposta: **non** usarla per impostazione predefinita; la chiave di recupero disponibile (F.1) è sufficiente come protezione.

### F.3 Se compare la schermata di ripristino BitLocker

1. **Non** riavviare ripetutamente e **non** cambiare altre impostazioni del firmware.
2. Confrontare l'ID chiave mostrato sullo schermo con quello annotato **localmente** in F.1 (o con quello associato alla chiave nell'account Microsoft).
3. Se coincide: inserire la chiave di recupero. Windows dovrebbe avviarsi.
4. Dopo l'avvio: `manage-bde -status` per verificare che la protezione sia di nuovo attiva; riavviare una volta per verificare che la richiesta non si ripresenti.
5. Se la richiesta si ripresenta a ogni avvio: fermarsi e analizzare la causa (stato di Secure Boot o ordine di avvio cambiato) prima di continuare.
6. Se l'ID non coincide o la chiave non è disponibile: spegnere, **ripristinare le impostazioni UEFI precedenti** (foto del punto A.3) e riprovare l'avvio; spesso il ritorno allo stato precedente permette al TPM di sbloccare di nuovo il disco.
7. Annotare nel registro (parte E) solo data, causa probabile ed esito: **né la chiave né il suo ID**.

### F.4 Momenti in cui applicare la parte F

| Evento | Rischio di richiesta BitLocker |
|---|---|
| Cambio di stato di Secure Boot (attivo/disattivo, modalità) | Alto |
| Aggiornamento BIOS/UEFI della scheda madre | Alto |
| Modifica dell'ordine di avvio o aggiunta di voci di avvio | Possibile |
| Ricollegamento dell'SSD Windows dopo l'installazione di OMNI | Possibile |
| Registrazione di una MOK (non modifica le chiavi del firmware) | Basso, da verificare |
| Reset delle impostazioni UEFI ai valori predefiniti | Alto |
