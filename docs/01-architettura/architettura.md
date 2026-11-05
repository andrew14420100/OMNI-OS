# Architettura tecnica dettagliata — OMNI OS (M0)

- **Stato:** proposta M0, da revisionare. Nessun componente è implementato o verificato.
- **Riferimento:** [`../00-specifiche/specifiche-funzionali-v1.0.md`](../00-specifiche/specifiche-funzionali-v1.0.md), §3.
- **Decisioni correlate:** ADR-0002 (base), ADR-0003 (immagini e aggiornamenti), ADR-0004 (NVIDIA e Secure Boot), ADR-0006 (linguaggi e IPC).

> Convenzione (Regola operativa 4): **[P]** = proposta, **[V]** = verificato con fonte,
> **[D]** = da verificare sperimentalmente in una milestone successiva.

---

## 1. Vista a livelli

```
┌─────────────────────────────────────────────────────────────────────┐
│ L5  Applicazioni OMNI (Qt 6/QML, Flatpak dove possibile)            │
│     File Manager, Store, Terminal, Centri (Network, Storage, ...),  │
│     Suite (Media, Office, Productivity, Communication), Gaming Hub  │
├─────────────────────────────────────────────────────────────────────┤
│ L4  Shell desktop OMNI (plasmoid/QML su KDE Plasma, KWin/Wayland)   │
│     Dock, launcher, widget, Control Center, centro attività, tema   │
├─────────────────────────────────────────────────────────────────────┤
│ L3  Motore AI (Python, utente non privilegiato, sandbox)            │
│     Model Center, Router, Task queue, Agenti, Memory, Audit log     │
├─────────────────────────────────────────────────────────────────────┤
│ L2  Servizi di sistema OMNI (Rust, systemd, D-Bus, polkit)          │
│     omni-updated, omni-storaged, omni-perfd, omni-powerd,           │
│     omni-deviced, omni-securityd, omni-netd (wrapper), omni-auditd  │
├─────────────────────────────────────────────────────────────────────┤
│ L1  Base Fedora Atomic (Kinoite): kernel, systemd, ostree/bootc,    │
│     NetworkManager, PipeWire, Flatpak, Podman/Toolbx, firewalld,    │
│     driver NVIDIA open (kmod firmato), SELinux                      │
├─────────────────────────────────────────────────────────────────────┤
│ L0  Firmware UEFI, Secure Boot (shim + MOK), SSD OMNI dedicato      │
└─────────────────────────────────────────────────────────────────────┘
```

Regola strutturale: ogni livello usa solo interfacce pubbliche del livello
inferiore. **L3 (AI) non ha accesso diretto a L1**: passa sempre da API L2
mediate da polkit e dal gestore autorizzazioni (RF-05).

---

## 2. Livello L0–L1: base del sistema

| Elemento | Scelta proposta | Stato |
|---|---|---|
| Base | Fedora Kinoite (ufficiale o derivato Universal Blue: vedi ADR-0002) | [P] |
| Formato del sistema | Immagine OCI "bootable container" costruita da `Containerfile` | [P] — ADR-0003 |
| Deployment | ostree (A/B deployment, rollback) gestito da rpm-ostree e/o bootc | [P] — ADR-0003 |
| Kernel | Kernel Fedora senza modifiche | [P] |
| GPU | Moduli kernel NVIDIA **open** (obbligatori per Blackwell) | [V] README NVIDIA — ADR-0004 |
| Secure Boot | shim Fedora + chiave MOK di progetto per firmare i kmod | [P] — ADR-0004 |
| Isolamento app | Flatpak + portali XDG; SELinux enforcing | [P] |
| Sviluppo | Toolbx/Podman | [P] |
| Cifratura | LUKS2 sull'SSD OMNI (sblocco con passphrase; TPM2 valutato dopo M3) | [P] |

**Vincolo:** il sistema deve restare utilizzabile con tutto L3 disattivato
(RF-03, RF-08, RF-10).

---

## 3. Livello L2: servizi di sistema

Tutti i servizi sono:

- scritti in Rust [P], gestiti da systemd con hardening (`ProtectSystem=`,
  `NoNewPrivileges=`, `CapabilityBoundingSet=` minimo, `SystemCallFilter=`);
- esposti su **D-Bus di sistema** con interfacce versionate (`org.omnios.<Servizio>1`);
- autorizzati tramite **polkit**, con azioni separate per ogni operazione sensibile;
- registrati in journald e nel registro di audit (`omni-auditd`).

| Servizio | Responsabilità | Decisioni | Operazioni privilegiate (polkit) |
|---|---|---|---|
| `omni-updated` | Stato deployment, upgrade, rollback, pin | 15, 47 | `org.omnios.Update1.upgrade`, `.rollback` |
| `omni-storaged` | Wrapper su UDisks2: inventario dischi, analisi spazio, backup | 26, 29 | `.format`, `.mount`, `.backup` |
| `omni-perfd` | Profili CPU/GPU/RAM, priorità Gaming/AI, limiti cgroup | 13, 53 | `.set-profile` |
| `omni-powerd` | Profili energetici (su power-profiles-daemon), inibizione sospensione per lavori in corso | 46 | `.inhibit` |
| `omni-deviced` | Inventario hardware, stato driver, diagnostica | 45, 28 | sola lettura salvo `.reload-driver` |
| `omni-securityd` | Stato firewall, SELinux, cifratura, Secure Boot; politiche estensioni | 14, 40 | `.set-firewall-zone` |
| `omni-netd` | Facciata su NetworkManager per diagnostica e VPN | 27 | delega a polkit di NetworkManager |
| `omni-auditd` | Registro verificabile (append-only, con catena di hash) di azioni utente/AI | 41, 9 | sola scrittura dai servizi |

I servizi **non reimplementano** funzioni già fornite da componenti maturi
(NetworkManager, UDisks2, firewalld, power-profiles-daemon, PipeWire): le
espongono con politiche OMNI.

---

## 4. Livello L3: motore AI

Processo `omni-ai` in sessione utente, non privilegiato, confinato
(systemd user unit con sandbox + profilo SELinux dedicato [D]).

| Sottosistema (spec §3.4) | Funzione | Note |
|---|---|---|
| 1. Gestore modelli | Download, verifica hash, quantizzazione, caricamento/scaricamento | Budget VRAM da `omni-perfd` (decisioni 42, 53) |
| 2. Router richieste | Scelta locale/cloud; default **solo locale** | Il cloud richiede consenso esplicito (decisione 8, 48) |
| 3. Task manager e code | Code con priorità, dipendenze, annullamento | Decisioni 7, 41 |
| 4. Coordinatore multi-agente | Esecuzione agenti con limiti tempo/risorse | Decisioni 24, 41 |
| 5. Gestore autorizzazioni | Capability per strumento; conferma utente per azioni sensibili | Vedi `../03-sicurezza/requisiti-sicurezza.md` §4 |
| 6. Memoria locale | Archivio cifrato per progetto, ispezionabile ed eliminabile | Decisione 43 |
| 7. Registro azioni | Ogni chiamata a strumento scritta in `omni-auditd` | Decisione 41 |
| 8. Connettori cloud | Moduli opzionali, disattivati di default | Sostenibilità: nessun servizio a pagamento obbligatorio |

**Modello di strumenti:** l'AI non esegue comandi arbitrari. Invoca *strumenti*
dichiarati (es. `files.read`, `files.move`, `update.status`), ognuno con:
ambito (percorsi, servizi), livello di rischio (lettura / modifica reversibile /
modifica irreversibile / rete esterna) e politica di conferma. Gli strumenti
che modificano il sistema chiamano le API L2 **con l'identità dell'utente**,
quindi polkit applica gli stessi controlli di un'azione manuale.

Backend di inferenza: da scegliere in M6 dopo i benchmark
(`../07-verifiche/piano-benchmark-gaming-ai.md`). Candidati da valutare:
llama.cpp, vLLM, Ollama, whisper.cpp (voce). [P]

---

## 5. Livello L4: shell desktop

- Base: KDE Plasma 6 + KWin Wayland, **senza sostituire il compositor** (spec §3.2).
- Componenti OMNI come plasmoid QML, temi Plasma (Look-and-Feel), script/effetti KWin.
- Dock, launcher, widget, Control Center, centro attività: QML + backend D-Bus.
- Window Manager OMNI (decisione 22): script/effetti KWin per tiling e gruppi,
  **non** un compositor nuovo.
- Accessibilità (decisione 39, RF-10): si usano gli strumenti di Plasma/Qt
  (Orca, AT-SPI, zoom, contrasto) e ogni componente OMNI deve esporre
  l'albero di accessibilità Qt. Nessuna funzione assistiva fondamentale
  richiede L3.

---

## 6. Livello L5: applicazioni

Classificazione (spec §3.5): **Native OMNI**, **Integrate**, **Compatibili**.
Mappatura proposta in [`tracciabilita-decisioni.md`](tracciabilita-decisioni.md).
Le applicazioni complesse (Browser, Office, editing multimediale) integrano
motori maturi (es. Firefox/Chromium, LibreOffice, Kdenlive/FFmpeg) invece di
riscriverli [P].

---

## 7. Interfacce e convenzioni

| Aspetto | Convenzione proposta |
|---|---|
| Nomi D-Bus | `org.omnios.<Nome>1`, versione nel nome dell'interfaccia |
| Oggetti | `/org/omnios/<Nome>` |
| Azioni polkit | `org.omnios.<servizio>.<azione>` |
| Errori | `org.omnios.Error.<Tipo>` con messaggio leggibile e codice |
| Log | journald, campi strutturati `OMNI_COMPONENT=`, `OMNI_ACTION_ID=` |
| Configurazione | `/usr/share/omni/` (default nell'immagine), `/etc/omni/` (sistema), `~/.config/omni/` (utente) |
| Dati AI | `~/.local/share/omni/ai/` cifrati; mai in `/usr` |
| Versioni API | Semver; un'API rimossa richiede un ADR |

---

## 8. Componenti prioritari: responsabilità, dipendenze, test, completamento

Criterio di verifica M0: ogni componente prioritario ha queste quattro voci.
Priorità = componenti di M1–M5 (decisione 52).

| Componente | Responsabilità | Dipende da | Modalità di test | Condizione di completamento |
|---|---|---|---|---|
| Immagine base OMNI | Kinoite + personalizzazioni, ricostruibile | ADR-0002/0003 | Build CI, boot in VM UEFI (QEMU/OVMF), test di upgrade/rollback | Criteri M1 (`../08-accettazione/criteri-accettazione.md`) |
| Firma immagine | Provenienza verificabile | cosign/sigstore, registry | Rifiuto di un'immagine non firmata in VM | Policy `containers-policy.json` applicata e testata |
| Driver NVIDIA | kmod open firmato nell'immagine | ADR-0004, MOK | Solo hardware reale (M3) | Driver caricato con Secure Boot attivo, 4K OK |
| OMNI Installer | Installazione solo sul disco autorizzato | Anaconda/bootc-image-builder, UDisks2 | VM con dischi esca, test distruttivi solo su dischi di prova | Criteri M2 |
| OMNI Recovery | Avvio di emergenza, rollback, accesso ai dati cifrati | ostree, USB live | VM: deployment rotto → ripristino | Criteri M2/M3 |
| Shell desktop | Dock, launcher, widget, notifiche | Plasma 6 | Test QML, screenshot di regressione, 4K | Criteri M4 |
| `omni-updated` | Upgrade/rollback con UI | rpm-ostree/bootc D-Bus | Integrazione in VM | Rollback da UI dimostrato |
| `omni-storaged` | Dischi e backup | UDisks2 | Dischi virtuali | Backup cifrato + ripristino verificato |
| `omni-securityd` | Stato sicurezza | firewalld, SELinux | Integrazione | Stato coerente con `firewall-cmd`/`getenforce` |
| `omni-perfd` | Profili risorse | cgroup v2, NVIDIA NVML | Benchmark M6 | Profili Gaming/AI misurati |
| File Manager, Store, Terminal | App fondamentali | Dolphin/KIO, Flatpak, Konsole (base iniziale) [P] | Test funzionali | Criteri M5 |

I componenti M6–M8 (AI, agenti, suite) sono descritti a livello di
responsabilità nella tracciabilità e avranno questa tabella completata prima
del rispettivo avvio.
