# Requisiti di sicurezza — OMNI OS

- **Stato:** proposta M0. Il requisito **SEC-INST-01** è richiesto esplicitamente dal proprietario (autorizzazione M0, punto 5) ed è **obbligatorio**.
- **Riferimenti:** spec §3.3, §3.4, §4, §8; ADR-0003, ADR-0004, ADR-0006.

---

## 1. Beni da proteggere

| Bene | Perché è critico |
|---|---|
| SSD Windows e i suoi dati | Regola operativa 10: non deve mai essere alterato |
| Dati personali sull'SSD OMNI | Nessuna perdita di dati (RNF) |
| Credenziali (password, token, chiavi SSH, chiavi API cloud) | Accesso a servizi esterni |
| Chiavi di firma (cosign, MOK) | Controllano cosa il PC considera affidabile |
| Integrità del sistema (`/usr`, bootloader, kmod) | Avviabilità e sicurezza |
| Memoria AI e registri | Contengono contesto personale |

## 2. Modello delle minacce (sintesi)

| ID | Minaccia | Esempio | Contromisure principali |
|---|---|---|---|
| T-01 | Errore umano o di script sui dischi | Installazione o formattazione sul disco sbagliato | SEC-INST-01..05 |
| T-02 | Agente AI che esegue azioni dannose | Prompt injection da pagina web o documento | SEC-AI-01..12 |
| T-03 | Immagine di sistema compromessa | Registry o CI manomessi | SEC-UPD-01..05 |
| T-04 | Modulo kernel non affidabile | Kmod firmato con chiave rubata | SEC-BOOT-01..04 |
| T-05 | Estensione o automazione malevola | Plugin che esfiltra file | SEC-EXT-01..05 |
| T-06 | Accesso remoto non autorizzato | Esposizione di OMNI Remote su Internet | SEC-REM-01..04 |
| T-07 | Furto o perdita del PC/SSD | Accesso offline al disco | SEC-DATA-01..03 |
| T-08 | Invio di dati al cloud senza consenso | Router AI che usa un modello remoto | SEC-AI-07, SEC-CLOUD-01..03 |

---

## 3. Installazione e protezione di Windows — SEC-INST

| ID | Requisito | Priorità |
|---|---|---|
| **SEC-INST-01** | **Durante la prima installazione fisica di OMNI OS l'SSD Windows deve essere fisicamente scollegato, se l'operazione può essere eseguita in sicurezza. Se lo scollegamento non è possibile in sicurezza, l'installazione NON deve procedere finché il proprietario non approva esplicitamente una diversa procedura di isolamento documentata.** | Obbligatorio — vincolante |
| SEC-INST-02 | L'installer identifica il disco di destinazione con almeno tre attributi (modello, numero di serie, capacità; più WWN/EUI se disponibili) e li mostra per conferma | Obbligatorio |
| SEC-INST-03 | L'installer rifiuta per default qualsiasi disco che contenga una partizione Windows/NTFS, una ESP con bootloader Microsoft o BitLocker, anche se selezionato | Obbligatorio |
| SEC-INST-04 | Le operazioni distruttive richiedono conferma esplicita digitando l'identificativo del disco (non un semplice "OK") | Obbligatorio |
| SEC-INST-05 | L'installer non scrive mai nella ESP di un altro disco; la ESP di OMNI è sull'SSD OMNI | Obbligatorio |
| SEC-INST-06 | L'AI dell'installer (decisione 29) è solo **consultiva**: non può selezionare né formattare dischi | Obbligatorio |
| SEC-INST-07 | Prima dell'installazione è verificato un backup di Windows recente e la chiave di recupero BitLocker è disponibile | Obbligatorio |

La procedura operativa è in [`procedura-prima-installazione.md`](procedura-prima-installazione.md).

### Nota sulla "diversa procedura di isolamento"

Se lo scollegamento fisico non fosse possibile (es. SSD M.2 sotto un
dissipatore difficile da rimuovere, rischio meccanico), alternative da
**proporre** al proprietario, nessuna delle quali è approvata:

1. Disattivare lo slot M.2 dell'SSD Windows nel firmware UEFI, se la scheda madre lo permette, verificando da un sistema live che il disco non sia più visibile.
2. Installazione da supporto che consente solo il disco identificato per numero di serie (filtro nell'installer) **più** verifica da sistema live che il disco Windows non compaia.
3. Rimozione dell'SSD Windows eseguita da un tecnico.

Ognuna richiede un'approvazione esplicita e scritta, registrata nel rapporto di milestone.

---

## 4. Agenti e assistente AI — SEC-AI

| ID | Requisito |
|---|---|
| SEC-AI-01 | Il motore AI gira come utente non privilegiato, confinato (sandbox systemd + SELinux); nessun accesso amministrativo generale (spec §3.4) |
| SEC-AI-02 | L'AI agisce solo tramite **strumenti dichiarati** con ambito, livello di rischio e politica di conferma; nessuna shell libera |
| SEC-AI-03 | Livelli di rischio: **R0** lettura; **R1** modifica reversibile nei percorsi autorizzati; **R2** modifica irreversibile o fuori ambito; **R3** privilegiata (sistema, dischi, rete, installazioni). R2 e R3 richiedono sempre conferma esplicita; R3 passa sempre da polkit |
| SEC-AI-04 | Le autorizzazioni sono configurabili dall'utente (decisione 9) ma **R3 non può essere reso automatico** |
| SEC-AI-05 | Nessun accesso a credenziali (portachiavi KWallet/Secret Service, `~/.ssh`, `~/.gnupg`, token dei browser) salvo concessione specifica e revocabile per singolo elemento |
| SEC-AI-06 | Il contenuto non affidabile (web, email, documenti, output di comandi) è trattato come **dati**: le istruzioni che contiene non diventano azioni senza conferma dell'utente |
| SEC-AI-07 | Nessun invio di dati al cloud senza consenso esplicito; il router mostra cosa verrà inviato e a quale servizio |
| SEC-AI-08 | Modifica di partizioni, formattazioni, cifratura: **vietate** agli agenti; solo l'utente tramite Storage Center/Installer |
| SEC-AI-09 | Eliminazione file: solo nei percorsi autorizzati, tramite cestino (reversibile) salvo conferma R2 |
| SEC-AI-10 | Installazione software: solo tramite Store/Update Center con conferma; mai software privilegiato senza polkit |
| SEC-AI-11 | Ogni chiamata a strumento è registrata (chi, cosa, quando, esito, origine della richiesta) in `omni-auditd` |
| SEC-AI-12 | Arresto immediato: un comando globale ferma tutti gli agenti e annulla le azioni in coda (decisione 41) |
| SEC-AI-13 | Il Terminal (decisione 49) mostra in anteprima il comando generato dall'AI e richiede conferma; segnala comandi distruttivi (`rm -rf`, `dd`, `mkfs`, `wipefs`, `chmod -R`, `curl \| sh`) |
| SEC-AI-14 | L'intero motore AI è disattivabile; il sistema resta pienamente utilizzabile (RF-03, RNF) |

Questi requisiti corrispondono alla lista "Test specifici di sicurezza AI" (spec §8).

---

## 5. Avvio e kernel — SEC-BOOT

| ID | Requisito |
|---|---|
| SEC-BOOT-01 | Obiettivo: Secure Boot attivo. L'opzione specifica (SB-A, SB-C, SB-D) **resta da decidere** (ADR-0004) |
| SEC-BOOT-02 | Le chiavi private di firma non sono mai nel repository (che è **pubblico**); custodia secondo §5.1 |
| SEC-BOOT-03 | Rotazione e revoca delle chiavi secondo §5.1, documentate e provate in VM prima di usare una chiave sul PC reale |
| SEC-BOOT-04 | Nessuna modifica alle chiavi del firmware (PK/KEK/db/dbx) senza approvazione esplicita (opzione SB-E esclusa) |
| SEC-BOOT-05 | Qualsiasi cambio di stato di Secure Boot o del firmware segue la procedura BitLocker (`procedura-prima-installazione.md`, parte F) |

### 5.1 Gestione delle chiavi di firma — SEC-KEY

> Questa sezione descrive i requisiti **indipendentemente** dalle scelte ancora
> aperte: firma delle immagini (ADR-0003, F1/F2) e opzione Secure Boot
> (ADR-0004). Se si scegliesse cosign "keyless" (F2) non esisterebbe una chiave
> privata cosign da custodire; se si scegliesse SB-C o SB-D non esisterebbe una
> chiave MOK di progetto. Nessuna di queste scelte è stata fatta.

#### Due chiavi diverse, due funzioni diverse

| | **Chiave cosign** (firma delle immagini) | **Chiave MOK** (firma dei moduli kernel) |
|---|---|---|
| Cosa protegge | L'immagine di sistema scaricata dal registry: il client accetta solo immagini firmate | I moduli kernel (es. NVIDIA): con Secure Boot attivo il kernel carica solo moduli firmati da chiavi fidate |
| Chi verifica | rpm-ostree/bootc tramite `containers-policy.json` (spazio utente, al momento dell'aggiornamento) | Il kernel Linux, tramite le chiavi caricate da shim/MOK (all'avvio e al caricamento del modulo) |
| Dove sta la parte pubblica | Nell'immagine, `/etc/pki/containers/` + policy | Nel firmware NVRAM come MOK, registrata con `mokutil --import` e confermata in MOK Manager |
| Tipo di chiave | Coppia cosign (formato sigstore), protetta da password | Certificato X.509 + chiave privata (es. RSA 2048/4096) per firmare i moduli |
| Se viene rubata | Un attaccante che controlla anche il registry può far accettare un'immagine malevola ai client | Un attaccante con accesso root al PC può caricare un modulo kernel malevolo nonostante Secure Boot |
| Come si ruota | Nuova immagine con due chiavi pubbliche → firma con la nuova → nuova immagine senza la vecchia | Registrazione della nuova MOK sul PC (presenza fisica in MOK Manager) → moduli firmati con la nuova → rimozione della vecchia |
| Come si revoca | Rimozione dalla policy in un'immagine nuova; ri-firma delle immagini valide | `mokutil --delete` della chiave; in caso di compromissione anche inserimento nella lista di esclusione MOKX (`mokutil --mokx --import`) [D] |

| ID | Requisito |
|---|---|
| SEC-KEY-01 | Le due chiavi sono **distinte**: mai la stessa chiave, mai la stessa password, segreti CI separati |
| SEC-KEY-02 | Ogni chiave è generata dal proprietario (o in sua presenza) su una macchina affidabile; Claude non genera, non riceve e non vede chiavi private o password |
| SEC-KEY-03 | Custodia primaria: segreto cifrato della CI, accessibile **solo** al job di firma |
| SEC-KEY-04 | I job di firma girano solo su `push` a `main`/tag approvati, **mai** su PR (in particolare mai su `pull_request_target` o PR da fork, possibili perché il repository è pubblico), con un *environment* GitHub protetto da approvazione del proprietario |
| SEC-KEY-05 | Copia di riserva offline: chiave privata cifrata su due supporti separati (es. due chiavette USB in luoghi diversi), password conservata separatamente dal supporto |
| SEC-KEY-06 | Opzione rafforzata da valutare: chiave MOK su token hardware (smart card/HSM) usato solo per firme manuali di release |
| SEC-KEY-07 | Inventario delle chiavi nel repository con **sole** informazioni pubbliche: impronta (fingerprint), data di creazione, scadenza prevista, stato (attiva/in rotazione/revocata) |
| SEC-KEY-08 | Rotazione programmata: almeno a ogni cambio di release Fedora per cosign, e alla scadenza del certificato per la MOK (validità proposta: 2–3 anni) |
| SEC-KEY-09 | Rotazione d'emergenza entro 24 ore dalla sospetta compromissione, con procedura §5.2 |
| SEC-KEY-10 | La rotazione MOK richiede un aggiornamento in due tempi: prima un'immagine che contiene moduli firmati con la vecchia chiave **e** la nuova chiave pubblica da registrare; solo dopo la registrazione della nuova un'immagine firmata solo con la nuova. Altrimenti il driver NVIDIA non si carica |
| SEC-KEY-11 | Prima di revocare una MOK, verificare che il deployment di rollback (R1/R2, ADR-0003) non dipenda ancora da quella chiave; in caso contrario il rollback avvierebbe senza driver NVIDIA |
| SEC-KEY-12 | Procedure di rotazione e revoca provate prima in VM con Secure Boot emulato (M1/M2), mai sperimentate per la prima volta sul PC reale |

#### 5.2 Procedura in caso di compromissione (sintesi)

1. Revocare subito il segreto nella CI e sospendere i job di firma.
2. **cosign:** pubblicare un'immagine firmata con una nuova chiave e senza la vecchia nella policy; ritirare dal canale `:stable` le immagini firmate dopo la data sospetta; verificare l'integrità del registry.
3. **MOK:** generare una nuova chiave; distribuire un'immagine di transizione (SEC-KEY-10); sul PC registrare la nuova MOK, poi cancellare la vecchia e, se compromessa, metterla in MOKX.
4. Verificare sul PC l'elenco delle chiavi registrate (`mokutil --list-enrolled`) e dei moduli caricati.
5. Annotare l'incidente nel registro dei rischi e nel rapporto di milestone.

## 6. Aggiornamenti — SEC-UPD

| ID | Requisito |
|---|---|
| SEC-UPD-01 | Le immagini `:testing` e `:stable` sono firmate; il client rifiuta immagini non firmate (ADR-0003) |
| SEC-UPD-02 | Immagine base Fedora fissata per digest |
| SEC-UPD-03 | SBOM generato a ogni build |
| SEC-UPD-04 | Il rollback è sempre disponibile (almeno un deployment precedente; un deployment fissato prima degli aggiornamenti importanti) |
| SEC-UPD-05 | Monitoraggio vulnerabilità delle dipendenze (CVE) a ogni build |

## 7. Dati — SEC-DATA

| ID | Requisito |
|---|---|
| SEC-DATA-01 | SSD OMNI cifrato con LUKS2 (proposta; sblocco TPM2 valutato dopo M3) |
| SEC-DATA-02 | Backup cifrati, con prova periodica di ripristino |
| SEC-DATA-03 | Memoria AI cifrata, ispezionabile ed eliminabile dall'utente (decisione 43) |

## 8. Estensioni e automazioni — SEC-EXT

| ID | Requisito |
|---|---|
| SEC-EXT-01 | Ogni estensione dichiara i permessi in un manifest; i permessi sono revocabili |
| SEC-EXT-02 | Estensioni e automazioni non affidabili girano isolate (Flatpak o sandbox equivalente) (RF-07) |
| SEC-EXT-03 | Verifica di provenienza (firma) delle estensioni |
| SEC-EXT-04 | Le capacità AI installabili (decisione 40) sono soggette agli stessi livelli R0–R3 |
| SEC-EXT-05 | Un'estensione non può aggiungere regole polkit |

## 9. Remoto e cloud — SEC-REM, SEC-CLOUD

| ID | Requisito |
|---|---|
| SEC-REM-01 | OMNI Remote disattivato per default |
| SEC-REM-02 | Connessioni cifrate e autenticate in modo forte (chiavi/2FA); nessuna esposizione diretta su Internet per default |
| SEC-REM-03 | Le azioni remote sugli agenti seguono gli stessi livelli R0–R3 |
| SEC-REM-04 | Registro delle sessioni remote |
| SEC-CLOUD-01 | OMNI Cloud facoltativo, nessun abbonamento obbligatorio |
| SEC-CLOUD-02 | Cifratura lato client dei backup prima dell'invio |
| SEC-CLOUD-03 | Elenco chiaro dei dati sincronizzati e possibilità di cancellarli |

## 10. Rete — SEC-NET

| ID | Requisito |
|---|---|
| SEC-NET-01 | Firewall attivo per default (firewalld), nessuna porta in ascolto non necessaria |
| SEC-NET-02 | Servizi OMNI in ascolto solo su socket locali salvo funzioni remote esplicitamente attivate |
