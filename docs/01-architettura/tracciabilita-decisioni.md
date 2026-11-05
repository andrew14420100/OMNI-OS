# Matrice di tracciabilità delle 55 decisioni

- **Stato:** proposta M0. Le 55 decisioni sono **mantenute integralmente**; questa
  matrice non ne modifica alcuna, ne assegna soltanto livello, categoria,
  milestone e dipendenze.
- **Legenda livello:** L0–L5 come in [`architettura.md`](architettura.md).
- **Legenda categoria (spec §3.5):** N = Native OMNI, I = Integrata (open source esistente), C = Compatibile, B = Base/infrastruttura, P = Processo.
- **Stato di tutte le righe:** non implementato.

| # | Decisione | Livello | Cat. | Milestone | Dipendenze principali | Base proposta / note |
|---|---|---|---|---|---|---|
| 1 | Sistema operativo autonomo | L0–L1 | B | M1, M3 | Fedora Kinoite, UEFI | RF-01 |
| 2 | Hardware iniziale | L0–L1 | B | M3 | Driver NVIDIA, firmware | Nessun supporto dichiarato senza test (Regola 11) |
| 3 | Installazione su SSD separato | L1 | B | M2, M3 | Installer, identificazione dischi | RF-02, SEC-INST-01 |
| 4 | Desktop ibrido | L4 | I+N | M4 | KDE Plasma 6 | Componenti OMNI graduali |
| 5 | Identità grafica | L4 | N | M4 | Temi Plasma, Kvantum/QStyle [P] | Verifica marchio prima della distribuzione |
| 6 | Desktop intelligente | L4 | N | M4 (base), M6 (AI) | Plasmoid QML | Dock/widget senza AI in M4 |
| 7 | Multitasking ibrido | L4+L3 | N | M4, M7 | Centro attività, task manager AI | RF-06 |
| 8 | AI ibrida | L3 | N | M6 | Model Center, Router | Locale predefinito, cloud opt-in |
| 9 | Assistente avanzato | L3 | N | M6, M7 | Gestore autorizzazioni | RF-05 |
| 10 | Compatibilità software | L1+L5 | C | M8 | Wine, Proton, Flatpak | RF-09: matrice verificata |
| 11 | OMNI Store | L5 | N (su Flatpak/rpm-ostree) | M5 | Flatpak, fonti, permessi | Base iniziale: Discover [P] |
| 12 | OMNI File Manager | L5 | N/I | M5 (base), M6 (AI) | KIO/Dolphin [P], OMNI Search | |
| 13 | OMNI Performance Center | L2+L5 | N | M5 | `omni-perfd`, NVML | |
| 14 | OMNI Security Center | L2+L5 | N | M5 | firewalld, SELinux, LUKS | |
| 15 | OMNI Update Center | L2+L5 | N | M5 | ostree/bootc | RF-04 |
| 16 | OMNI Identity | L1+L5 | I+N | M5 | SDDM, PAM, systemd-homed [D] | |
| 17 | OMNI Search | L3+L5 | N | M6 | Baloo [P], indice semantico locale | |
| 18 | OMNI Media Suite | L5 | I+N | M8 | FFmpeg, Kdenlive, mpv [P] | Codec: vedi licenze |
| 19 | OMNI Browser | L5 | I+N | M5 (base), M8 (AI) | Firefox o Chromium [P] | Motore maturo, non riscritto |
| 20 | OMNI Control Center | L4 | N | M4 | Notifiche Plasma | |
| 21 | OMNI Personalization | L4 | N | M4, M6 (AI) | Temi Plasma | |
| 22 | OMNI Window Manager | L4 | N | M4 | Script/effetti KWin | Compositor non sostituito |
| 23 | OMNI Connect | L5 | I+N | M8 | KDE Connect [P] | |
| 24 | OMNI Automation Studio | L3+L5 | N | M7 | Agenti, scheduler | RF-07 |
| 25 | OMNI Developer Studio | L5 | I+N | M8 | Toolbx, IDE esistente [P] | |
| 26 | OMNI Storage Center | L2+L5 | N | M5 | UDisks2, backup cifrati | |
| 27 | OMNI Network Center | L2+L5 | N | M5 | NetworkManager | |
| 28 | OMNI System Doctor | L2+L3+L5 | N | M5 (base), M6 (AI) | journald, `omni-deviced` | Riparazioni solo con conferma |
| 29 | OMNI Installer | L1 | I+N | M2 | Anaconda / bootc-image-builder [P] | SEC-INST-01..05 |
| 30 | OMNI Welcome Experience | L5 | N | M4, M6 (AI) | Primo avvio | |
| 31 | OMNI Audio Center | L5 | N | M5/M8 | PipeWire, WirePlumber | |
| 32 | OMNI Gaming Hub | L5 | I+N | M8 | Steam/Proton, MangoHud, GameMode [P] | Matrice giochi |
| 33 | OMNI Voice | L3+L5 | N | M8 | whisper.cpp o equivalente [P], PipeWire | Riconoscimento locale |
| 34 | OMNI Office Suite | L5 | I+N | M8 | LibreOffice [P] | |
| 35 | OMNI Productivity Hub | L5 | I+N | M8 | Thunderbird/Kontact [P] | |
| 36 | OMNI Communication Hub | L5 | I+C | M8 | Client esistenti (Flatpak) | |
| 37 | OMNI Display Center | L4+L5 | N | M3 (verifica), M5 | KWin (HDR/VRR), colord | HDR/VRR non presunti |
| 38 | OMNI Maintenance Center | L2+L5 | N | M5, M7 | `omni-updated`, `omni-storaged` | |
| 39 | OMNI Accessibility | L4 | I+N | M4 | AT-SPI, Orca | RF-10 |
| 40 | OMNI Extensions | L2+L5 | N | M8 | API stabili, sandbox | RF-07 |
| 41 | OMNI AI Control | L3+L5 | N | M7 | Task manager, audit | |
| 42 | OMNI AI Model Center | L3 | N | M6 | Driver GPU, benchmark VRAM | Vedi piano benchmark |
| 43 | OMNI AI Memory | L3 | N | M6 | Archivio cifrato locale | |
| 44 | OMNI Remote | L2+L5 | N | M8 | Identità, cifratura | Disattivato di default |
| 45 | OMNI Device Manager | L2+L5 | N | M5 | `omni-deviced`, udev | |
| 46 | OMNI Power Center | L2+L5 | N | M5 | power-profiles-daemon | |
| 47 | OMNI Recovery | L1 | N | M2 (preliminare), M5 | ostree, USB live | |
| 48 | OMNI Cloud | L3+L5 | N | M8 | Identità, cifratura | Opzionale, nessun abbonamento obbligatorio |
| 49 | OMNI Terminal | L5 | I+N | M5 (base), M6 (AI) | Konsole/terminale esistente [P] | Anteprima e conferma comandi AI |
| 50 | Base Linux Fedora Kinoite | L1 | B | M1 | ADR-0002, ADR-0005 | Confronto con Universal Blue presentato |
| 51 | Architettura | Tutti | B | M0 | ADR-0006 | |
| 52 | Ordine di sviluppo | — | P | Tutte | — | Seguito da questa matrice |
| 53 | Gestione risorse | L2+L3 | N | M5, M6 | cgroup v2, NVML | Benchmark gaming+AI |
| 54 | Qualità | — | P | Tutte | CI, VM, USB, SSD isolato | `../07-verifiche/strategia-test.md` |
| 55 | Claude | — | P | Tutte | Git, PR, revisione | `../09-repository/` |

**Conteggio:** 55 righe, una per decisione approvata.
