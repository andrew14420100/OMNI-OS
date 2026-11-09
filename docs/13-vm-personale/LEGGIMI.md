# OMNI OS 0.2.0 — VM personale (anteprima sperimentale)

Disco virtuale di **prova** di OMNI OS (base Fedora Kinoite 45 verificata, M1) con
**OMNI Shell V2** che si apre da sola dopo l'accesso. Serve solo dentro una macchina
virtuale: non va installato su un disco fisico e non modifica Windows.

> Non è una release: è un artifact di GitHub Actions, valido 14 giorni.
> Non è M2, M3 o M4. Gli aggiornamenti automatici non sono configurati.

## Contenuto del pacchetto

| File | Cosa contiene |
|---|---|
| `OMNI-OS-0.2.0-vm-personale.vmdk` | disco virtuale (VMDK compresso, 30 GB massimi, cresce solo se serve) |
| `SHA256SUMS.txt` | impronte SHA-256 dei file |
| `controlli-di-sicurezza.md` | esito dei controlli fatti su questo stesso disco prima della pubblicazione dell'artifact |
| `inventario-software.txt` | elenco dei pacchetti RPM e impronte dei file di OMNI Shell |
| `LEGGIMI.md` | questo documento |

## 1. Scaricare e verificare

1. Scarica l'artifact `OMNI-OS-0.2.0-VM-personale` dalla pagina dell'esecuzione di
   GitHub Actions (sezione **Artifacts**) ed estrai lo ZIP in una cartella, per esempio
   `C:\VM\OMNI-OS`.
2. In PowerShell, nella cartella estratta:
   ```powershell
   Get-FileHash .\OMNI-OS-0.2.0-vm-personale.vmdk -Algorithm SHA256
   Get-Content .\SHA256SUMS.txt
   ```
   Le due impronte devono coincidere (le lettere maiuscole/minuscole non contano).
   In alternativa: `certutil -hashfile OMNI-OS-0.2.0-vm-personale.vmdk SHA256`.

## 2. Creare la VM con VirtualBox (gratuito)

1. **Nuova** macchina: nome `OMNI OS`, tipo **Linux**, versione **Fedora (64-bit)**.
   Non indicare nessuna ISO.
2. Memoria **6–8 GB** (minimo 4 GB), processori **2–4**.
3. Spunta **Abilita EFI** (obbligatorio: il disco avvia solo in UEFI).
4. Disco: **Usa un file di disco rigido virtuale esistente** → scegli il file `.vmdk`.
5. Dopo la creazione, in **Impostazioni**:
   - *Schermo*: controller grafico **VMSVGA**, memoria video 128 MB,
     **accelerazione 3D disattivata**;
   - *Sistema → Scheda madre*: lascia EFI attivo; Secure Boot disattivato
     (riguarda solo la VM, non il PC);
   - *Rete*: NAT (predefinito).
6. **Avvia**.

### In alternativa: VMware Workstation Pro (gratuito per uso personale)

Nuova VM → *Custom* → *I will install the operating system later* → Linux, *Fedora
64-bit* → firmware **UEFI** (Secure Boot non spuntato) → 2–4 CPU, 6–8 GB → disco:
*Use an existing virtual disk* → file `.vmdk` (se chiede di convertirlo, accetta).

> Hyper-V: il file VHDX non è nel pacchetto predefinito (si può generare su richiesta).

## 3. Primo avvio

1. Il primo avvio richiede 1–3 minuti. Compare la **configurazione iniziale di KDE**:
   scegli lingua e tastiera, poi **crea il tuo account** (nome utente e password a tua
   scelta). Il disco non contiene utenti, password né chiavi: le crei tu ora.
2. Dopo l'accesso, **OMNI Shell si apre a schermo intero** sopra Plasma.
3. Al primo accesso Plasma mostra anche il **Benvenuto** di Fedora/KDE sopra OMNI Shell:
   chiudilo con *Skip* (o completalo); non ricompare agli accessi successivi.

## 4. Usare OMNI Shell

- **Dock** in basso: clic sulle icone per avviare davvero Konsole (terminale), Dolphin
  (file), Firefox (browser).
- **Launcher**: pulsante a griglia nel dock, oppure scrivi per cercare fra le
  applicazioni realmente installate; Invio avvia la prima.
- **Notifiche** e **Impostazioni rapide**: icone in alto a destra (tema chiaro/scuro,
  colore d'accento, movimento ridotto, risparmio risorse).
- Le applicazioni avviate si aprono in finestre Plasma normali: per tornarci usa
  Alt+Tab, oppure esci da OMNI Shell.
- **Uscire da OMNI Shell**: Impostazioni rapide → *Esci da OMNI Shell (torna a Plasma)*.
  Il desktop Plasma resta intatto.
- **Riaprirla**: menu di Plasma → cerca *OMNI Shell*.
- **Non aprirla più all'accesso**: Impostazioni di sistema → *Avvio automatico* →
  disattiva *OMNI Shell*.

## 5. Cosa è reale e cosa è ancora simulato

| Funzione | Stato |
|---|---|
| Avvio del sistema, accesso, sessione Plasma Wayland, mouse e tastiera | **reale** |
| Elenco delle applicazioni nel launcher (file `.desktop` installati) | **reale** |
| Avvio di Konsole, Dolphin, Firefox, Impostazioni e delle altre app | **reale** (`gio launch`, ripiego `kstart`) |
| Tema chiaro/scuro, accento, movimento ridotto, risparmio risorse | **reale** (solo per OMNI Shell) |
| Orologio e calendario | **reale** |
| Notifiche nel centro notifiche | **simulate** (esempi, non quelle del sistema) |
| Rete, audio, luminosità, spazi di lavoro, assistente AI | **simulati / non collegati** |
| Gestione finestre, pannello e accesso | **Plasma, KWin e il gestore di accesso di Fedora** (non sostituiti) |

## 6. Avvertenze

- Sistema di **prova**: non usarlo per dati importanti.
- Senza accelerazione 3D la grafica usa il rendering software: OMNI Shell lo rileva e
  riduce da sola le animazioni.
- Per eliminare tutto: cancella la VM in VirtualBox/VMware e la cartella estratta.
