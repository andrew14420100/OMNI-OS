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
| SEC-BOOT-01 | Obiettivo: Secure Boot attivo (ADR-0004, opzione SB-A proposta) |
| SEC-BOOT-02 | Le chiavi private di firma (MOK, cosign) non sono mai nel repository; custodite nei segreti della CI o su token hardware; accesso solo al proprietario |
| SEC-BOOT-03 | Procedura di revoca e rotazione delle chiavi documentata prima della prima release pubblica |
| SEC-BOOT-04 | Nessuna modifica alle chiavi del firmware (PK/KEK/db) senza approvazione esplicita (opzione SB-E esclusa) |

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
