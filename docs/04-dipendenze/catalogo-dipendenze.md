# Catalogo delle dipendenze

- **Stato:** proposta M0. Le versioni sono indicative e saranno **fissate** in M1 per la release Fedora scelta (ADR-0005).
- **Legenda origine:** F = repository Fedora; RF = RPM Fusion; FH = Flathub; U = upstream; UB = Universal Blue (solo se ADR-0002 B).
- **Legenda licenza:** indicativa, da confermare nell'analisi licenze ([`../05-licenze/analisi-licenze.md`](../05-licenze/analisi-licenze.md)) su file `LICENSE`/metadati RPM della versione fissata.

## 1. Sistema base (L0–L1)

| Componente | Uso | Origine | Licenza (indicativa) | Milestone | Note |
|---|---|---|---|---|---|
| Fedora Kinoite 45 (immagine) | Base | F | Varie (FOSS) | M1 | ADR-0002, ADR-0005 |
| Kernel Linux (7.2 da Beta F45) | Kernel | F | GPL-2.0 | M1 | Non modificato |
| shim, GRUB 2 | Avvio UEFI / Secure Boot | F | BSD-like / GPL-3.0+ | M1 | |
| systemd | Init e servizi | F | LGPL-2.1+ | M1 | |
| ostree, rpm-ostree | Deployment atomici | F | LGPL-2.0+ | M1 | ADR-0003 |
| bootc | Client container-native | F | Apache-2.0 / MIT [D] | M1 | ADR-0003 |
| Podman, Toolbx, skopeo | Container, ambienti di sviluppo | F | Apache-2.0 | M1 | |
| cosign | Firma immagini (nella CI) | U | Apache-2.0 | M1 | Solo CI |
| SELinux policy | Confinamento | F | GPL-2.0 | M1 | |
| firewalld | Firewall | F | GPL-2.0+ | M1 | |
| NetworkManager | Rete | F | GPL-2.0+ | M1 | |
| PipeWire, WirePlumber | Audio/video | F | MIT | M1 | |
| Flatpak, xdg-desktop-portal(-kde) | App isolate | F | LGPL-2.1+ | M1 | |
| UDisks2 | Dischi | F | GPL-2.0+ | M2 | |
| cryptsetup (LUKS2) | Cifratura | F | GPL-2.0+ | M2 | |
| Anaconda / image-builder / bootc-image-builder | Installazione e supporti | F/U | GPL-2.0+ / Apache-2.0 [D] | M2 | Da scegliere |
| power-profiles-daemon | Energia | F | GPL-3.0 | M5 | |
| polkit | Autorizzazioni | F | LGPL-2.0+ | M5 | |

## 2. Driver NVIDIA (L1)

| Componente | Uso | Origine | Licenza | Milestone | Note |
|---|---|---|---|---|---|
| Moduli kernel NVIDIA open | Driver kernel | RF (da `open-gpu-kernel-modules`) | Dual MIT/GPL | M3 | Obbligatori per Blackwell (ADR-0004) |
| Driver NVIDIA user-space (GL/Vulkan/CUDA/NVENC) | Grafica, calcolo | RF nonfree | **Proprietaria NVIDIA** | M3 | Vincoli di redistribuzione da analizzare |
| GSP firmware NVIDIA | Firmware GPU | RF nonfree | Proprietaria NVIDIA | M3 | |
| akmods / kmodtool | Build kmod | RF/F | MIT | M1/M3 | Usati nella CI |
| nvidia-container-toolkit | GPU nei container (AI) | U | Apache-2.0 | M6 | Valutare |

## 3. Desktop (L4)

| Componente | Uso | Origine | Licenza | Milestone |
|---|---|---|---|---|
| KDE Plasma 6.7, KWin (Wayland) | Desktop e compositor | F | GPL-2.0+/LGPL | M1/M4 |
| Qt 6 | Toolkit | F | LGPL-3.0 / GPL (dual commerciale) | M4 |
| KDE Frameworks 6 | Librerie | F | LGPL-2.1+ | M4 |
| SDDM | Login | F | GPL-2.0+ | M1 |
| Orca, AT-SPI | Accessibilità | F | LGPL | M4 |

## 4. Servizi OMNI (L2) — librerie Rust

| Crate | Uso | Licenza (tipica) | Milestone |
|---|---|---|---|
| zbus | D-Bus | MIT | M5 |
| tokio | I/O asincrono | MIT | M5 |
| serde | Serializzazione | MIT / Apache-2.0 | M5 |
| tracing | Log strutturati | MIT | M5 |
| nvml-wrapper | Metriche GPU NVIDIA | MIT / Apache-2.0 [D] | M5 |

Strumenti di controllo: `cargo-deny` (licenze e advisory), `cargo-audit`.

## 5. Motore AI (L3) — da selezionare dopo benchmark

| Candidato | Uso | Licenza (indicativa) | Milestone |
|---|---|---|---|
| llama.cpp | Inferenza LLM locale (GGUF, quantizzazione) | MIT | M6 |
| Ollama | Gestore modelli/runtime | MIT | M6 |
| vLLM | Inferenza ad alto throughput | Apache-2.0 | M6 |
| whisper.cpp | Riconoscimento vocale locale | MIT | M8 |
| Piper o equivalente | Sintesi vocale | MIT [D] | M8 |
| Libreria embedding + indice vettoriale (es. SQLite + estensione vettoriale) | Ricerca semantica, memoria | Varie | M6 |
| **Pesi dei modelli** | Modelli locali | **Licenza specifica per modello** (alcune non OSI, con limiti d'uso) | M6 |

## 6. Applicazioni integrate (L5) — candidati

| Area (decisione) | Candidato | Origine | Licenza |
|---|---|---|---|
| File Manager (12) | Dolphin / KIO | F | GPL |
| Store (11) | Discover (base iniziale), Flathub | F/FH | GPL / varie |
| Terminal (49) | Konsole | F | GPL |
| Browser (19) | Firefox o Chromium | F/FH | MPL-2.0 / BSD |
| Office (34) | LibreOffice | FH/F | MPL-2.0 |
| Media (18) | mpv, Kdenlive, FFmpeg | F/RF/FH | GPL/LGPL |
| Gaming (32) | Steam, Proton, Wine, MangoHud, GameMode, Gamescope | FH/RF/F | Steam proprietario; Proton/Wine LGPL; altri MIT/BSD |
| Connect (23) | KDE Connect | F | GPL |
| Productivity (35) | Thunderbird / Kontact | FH/F | MPL-2.0 / GPL |
| Codec multimediali | ffmpeg completo, gstreamer plugins | RF | GPL/LGPL + **problemi di brevetti** in alcune giurisdizioni |

## 7. Infrastruttura di progetto

| Servizio | Uso | Costo | Note |
|---|---|---|---|
| GitHub (repository, Actions) | Codice, CI | Gratuito per repo pubblici; minuti limitati per privati | Valutare limiti per build di immagini |
| GHCR o altro registry | Pubblicazione immagini | Gratuito per immagini pubbliche | Immagini private richiedono credenziali sul client |
| sigstore (opzionale) | Firma keyless | Gratuito | ADR-0003 F2 |

Nessuna dipendenza introduce un servizio a pagamento obbligatorio (Regola 9).
