# OMNI OS — Specifiche funzionali e piano tecnico preliminare

> **Documento di riferimento principale (Regola operativa 1).**
> Questo file riproduce la versione 1.0 approvata dal proprietario del progetto.
> Non deve essere modificato senza approvazione esplicita; ogni variazione
> proposta va registrata come ADR o come nota di variazione evidenziata
> (Regola operativa 2).
>
> **Nota di stato (aggiunta, non parte del testo approvato):** il 5 novembre 2026
> il proprietario ha autorizzato la sola fase M0 (documentazione tecnica).
> M1 e le milestone successive non sono autorizzate. Le righe di stato sotto
> riportano il testo originale v1.0.

- **Versione documento:** 1.0 — Progettazione approvata
- **Data:** 5 novembre 2026
- **Stato:** 55 decisioni funzionali confermate
- **Sviluppo:** non ancora autorizzato
- **Obiettivo:** realizzare un sistema operativo autonomo, installabile su SSD dedicato, basato su Fedora Kinoite e ampliato con applicazioni, automazioni e intelligenza artificiale.

---

## 1. Visione del progetto

OMNI OS sarà un sistema operativo per PC x86-64, avviabile direttamente dal firmware UEFI, senza richiedere Windows per funzionare.

Non verrà creato un nuovo kernel: il progetto utilizzerà il kernel Linux e l'ambiente KDE Plasma come fondamenta, sviluppando progressivamente componenti, servizi e applicazioni originali.

### Principi fondamentali

- **Autonomia:** installazione e utilizzo indipendenti da Windows.
- **Local-first:** dati e funzioni essenziali disponibili localmente.
- **Multitasking:** più applicazioni, operazioni e agenti AI coordinati.
- **Controllo:** autorizzazioni esplicite per le operazioni sensibili.
- **Modularità:** componenti aggiornabili e sostituibili.
- **Sicurezza:** ripristino, isolamento delle applicazioni e protezione dei dati.
- **Compatibilità:** software Linux nativo, più applicazioni Windows compatibili.
- **Sostenibilità:** nessun abbonamento obbligatorio; servizi esterni opzionali.

### Hardware iniziale

| Componente | Hardware |
|---|---|
| Processore | AMD Ryzen 7 9800X3D |
| Scheda video | NVIDIA RTX 5070 Ti, 16 GB |
| RAM | 32 GB |
| Scheda madre | MSI B850A Gaming Plus WiFi |
| Monitor | ASUS ROG Strix XG32UCWMG, 4K |
| Sistema attuale | Windows 11 Pro |
| Installazione OMNI OS | SSD fisicamente separato |

La capacità dell'SSD dedicato, la configurazione UEFI/Secure Boot e gli altri dettagli delle periferiche restano da rilevare.

---

## 2. Registro completo delle 55 decisioni

### Fondamenta e interfaccia — Scelte 1–7

1. **Sistema operativo autonomo:** kernel Linux, avvio indipendente da Windows.
2. **Hardware iniziale:** compatibilità prioritaria con il computer del proprietario.
3. **Installazione:** SSD separato, mantenendo Windows intatto.
4. **Desktop ibrido:** base grafica affidabile con componenti originali sviluppati gradualmente.
5. **Identità grafica:** design ibrido adattivo, elegante, futuristico e produttivo.
6. **Desktop intelligente:** dock dinamico, widget e spazi di lavoro multipli.
7. **Multitasking ibrido completo:** gestione tradizionale, centro attività e assistente AI per operazioni parallele.

### Intelligenza artificiale, applicazioni e sicurezza — Scelte 8–17

8. **AI ibrida:** modelli locali gratuiti come modalità predefinita, cloud opzionale.
9. **Assistente avanzato:** autonomia controllata, autorizzazioni configurabili e conferme.
10. **Compatibilità software:** applicazioni Linux e programmi Windows compatibili tramite Wine/Proton.
11. **OMNI Store:** catalogo universale intelligente per installazioni e aggiornamenti.
12. **OMNI File Manager:** gestione professionale dei file con ricerca e organizzazione AI.
13. **OMNI Performance Center:** gestione intelligente di CPU, GPU, RAM e priorità.
14. **OMNI Security Center:** firewall, cifratura, isolamento, monitoraggio e protezione AI.
15. **OMNI Update Center:** aggiornamenti atomici e ritorno alle versioni precedenti.
16. **OMNI Identity:** profili multiutente, accesso sicuro e autenticazione compatibile.
17. **OMNI Search:** ricerca universale semantica con AI locale.

### Applicazioni e esperienza desktop — Scelte 18–27

18. **OMNI Media Suite:** riproduzione, editing e conversioni multimediali con AI.
19. **OMNI Browser:** navigazione, privacy, analisi delle pagine e automazioni autorizzate.
20. **OMNI Control Center:** notifiche, impostazioni rapide e gestione intelligente delle attività.
21. **OMNI Personalization:** personalizzazione totale con adattamento grafico facoltativo tramite AI.
22. **OMNI Window Manager:** tiling, layout, gruppi di finestre e organizzazione AI.
23. **OMNI Connect:** collegamento e sincronizzazione con dispositivi compatibili.
24. **OMNI Automation Studio:** automazioni visuali e agenti AI per procedure parallele.
25. **OMNI Developer Studio:** ambiente professionale di sviluppo con AI.
26. **OMNI Storage Center:** dischi, analisi spazio, backup cifrati e organizzazione intelligente.
27. **OMNI Network Center:** reti, VPN, monitoraggio e diagnostica assistita da AI.

### Installazione, hardware e produttività — Scelte 28–37

28. **OMNI System Doctor:** diagnostica e riparazione controllata assistita da AI.
29. **OMNI Installer:** installazione guidata con verifica hardware, AI consultiva e protezione dei dischi.
30. **OMNI Welcome Experience:** primo avvio e configurazione personalizzata con AI.
31. **OMNI Audio Center:** mixer, equalizzatore, routing e miglioramento audio AI.
32. **OMNI Gaming Hub:** libreria giochi, Proton, overlay, profili e diagnostica gaming.
33. **OMNI Voice:** assistente vocale intelligente con agenti AI e riconoscimento locale.
34. **OMNI Office Suite:** documenti, fogli di calcolo, presentazioni e PDF con AI.
35. **OMNI Productivity Hub:** email, calendari, note e attività con agenti AI.
36. **OMNI Communication Hub:** chat, riunioni, videochiamate e assistenza AI.
37. **OMNI Display Center:** 4K, HDR, VRR, colori e profili adattivi.

### Manutenzione, estensioni e controllo AI — Scelte 38–48

38. **OMNI Maintenance Center:** manutenzione predittiva e ottimizzazioni controllate.
39. **OMNI Accessibility:** funzioni assistive indipendenti dall'AI, più strumenti AI adattivi.
40. **OMNI Extensions:** ecosistema modulare con plugin, SDK, API e capacità AI installabili.
41. **OMNI AI Control:** centro di comando multi-agente, priorità, limiti risorse e supervisione.
42. **OMNI AI Model Center:** gestione adattiva dei modelli, VRAM, quantizzazione e priorità.
43. **OMNI AI Memory:** memoria locale evolutiva, controllabile e legata ai progetti.
44. **OMNI Remote:** accesso remoto sicuro, dashboard e supervisione degli agenti AI.
45. **OMNI Device Manager:** rilevamento hardware, driver e diagnostica intelligente.
46. **OMNI Power Center:** gestione energetica adattiva, sospensione e protezione dei lavori.
47. **OMNI Recovery:** ambiente di recupero indipendente con assistenza AI facoltativa.
48. **OMNI Cloud:** cloud ibrido opzionale, sincronizzazione e backup cifrati.

### Decisioni tecniche e metodo di sviluppo — Scelte 49–55

49. **OMNI Terminal:** terminale Linux con comandi tradizionali, linguaggio naturale, anteprime e controlli di sicurezza.
50. **Base Linux:** Fedora Kinoite, con KDE Plasma e aggiornamenti atomici.
51. **Architettura:** componenti nativi modulari, KDE/Wayland, Qt/QML, Rust, Python e isolamento delle applicazioni.
52. **Ordine di sviluppo:** progressivo, partendo da sistema avviabile, installazione, desktop e sicurezza.
53. **Gestione risorse:** bilanciamento adattivo CPU/GPU/RAM, priorità Gaming/AI e controllo manuale.
54. **Qualità:** test automatici, macchina virtuale, USB, SSD isolato, verifiche hardware, backup e rollback.
55. **Claude:** sviluppo organizzato per milestone, repository Git, agenti su attività indipendenti, test e revisione prima dell'integrazione.

**Esito:** tutte le 55 decisioni sono approvate come requisiti di prodotto. La loro implementazione sarà suddivisa in versioni e sottoposta a verifiche di fattibilità.

---

## 3. Architettura tecnica proposta

### 3.1 Livello sistema operativo

Base: Fedora Kinoite, partendo da una release ufficiale supportata e verificata.

Componenti previsti:

- Kernel Linux fornito da Fedora.
- Gestione atomica dei deployment tramite tecnologie Fedora OSTree/rpm-ostree.
- KDE Plasma e KWin/Wayland per il desktop.
- systemd per gestione dei servizi.
- Flatpak e portali desktop per applicazioni isolate.
- Toolbx/Podman per gli ambienti di sviluppo.
- Driver NVIDIA compatibili con la release selezionata.

OMNI OS non dovrà diventare una distribuzione totalmente separata dall'ecosistema Fedora finché non saranno disponibili procedure affidabili di compilazione, aggiornamento e manutenzione.

### 3.2 Livello interfaccia grafica

Tecnologie proposte: Qt 6 e QML per le interfacce originali.

Il desktop conserverà inizialmente le fondamenta KDE, personalizzando:

- Dock e pannelli.
- Launcher e ricerca.
- Widget.
- Centro notifiche.
- Centro attività.
- Schermate delle applicazioni OMNI.
- Layout e profili visivi.

Il compositor e i componenti critici di Plasma non verranno sostituiti prematuramente.

### 3.3 Servizi di sistema

Tecnologia proposta: Rust per i servizi di sistema che richiedono robustezza, interfacce tipizzate e gestione esplicita delle risorse.

I servizi esporranno API documentate e limitate, preferibilmente attraverso meccanismi standard Linux come D-Bus.

Le operazioni privilegiate saranno separate dalle applicazioni utente e protette da sistemi di autorizzazione, per esempio polkit.

### 3.4 Motore AI

Tecnologia proposta: Python per orchestrazione, integrazione dei modelli e automazioni, con backend locali di inferenza da selezionare dopo benchmark.

Sottosistemi:

1. Gestore dei modelli locali.
2. Router delle richieste AI.
3. Gestore delle attività e delle code.
4. Coordinatore multi-agente.
5. Gestore delle autorizzazioni.
6. Memoria locale e recupero contestuale.
7. Registro verificabile delle azioni.
8. Collegamenti cloud opzionali.

L'AI non dovrà avere accesso amministrativo generale al sistema.

### 3.5 Applicazioni

Le applicazioni verranno classificate in tre categorie:

- **Native OMNI:** interfacce e strumenti sviluppati per OMNI OS.
- **Integrate:** programmi open source esistenti, utilizzati secondo le rispettive licenze.
- **Compatibili:** applicazioni Linux o Windows eseguite attraverso strumenti appropriati.

Per Browser, Office, editing multimediale e altri strumenti complessi verranno preferiti motori già maturi, evitando riscritture integrali prive di benefici concreti.

---

## 4. Requisiti obbligatori

### Requisiti funzionali

- **RF-01 — Avvio autonomo:** OMNI OS deve poter avviarsi senza Windows.
- **RF-02 — Installazione dedicata:** l'installazione deve indirizzarsi esclusivamente all'SSD scelto e autorizzato.
- **RF-03 — Desktop utilizzabile:** login, desktop, applicazioni, file, rete e impostazioni devono funzionare senza AI.
- **RF-04 — Aggiornamenti e ripristino:** deve esistere una procedura verificata per ripristinare un deployment precedente.
- **RF-05 — Controllo delle autorizzazioni:** nessuna richiesta AI deve aggirare i permessi Linux.
- **RF-06 — Multitasking:** il sistema deve gestire attività concorrenti e consentire il controllo delle operazioni.
- **RF-07 — Isolamento:** estensioni e automazioni non affidabili devono essere sottoposte a restrizioni appropriate.
- **RF-08 — Funzionamento offline:** le funzioni di sistema essenziali devono rimanere disponibili senza Internet.
- **RF-09 — Compatibilità:** i programmi Windows devono essere trattati come compatibili soltanto dopo verifica, non per presunzione.
- **RF-10 — Accessibilità:** le funzioni assistive fondamentali non possono dipendere dall'AI.

### Requisiti non funzionali

- Avvio e utilizzo stabili.
- Interfaccia responsive e utilizzabile in 4K.
- Consumi CPU, GPU e RAM misurabili.
- Errori registrati con log diagnostici.
- Nessuna perdita di dati durante operazioni correttamente autorizzate e completate.
- Aggiornamenti riproducibili e verificabili.
- Sicurezza delle connessioni remote.
- Gestione trasparente delle autorizzazioni.
- Possibilità di disattivare i componenti AI.
- Documentazione di installazione, manutenzione e ripristino.

Le soglie numeriche di prestazioni andranno definite dopo la misurazione del sistema base.

---

## 5. Piano di sviluppo per Claude

Il piano è organizzato per dipendenze, non per date arbitrarie. Ogni milestone potrà iniziare soltanto quando la precedente avrà soddisfatto i criteri richiesti.

### M0 — Preparazione tecnica e documentazione

Obiettivo: trasformare le specifiche in documenti implementabili.

Attività: definire architettura dettagliata e interfacce dei moduli; elaborare i requisiti di sicurezza; definire struttura dei repository; preparare il catalogo delle dipendenze; stabilire i criteri di accettazione; analizzare le licenze dei componenti; preparare un registro dei rischi.

Verifica: ogni componente prioritario deve avere responsabilità, dipendenze, modalità di test e condizioni di completamento documentate.

### M1 — Base Linux avviabile in macchina virtuale

Obiettivo: validare Fedora Kinoite come fondamento di OMNI OS.

Attività: studiare la procedura di personalizzazione della base Fedora; preparare una build sperimentale isolata; verificare boot UEFI, desktop, login e rete; testare gestione degli aggiornamenti e rollback; verificare che l'ambiente sia ricostruibile.

Criterio di uscita: una base avviabile in VM, con aggiornamento e rollback dimostrati.

La configurazione NVIDIA reale non sarà considerata verificata dai soli test virtuali.

### M2 — Installer sicuro e recupero preliminare

Obiettivo: preparare le condizioni per prove fisiche sicure.

Attività: identificazione affidabile dei dischi; distinzione fra SSD OMNI e disco Windows; conferme esplicite prima delle operazioni distruttive; verifiche dei backup; preparazione di un supporto USB di emergenza; test di installazione e ripristino su dischi virtuali.

Criterio di uscita: test distruttivi superati esclusivamente su supporti di prova, senza modifiche a dischi non autorizzati.

### M3 — Compatibilità con il computer reale

Obiettivo: avviare la base di OMNI OS sull'hardware previsto.

Verificare: UEFI e Secure Boot; driver NVIDIA; output video e risoluzione 4K; frequenze di aggiornamento; Wi-Fi, Ethernet e Bluetooth; audio e microfoni; USB e periferiche essenziali; sospensione e riavvio; recupero in caso di mancato avvio.

Criterio di uscita: sistema stabile sul solo SSD OMNI, con avvio indipendente e Windows preservato.

HDR, VRR e funzionalità specialistiche non saranno automaticamente considerate supportate.

### M4 — Desktop OMNI

Obiettivo: costruire la prima esperienza grafica originale.

Funzionalità prioritarie: branding OMNI OS; tema adattivo chiaro/scuro; dock personalizzato; launcher; widget fondamentali; centro impostazioni; notifiche; gestione finestre; primi strumenti di personalizzazione.

Criterio di uscita: utilizzo quotidiano delle funzioni desktop fondamentali senza componenti AI obbligatori.

### M5 — Servizi di sistema e applicazioni fondamentali

Obiettivo: ottenere una piattaforma desktop praticamente utilizzabile.

Priorità: File Manager; Store; Terminale; Network Center; Device Manager; Storage Center; Performance Center; Security Center; Update Center; Backup e Recovery; Browser e applicazioni fondamentali.

Criterio di uscita: applicazioni di base, installazioni, aggiornamenti, rete, gestione file e recupero verificati.

### M6 — AI locale e integrazione desktop

Obiettivo: integrare il primo assistente AI realmente utilizzabile.

Attività: runtime locale; gestione dei modelli; benchmark CPU/GPU/RAM; interfaccia conversazionale; funzioni AI di sola lettura; ricerca semantica; gestione della memoria autorizzata; primo sistema di autorizzazioni per le azioni.

Criterio di uscita: l'assistente risponde offline e usa strumenti limitati senza poter compiere modifiche non autorizzate.

### M7 — Agenti AI e automazioni

Obiettivo: introdurre il multitasking intelligente autonomo.

Componenti: coordinatore centrale degli agenti; code e dipendenze; gestione priorità; limiti di risorse; editor visuale delle automazioni; attività programmate; log e cronologia; arresto e recupero degli errori; autorizzazioni sulle azioni sensibili.

Criterio di uscita: più compiti vengono coordinati correttamente, rispettando i permessi e senza compromettere i dati.

### M8 — Funzionalità avanzate e integrazioni

Obiettivo: estendere il sistema agli strumenti specialistici già approvati.

Gruppi: Gaming e compatibilità Wine/Proton; Media Suite; Office Suite; Voice e Communication Hub; Productivity Hub; Developer Studio; Cloud e sincronizzazione; Remote; Connect; Extensions; funzioni AI avanzate per ogni applicazione.

I singoli gruppi possono essere realizzati in sottoprogetti indipendenti, secondo maturità e dipendenze.

Criterio di uscita: ogni modulo dispone di test, documentazione, gestione degli errori e integrazione con la sicurezza del sistema.

### M9 — Consolidamento e distribuzione

Obiettivo: preparare una release OMNI OS utilizzabile e manutenibile.

Attività: test completi su hardware reale; test di regressione; verifiche degli aggiornamenti; verifiche di sicurezza; controllo delle licenze; documentazione; versionamento; build riproducibili; immagine d'installazione; procedure di recovery e supporto.

Criterio di uscita: rilascio approvato sulla base di test reali, con limitazioni note e documentate.

---

## 6. Dipendenze principali

| Componente | Prerequisiti |
|---|---|
| OMNI Installer | Base Fedora, gestione dischi, UEFI, backup e sicurezza |
| OMNI Recovery | Base avviabile, deployment, accesso cifrato ai dati |
| OMNI Window Manager | KDE Plasma, Wayland e componenti grafici |
| OMNI Store | Gestione pacchetti, Flatpak, fonti e permessi |
| OMNI AI Model Center | Driver GPU, runtime locale, benchmark risorse |
| OMNI AI Control | Modelli, task manager, registro eventi, permessi |
| OMNI Automation Studio | Agenti, strumenti autorizzati, scheduler |
| OMNI Voice | Modelli vocali, audio, autorizzazioni |
| OMNI Remote | Identità, rete, cifratura, controllo accessi |
| OMNI Cloud | Identità, storage, cifratura, sincronizzazione |
| OMNI Gaming Hub | Driver NVIDIA, Wine/Proton e monitor prestazioni |
| OMNI Extensions | API stabili, isolamento, controllo delle autorizzazioni |

Una funzionalità avanzata non deve ritardare il rilascio di una versione di base già funzionante, salvo che costituisca una dipendenza di sicurezza indispensabile.

---

## 7. Rischi tecnici e mitigazioni

| Rischio | Mitigazione prevista |
|---|---|
| Ampiezza delle 55 funzionalità | Implementazione progressiva, moduli indipendenti e criteri di priorità |
| Compatibilità NVIDIA | Test sulla release scelta, verifica dei driver e della firma dei moduli |
| Secure Boot e avvio UEFI | Analisi preventiva, recupero offline e gestione controllata delle chiavi |
| Modifica accidentale di Windows | SSD dedicato, identificazione dischi e prove iniziali con Windows scollegato quando possibile |
| Problemi HDR/VRR | Test specifici su monitor e collegamento reali, profili di fallback |
| Giochi incompatibili con Linux | Matrice per singolo gioco e launcher; nessuna garanzia universale |
| Esaurimento VRAM | Pianificazione dei modelli, limiti risorse e caricamento dinamico |
| Errori degli agenti AI | Permessi minimi, ambienti isolati, conferme e audit |
| Ripristino incompleto | Backup indipendenti, prove reali di recupero e rollback |
| Vulnerabilità delle estensioni | Verifica provenienza, isolamento e permessi revocabili |
| API esterne e servizi cloud | Integrazioni facoltative e modalità offline |
| Manutenzione delle dipendenze | Aggiornamenti programmati e monitoraggio delle vulnerabilità |
| Licenze e redistribuzione | Verifiche di software libero, componenti proprietari, marchi e obblighi di distribuzione |

---

## 8. Strategia di test e accettazione

### Test automatici

Test unitari dei moduli; test di integrazione delle API; test di regressione della GUI; analisi statica e controlli delle dipendenze; test del gestore degli aggiornamenti; test dei permessi degli agenti; test delle operazioni sui file; test di recupero dopo interruzioni simulate.

### Test in macchina virtuale

Avvio UEFI; installazione su dischi virtuali; simulazione di dischi non autorizzati; aggiornamento e rollback; cifratura e sblocco del sistema; recupero dopo errori di avvio; compatibilità delle applicazioni non dipendenti da hardware specifico.

### Test su hardware reale

Avvio dall'SSD dedicato; integrità e avviabilità di Windows; driver NVIDIA; display 4K e modalità compatibili; audio e periferiche; networking; gaming; risorse durante AI e gaming simultanei; sospensione, riavvio e ripristino.

### Test specifici di sicurezza AI

Gli agenti non devono poter:

- Accedere a credenziali non autorizzate.
- Modificare partizioni senza consenso.
- Eliminare file personali fuori dalle autorizzazioni.
- Installare software privilegiato aggirando i controlli.
- Eseguire automaticamente comandi dannosi provenienti da contenuti non affidabili.
- Inviare informazioni al cloud senza autorizzazione.

Per ogni milestone saranno conservati risultati, problemi rilevati e test di regressione.

---

## 9. Regole operative per Claude

1. Utilizzare le specifiche approvate come riferimento principale.
2. Non modificare i requisiti senza evidenziare la variazione.
3. Procedere per milestone verificabili.
4. Distinguere implementazione, test e semplice proposta.
5. Non dichiarare funzionante un componente che non è stato realmente verificato.
6. Utilizzare agenti paralleli soltanto per compiti indipendenti.
7. Coordinare gli interventi su file e moduli condivisi.
8. Sottoporre le integrazioni a revisione e test.
9. Non introdurre servizi a pagamento obbligatori.
10. Non sostituire Windows e non alterare il suo SSD.
11. Non promettere supporto hardware privo di riscontro.
12. Documentare i limiti delle integrazioni esterne.
13. Predisporre procedure di rollback e recupero.
14. Segnalare le decisioni che richiedono l'intervento o l'approvazione dell'utente.
15. Mantenere separati codice sperimentale, versione di test e release stabile.

Ogni milestone dovrà produrre un rapporto contenente stato, componenti realizzati, test eseguiti, risultati, problemi aperti e criteri di accettazione.

---

## 10. Definizione delle versioni

| Versione proposta | Obiettivo |
|---|---|
| OMNI OS 0.1 — Base | Sistema avviabile e testato in ambiente virtuale |
| OMNI OS 0.2 — Hardware Alpha | Avvio su SSD dedicato e driver fondamentali |
| OMNI OS 0.3 — Desktop Alpha | Prima interfaccia OMNI originale |
| OMNI OS 0.4 — Core Beta | Applicazioni fondamentali, aggiornamenti, sicurezza e recupero |
| OMNI OS 0.5 — AI Beta | Assistente locale, ricerca e controllo dei modelli |
| OMNI OS 0.6 — Agents Beta | Automazioni e coordinamento multi-agente |
| OMNI OS 0.7–0.9 | Estensioni, gaming, multimedia, produttività e integrazioni |
| OMNI OS 1.0 | Prima release stabile con un insieme di funzionalità dichiarato e verificato |

La numerazione non costituisce una promessa che tutte le funzioni saranno presenti nella versione 1.0. Alcuni moduli potrebbero richiedere ulteriori release.

---

## 11. Condizioni prima del primo sviluppo

Prima della milestone M1 dovranno essere raccolti o verificati:

- Capacità e identificativo dell'SSD destinato a OMNI OS.
- Stato Secure Boot e impostazioni UEFI.
- Schema degli SSD attualmente presenti.
- Situazione dei backup Windows.
- Identificativi delle periferiche principali.
- Compatibilità preliminare NVIDIA con Fedora selezionata.
- Tecnica scelta per costruire e distribuire l'immagine personalizzata.
- Strategia per aggiornamenti, firma delle immagini e ripristino.
- Licenze applicabili ai componenti distribuiti.
- Requisiti di compatibilità per i giochi e programmi prioritari.

Queste verifiche sono preliminari: non autorizzano modifiche al computer o al repository.

---

## 12. Decisione conclusiva

- **Stato delle specifiche funzionali:** approvato.
- **Stato del piano tecnico:** proposta preliminare, da sottoporre a revisione prima dell'implementazione.
- **Stato dello sviluppo con Claude:** non iniziato.

OMNI OS dovrà essere sviluppato come un sistema operativo realmente utilizzabile, non come una semplice interfaccia dimostrativa.

La priorità assoluta sarà ottenere una base indipendente, stabile, sicura e ripristinabile. L'intelligenza artificiale, le automazioni e le applicazioni avanzate verranno introdotte progressivamente, senza compromettere i componenti fondamentali.

Prossimo passaggio autorizzabile separatamente: predisporre il pacchetto di specifiche tecniche di M0 per Claude, prima di qualunque modifica al repository o generazione di codice operativo.
