# OMNI OS 0.4.0 sperimentale: macchina virtuale

La 0.4.0 parte dalla 0.3.0 verificata e aggiunge:
- le app di sistema OMNI: **Impostazioni**, **Gestione attività**, **Esplora file** e **OMNI Store**;
- gli interventi sulle prestazioni descritti in `confronto-prestazioni.md`;
- lo schema di colori OMNI anche nelle app Qt/KDE.

Plasma e KWin restano l'infrastruttura. Il desktop Plasma originale resta disponibile come
**modalità sicura**.

> Non è una release: è un artifact di GitHub Actions, valido 14 giorni.
> Non è un'installazione per il computer fisico: niente ISO, chiavetta USB o dual boot.
> Gli aggiornamenti automatici non sono configurati. Nessuna funzione di intelligenza
> artificiale è presente o attiva.

## 1. Scaricare e verificare

1. Scarica l'artifact `OMNI-OS-0.4.0-sperimentale-VM` ed estrai lo ZIP in una cartella **nuova**.
   Per esempio `C:\VM\OMNI-OS-0.4`, non la cartella della 0.3.
2. In PowerShell, nella cartella estratta:
   ```powershell
   Get-FileHash .\OMNI-OS-0.4.0-sperimentale.vmdk -Algorithm SHA256
   Get-Content .\SHA256SUMS.txt
   ```
   Le due impronte devono coincidere.

## 2. Provare la 0.4 senza perdere la VM 0.3.0

La 0.4.0 è un **disco nuovo e indipendente**. La VM 0.3.0 non viene toccata. Puoi tenerle
entrambe e usarle a turno.

1. **Non** sostituire il disco della VM 0.3. Non usare *Rimuovi* sulla VM 0.3.
2. Facoltativo, ma consigliato: in VirtualBox seleziona la VM 0.3 → **Istantanee** →
   **Crea**. Ti permette di tornare esattamente allo stato attuale.
3. Crea una VM **nuova** per la 0.4 seguendo il punto 3. Usa un nome diverso, per esempio
   `OMNI OS 0.4`.
4. Non avviare le due VM insieme, salvo che tu abbia almeno 16 GB di RAM liberi: ognuna usa
   la memoria che le assegni.
5. I file della VM 0.3 restano dentro la VM 0.3. Per portarli nella 0.4, copiali con una
   cartella condivisa di VirtualBox (*Impostazioni → Cartelle condivise*).

Per tornare alla 0.3 ti basta avviare la VM 0.3. Per eliminare la 0.4: clic destro sulla VM
`OMNI OS 0.4` → **Rimuovi** → *Elimina tutti i file*, poi elimina la cartella estratta.

## 3. Creare la VM con VirtualBox

1. **Nuova**: nome `OMNI OS 0.4`, tipo **Linux**, versione **Fedora (64-bit)**, senza ISO.
2. **Memoria**: 8 GB, minimo 4 GB. **Processori**: 4–6, non più della metà dei processori
   logici del computer.
3. Spunta **Abilita EFI** (obbligatorio).
4. **Disco**: *Usa un file di disco rigido virtuale esistente* → il file `.vmdk`.
5. **Impostazioni → Schermo**:
   - controller grafico **VMSVGA**;
   - memoria video **256 MB**;
   - **Abilita l'accelerazione 3D**.

   È la scelta che conta di più per la velocità. La VM non usa direttamente la scheda
   grafica del computer: VirtualBox traduce le chiamate grafiche. Senza accelerazione 3D
   disegna tutto il processore, e in 4K questo è lento.
6. **Impostazioni → Sistema → Accelerazione**: interfaccia di paravirtualizzazione **KVM**.
7. **Audio**: Intel HD Audio. **Rete**: NAT.
8. **Avvia**.

## 4. Primo avvio

1. Alla prima accensione compare la configurazione iniziale. Crea il tuo account: il disco
   non contiene utenti, password né chiavi.
2. Nella schermata di accesso, la sessione predefinita è **OMNI OS**. La sessione
   **OMNI OS – modalità sicura (desktop Plasma)** apre il desktop Plasma originale.
3. Per il 4K a scala 200%: **Impostazioni → Schermo**, scegli **3840x2160** e **200%**.

## 5. Le app OMNI

| App | Dove | Cosa fa davvero |
|---|---|---|
| **Impostazioni** | Start, oppure ⚙ nel pannello rapido (icone di rete e volume) | Rete, Bluetooth, audio, schermo, aspetto, mouse e tastiera, lingua, data e ora, account, privacy, notifiche, energia, archiviazione, app predefinite, aggiornamenti, backup, informazioni. Ogni modifica è confermata solo dopo la risposta del sistema. Le operazioni da amministratore chiedono la password (polkit). |
| **Gestione attività** | Start | Processi con CPU e memoria, grafici di processore, memoria, disco e rete, app aperte, app all'avvio. Termina solo i tuoi processi, dopo una conferma. La GPU della VM è virtuale: il carico della scheda grafica fisica non è visibile da dentro la VM. |
| **Esplora file** | Start, oppure apri una cartella da un'altra app | Schede, cronologia, ricerca, anteprima, viste Dettagli/Icone. Copia, taglia, incolla, rinomina, trascinamento, ZIP. Cestino con ripristino, proprietà e permessi. L'eliminazione definitiva chiede sempre conferma. Usa KIO, lo stesso sistema di Dolphin. |
| **OMNI Store** | Start, oppure *OMNI Store* nel pannello rapido | App Flatpak dal catalogo reale delle sorgenti configurate, come Flathub. Prima dell'installazione mostra i permessi. Installa, rimuove e aggiorna solo quando premi il pulsante. Se Flathub non è configurato, puoi aggiungerlo dalla pagina *Sorgenti* solo per il tuo utente. |

## 6. Cosa è reale e cosa è limitato da VirtualBox

L'esito di ogni prova è in `prove-reali.md`; le misure prima e dopo sono in
`confronto-prestazioni.md`. In breve:
- **Wi-Fi e Bluetooth**: VirtualBox di solito non fornisce schede Wi-Fi o Bluetooth.
  OMNI lo segnala invece di inventare reti o dispositivi.
- **Luminosità, frequenze oltre i 60 Hz, GPU fisica**: non disponibili in una VM.
- **Aggiornamenti di sistema**: *Impostazioni → Aggiornamenti* mostra lo stato reale di
  rpm-ostree. Questa VM di prova non ha una sorgente di aggiornamenti firmata configurata,
  quindi il controllo può non trovare nulla.

## 7. Se qualcosa non va

- **OMNI Shell si chiude da sola**: systemd la riavvia. Dopo 4 arresti in 2 minuti parte il
  desktop Plasma di riserva, quindi non resti mai senza interfaccia.
- **Problemi persistenti**: all'accesso scegli **OMNI OS – modalità sicura**.
- **Ripristino dell'aspetto**: *Impostazioni → Backup e ripristino → Ripristina le
  preferenze OMNI*. Il file precedente viene conservato.
- **Diagnostica**: in Konsole esegui `journalctl --user -b --no-pager | grep -i omni | tail -50`.
