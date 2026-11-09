# OMNI OS 0.3.0 — desktop OMNI in macchina virtuale (anteprima sperimentale)

Questa versione sostituisce la 0.2.0. OMNI Shell non è più una finestra a schermo intero
sopra Plasma, ma **l'unica interfaccia del desktop**:
- un solo menu Start, una sola barra delle applicazioni e nessun pannello duplicato;
- le finestre e i servizi sono quelli reali del sistema.

Plasma e KWin restano sotto, come infrastruttura. Il desktop Plasma originale resta
disponibile come **modalità sicura**.

> Non è una release: è un artifact di GitHub Actions, valido 14 giorni.
> Non è M2, M3 o M4. Gli aggiornamenti automatici non sono configurati.
> Nessuna funzione di intelligenza artificiale è presente o attiva.

## 1. Scaricare e verificare

1. Scarica l'artifact `OMNI-OS-0.3.0-desktop-VM` ed estrai lo ZIP in una cartella nuova,
   per esempio `C:\VM\OMNI-OS-0.3`.
2. In PowerShell, nella cartella estratta:
   ```powershell
   Get-FileHash .\OMNI-OS-0.3.0-desktop.vmdk -Algorithm SHA256
   Get-Content .\SHA256SUMS.txt
   ```
   Le due impronte devono coincidere.

## 2. Sostituire la VM 0.2.0 (consigliato: una VM nuova)

La 0.3.0 è un disco nuovo: i dati della VM 0.2.0 **non** vengono trasferiti.

1. Se nella VM 0.2.0 hai file che vuoi tenere, copiali prima fuori dalla VM. Puoi usare
   una cartella condivisa oppure caricarli su un servizio di tua scelta.
2. Spegni la VM 0.2.0. In VirtualBox: clic destro → *Rimuovi* → **Rimuovi solo** (tiene i
   file) oppure *Elimina tutti i file* se non ti serve più.
3. Crea una VM nuova con il disco 0.3.0 seguendo il punto 3.

In alternativa puoi tenerle entrambe: sono due VM indipendenti e non condividono nulla.

## 3. Creare la VM con VirtualBox

1. **Nuova**: nome `OMNI OS 0.3`, tipo **Linux**, versione **Fedora (64-bit)**, senza ISO.
2. **Memoria** 8 GB (minimo 4 GB). **Processori**: 4–6 (il tuo Ryzen 7 9800X3D ne ha 16
   logici; non superare la metà).
3. Spunta **Abilita EFI** (obbligatorio).
4. **Disco**: *Usa un file di disco rigido virtuale esistente* → il file `.vmdk`.
5. **Impostazioni → Schermo**:
   - controller grafico **VMSVGA**;
   - memoria video **256 MB** (il massimo);
   - **Abilita l'accelerazione 3D: attivata**.

   È la scelta più importante per la velocità: senza accelerazione 3D tutta la grafica
   (KWin e OMNI Shell) viene disegnata dal processore, e in 4K questo rallenta molto ogni
   finestra e animazione. Se con l'accelerazione 3D vedi difetti grafici, disattivala:
   OMNI OS funziona lo stesso, ma più lentamente.
6. **Impostazioni → Sistema → Accelerazione**: interfaccia di paravirtualizzazione **KVM**.
7. **Audio**: controller **Intel HD Audio** (predefinito). **Rete**: **NAT** (predefinito).
8. **Avvia**.

## 4. Primo avvio e accesso

1. Compare *Welcome to Plasma Desktop*: premi **Begin Setup**, scegli lingua e tastiera e
   crea il tuo account. Il disco non contiene utenti, password né chiavi.
2. Nella schermata di accesso controlla in basso la **sessione**:
   - **OMNI OS**: il desktop OMNI (predefinita);
   - **OMNI OS – modalità sicura (desktop Plasma)**: il desktop Plasma originale, senza
     OMNI Shell. Usala se qualcosa non funziona.
3. Per il 4K a scala 200%:
   - Impostazioni rapide (icone di rete e volume in basso a destra) → **Schermo**;
   - scegli **3840x2160** e **200%**, poi **Applica**;
   - OMNI Shell conferma solo dopo aver riletto lo stato reale.

   La frequenza proposta è solo quella offerta dallo schermo virtuale: di solito 60 Hz,
   non 240 Hz.

## 5. Usare il desktop OMNI

| Cosa | Come |
|---|---|
| Menu Start | pulsante OMNI nella barra oppure tasto **Windows** |
| Cercare un'app | apri Start e scrivi; **Invio** avvia la prima. Il testo che non corrisponde a un'app va alla ricerca di sistema (KRunner) |
| App aperte | barra in basso. Clic = attiva o riduci a icona. Clic centrale = nuova finestra. Clic destro = menu |
| Fissare un'app | clic destro in Start o nella barra → *Aggiungi alla barra* / *Aggiungi a Start* |
| Visualizzazione attività e desktop virtuali | pulsante a livelli nella barra (Panoramica di KWin), oppure Meta+W; Ctrl+Meta+frecce per cambiare desktop |
| Mostra desktop | estremità destra della barra |
| Rete, audio, Bluetooth, non disturbare, energia, schermo | icone di rete e volume nella barra |
| Notifiche e calendario | orologio nella barra |
| Spegnere, riavviare, disconnettersi, bloccare, sospendere | Start → pulsante energia in basso a destra |
| Alt+Tab, massimizzare, spostare, ridimensionare | come sempre: le gestisce KWin |

Lo spegnimento chiude prima le applicazioni, che possono chiedere di salvare il lavoro.

## 6. Cosa è reale e cosa è limitato da VirtualBox

Vedi `prove-reali.md` nel pacchetto (esito delle prove eseguite su questa versione) e la
tabella "Funzioni" in `docs/14-desktop-reale/README.md` nel repository. In breve:
- **Wi-Fi e Bluetooth**: in VirtualBox di solito non ci sono schede Wi-Fi o Bluetooth;
  OMNI Shell lo dice invece di inventare reti o dispositivi.
- **Luminosità**: un monitor virtuale non la consente.

## 7. Se qualcosa non va

- **OMNI Shell si chiude da sola**: systemd la riavvia. Dopo 4 arresti in 2 minuti parte
  automaticamente il desktop Plasma di riserva, quindi non resti mai senza interfaccia.
  Al prossimo accesso si torna alla sessione OMNI.
- **Problemi persistenti**: all'accesso scegli **OMNI OS – modalità sicura**.
- **Diagnostica**: in Konsole esegui
  `journalctl --user -u omni-shell -b --no-pager | tail -50`.
- **Per eliminare tutto**: rimuovi la VM in VirtualBox e la cartella estratta.
