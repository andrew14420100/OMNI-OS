# ADR-0004 — Driver NVIDIA open, Secure Boot e firma dei moduli

- **Stato:** Proposto — **la scelta dell'opzione Secure Boot spetta al proprietario**
- **Data:** 2026-11-05
- **Decisioni approvate correlate:** 2, 32, 37, 42, 45, 53
- **Requisiti correlati:** RF-01, Regola operativa 10, 11

> Nessuna affermazione di questo documento vale come supporto hardware
> verificato (Regola 11). Il funzionamento sulla RTX 5070 Ti sarà dichiarato
> solo dopo i test di M3 sull'hardware reale.

## 1. Requisiti dei driver per la RTX 5070 Ti

### Fatti verificati nella documentazione ufficiale NVIDIA

| Fatto | Fonte |
|---|---|
| "The proprietary flavor supports GPU architectures Turing, Ampere, Ada, and Hopper. **Blackwell and later are only supported by the open kernel modules.**" | README driver NVIDIA 595.84, capitolo *kernel_open* |
| La RTX 5070 Ti è un'architettura Blackwell (serie GeForce RTX 50) | Comunicazioni NVIDIA sulla serie RTX 50 [conoscenza generale; confermare il device ID nell'appendice "Supported NVIDIA GPU Products" del README della versione scelta] |
| Le due varianti di moduli (open e proprietaria) si escludono a vicenda | README 595.84 |
| NVIDIA raccomanda i moduli open su tutte le GPU che li supportano | README 595.84 |
| Limiti noti dei moduli open: inizializzazione GPU più lenta (mitigabile con `nvidia-persistenced`), transizioni di stato energetico (S3, S4, RTD3) più lunghe, consumo leggermente maggiore in alcuni casi | README 595.84 |
| Verifica del tipo di modulo installato: `modinfo nvidia \| grep license` → "Dual MIT/GPL" (open); `/proc/driver/nvidia/version` → "Open Kernel Module" | README 595.84 |
| Il blog tecnico NVIDIA (2024) indica che per Blackwell i moduli open sono obbligatori e i proprietari non supportati | NVIDIA Developer Blog, "NVIDIA Transitions Fully Towards Open-Source GPU Kernel Modules" |
| Il README del driver **non** tratta Secure Boot né la firma dei moduli | README 595.84 |

### Fatti dalla documentazione RPM Fusion (fonte primaria per Fedora)

| Fatto | Fonte |
|---|---|
| Serie 595+ predefinita su Fedora 44 e successive (ha rimosso il supporto alle GPU precedenti a Pascal) | `rpmfusion.org/Howto/NVIDIA` |
| `kmod-nvidia` usa per default un modulo **open** precompilato; `akmod-nvidia-open` (compilazione da sorgente) è nel repository *tainted* e non va usato di default | `rpmfusion.org/Howto/NVIDIA` |
| Con Secure Boot attivo bisogna disattivarlo o registrare una propria chiave **prima** di installare il kmod, altrimenti il driver non si carica (possibile schermo nero) | `rpmfusion.org/Howto/NVIDIA` |
| Su sistemi OSTree serve un pacchetto chiave separato per la firma; servono argomenti kernel che disattivino `nouveau` (e `nova_core`) | `rpmfusion.org/Howto/NVIDIA` |
| Procedura chiave locale: `kmodgenca -a`, `mokutil --import /etc/pki/akmods/certs/public_key.der`, conferma in MOK Manager al riavvio; la chiave privata in `/etc/pki/akmods` richiede **disco cifrato** o archiviazione esterna; dopo un aggiornamento BIOS può servire reimportare la chiave; la tastiera di MOK Manager usa la mappatura QWERTY | `rpmfusion.org/Howto/Secure Boot` |

### Segnalazioni comunitarie (non ufficiali, da considerare come rischio)

- Forum NVIDIA: errori Xid 79/119 e blocchi in idle su RTX 5070 Ti con driver 580.159.03 open.
- Forum NVIDIA: con kernel 6.17 + driver 580 alcuni utenti di RTX 5080 non vedevano i nodi DRM.
- Rapporto utente "NVIDIA on Fedora KDE Wayland in 2026" con RTX 5070 su driver 595.

Conclusione: la versione del driver va **scelta e fissata** insieme alla
versione del kernel e verificata in M3; "più recente" non significa
automaticamente "più stabile".

### Requisiti per OMNI OS (proposti)

| ID | Requisito |
|---|---|
| NV-01 | Usare esclusivamente i moduli kernel NVIDIA **open** |
| NV-02 | Serie driver: quella predefinita in RPM Fusion per la release Fedora scelta (oggi 595+), con versione esatta fissata nell'immagine |
| NV-03 | Verificare che il device ID della RTX 5070 Ti compaia nell'elenco GPU supportate del README della versione fissata |
| NV-04 | Moduli compilati **nella build dell'immagine** per il kernel esatto dell'immagine, non sul PC |
| NV-05 | Argomenti kernel: blacklist `nouveau` e `nova_core`; parametri `nvidia-drm` da confermare sulla versione scelta |
| NV-06 | Includere `nvidia-persistenced` e verificare sospensione/ripresa (limite noto dei moduli open) |
| NV-07 | La CI rifiuta di pubblicare un'immagine se il kmod NVIDIA non è stato compilato e firmato per il kernel contenuto |
| NV-08 | Fallback documentato: avvio con driver `nouveau`/framebuffer in modalità ridotta per diagnosi |

## 2. Secure Boot: opzioni

Contesto: Fedora avvia con Secure Boot tramite `shim` firmato Microsoft e kernel
firmato Fedora. I moduli NVIDIA, compilati fuori da Fedora, devono essere
firmati con una chiave che il sistema considera affidabile, tipicamente una
**MOK** (Machine Owner Key) registrata tramite `mokutil` e MOK Manager.

**Attenzione — firmware condiviso con Windows:** il firmware UEFI è unico per
tutto il PC. Disattivare Secure Boot o cambiare le chiavi del firmware
modifica anche l'ambiente di avvio di Windows. Se Windows usa BitLocker con
TPM, un cambio di stato di Secure Boot **può** chiedere la chiave di recupero
BitLocker. Alcuni giochi Windows con anti-cheat richiedono Secure Boot attivo.
La registrazione di una MOK non modifica le chiavi del firmware (db), ma va
comunque verificato su questo PC prima di procedere.

| Opzione | Descrizione | Vantaggi | Svantaggi |
|---|---|---|---|
| **SB-A — Secure Boot attivo, chiave MOK di progetto OMNI** | Kmod compilati e firmati nella CI con chiave privata OMNI; chiave pubblica nell'immagine; registrazione una tantum con `mokutil` | Secure Boot resta attivo per Windows e OMNI; nessuna chiave privata sul PC; build riproducibili | Chi possiede la chiave privata può firmare moduli kernel accettati dal PC: va custodita con cura (segreto CI, eventualmente token hardware) |
| **SB-B — Secure Boot attivo, chiave MOK locale (akmods sul PC)** | Procedura RPM Fusion: chiave generata sul PC, moduli compilati sul PC | Chiave mai fuori dal PC | Richiede layering lato client e compilazione sul PC (contrario ad ADR-0003); chiave privata sul disco (serve cifratura) |
| **SB-C — Secure Boot attivo, chiave Universal Blue** | Si usano kmod già firmati da Universal Blue e la loro chiave pubblica (password di registrazione `universalblue`) | Nessuna gestione di chiavi | Il PC si fida dei moduli firmati da un terzo; dipendenza da ADR-0002 opzione B |
| **SB-D — Secure Boot disattivato** | Nessuna firma richiesta | Massima semplicità | Riduce la sicurezza anche per Windows; possibile richiesta chiave BitLocker; anti-cheat di alcuni giochi Windows non funzionanti |
| SB-E — Chiavi firmware personalizzate (sbctl, db proprio) | Sostituisce/integra le chiavi del firmware | Controllo totale | Rischio elevato di rendere non avviabile Windows o il PC, rischio con firmware di periferiche (Option ROM GPU); **sconsigliata** |

## 3. Proposta

- **SB-A** come configurazione obiettivo (coerente con ADR-0002 opzione C e ADR-0003).
- **SB-C** accettabile solo se il proprietario sceglie Universal Blue come base o come banco di prova in M3.
- **SB-D** solo come misura diagnostica temporanea, con approvazione esplicita e dopo aver verificato chiave di recupero BitLocker e impatti su Windows.
- **SB-E** esclusa.

## 4. Procedura proposta (da eseguire solo in M3, previa autorizzazione)

1. Prima di toccare il firmware: annotare impostazioni UEFI attuali (foto), stato Secure Boot (`msinfo32` su Windows), verificare di avere la **chiave di recupero BitLocker** di Windows.
2. Lasciare Secure Boot attivo in modalità standard.
3. Primo avvio di OMNI dall'SSD dedicato (con SSD Windows scollegato, SEC-INST-01).
4. `mokutil --import` della chiave pubblica OMNI; conferma in MOK Manager (password temporanea, tastiera QWERTY).
5. Verifiche: `mokutil --sb-state`, `mokutil --test-key`, caricamento del modulo, `modinfo nvidia`, `nvidia-smi`.
6. Ricollegare l'SSD Windows e verificare che Windows avvii con Secure Boot attivo e senza richiesta BitLocker.

## 5. Verifiche richieste

| Verifica | Milestone |
|---|---|
| Device ID 5070 Ti nell'elenco del README della versione scelta | Prima di M1 (documentale) |
| Disponibilità pacchetti RPM Fusion per Fedora 45 e compatibilità con il suo kernel | Prima di M1 (documentale) |
| Compilazione e firma kmod in CI | Fine M1 / prima di M3 |
| Caricamento driver con Secure Boot attivo, 4K, refresh, sospensione | M3 (hardware reale) |

## Decisione del proprietario

_In attesa. Scelta richiesta: SB-A (proposta), SB-C, SB-D._
