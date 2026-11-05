# Piano di benchmark: gaming e AI locale simultanei (VRAM 16 GB)

- **Stato:** piano M0. Esecuzione prevista in **M6** (AI locale), con misure di base del solo gaming in **M3/M5**. Nessun benchmark è stato eseguito.
- **Decisioni approvate correlate:** 13, 32, 41, 42, 53
- **Riferimenti:** spec §4 (le soglie numeriche si definiscono dopo la misurazione del sistema base), §8 ("Risorse durante AI e gaming simultanei").

## 1. Obiettivi

1. Misurare il costo in VRAM, GPU, CPU e RAM di modelli AI locali di diverse dimensioni e quantizzazioni sulla RTX 5070 Ti (16 GB).
2. Misurare l'impatto dell'AI attiva sulle prestazioni dei giochi e viceversa.
3. Definire **budget VRAM** e **politiche di priorità** per i profili Gaming / AI / Bilanciato (decisione 53).
4. Verificare il comportamento in esaurimento VRAM (nessun crash del gioco, nessuna perdita di dati, degrado controllato dell'AI).

## 2. Configurazione di prova

| Elemento | Valore |
|---|---|
| Hardware | Ryzen 7 9800X3D, RTX 5070 Ti 16 GB, 32 GB RAM, monitor 4K |
| Software | Immagine OMNI fissata (tag), driver NVIDIA fissato, kernel fissato |
| Condizioni | Temperatura ambiente annotata; alimentazione e profilo energetico fissati; stesso stato di riavvio |
| Ripetizioni | Almeno 3 esecuzioni per scenario; si riportano mediana e dispersione |

## 3. Metriche

| Area | Metrica | Strumento candidato |
|---|---|---|
| VRAM | Uso totale e per processo, picco | `nvidia-smi --query-gpu`, NVML |
| GPU | Utilizzo, clock, potenza, temperatura | NVML |
| Gaming | FPS medi, 1% e 0,1% low, frame time (ms) | MangoHud (log) |
| AI | Tempo al primo token, token/s, latenza end-to-end, tempo di caricamento modello | Log del runtime |
| CPU/RAM | Utilizzo per core, RAM, swap/zram | `pidstat`, `/proc`, PSI (`/proc/pressure/*`) |
| Stabilità | Errori Xid, crash, OOM, stalli | `journalctl -k`, log |
| Reattività desktop | Latenza input/composizione percepita durante il carico | Prova manuale strutturata + log KWin [D] |

## 4. Scenari

| ID | Scenario | Scopo |
|---|---|---|
| B-00 | Desktop inattivo 4K | Linea di base VRAM/consumi |
| B-G1 | Solo gioco A (titolo pesante, 4K) | Riferimento gaming |
| B-G2 | Solo gioco B (titolo competitivo, alto refresh) | Riferimento gaming |
| B-A1 | Solo AI: modello piccolo (≈ 3–4 B parametri, quantizzato 4 bit) | Riferimento AI |
| B-A2 | Solo AI: modello medio (≈ 7–9 B, 4 bit) | Riferimento AI |
| B-A3 | Solo AI: modello grande (≈ 12–14 B, 4 bit) | Limite VRAM |
| B-A4 | Solo AI: modello su CPU/RAM (offload completo) | Alternativa senza VRAM |
| B-V1 | Solo riconoscimento vocale locale | Carico tipico di OMNI Voice |
| **B-C1** | Gioco A + modello piccolo **residente inattivo** | Costo della sola occupazione VRAM |
| **B-C2** | Gioco A + modello piccolo **in generazione continua** | Contesa di calcolo |
| **B-C3** | Gioco A + modello medio in generazione | Vicino al limite di 16 GB |
| **B-C4** | Gioco A + modello grande caricato | Prova di esaurimento VRAM controllato |
| **B-C5** | Gioco B + AI con offload parziale su CPU | Strategia ibrida |
| **B-C6** | Gioco A + voce locale + modello piccolo | Scenario d'uso reale "assistente durante il gioco" |
| **B-C7** | Avvio del gioco mentre il modello è già caricato | Verifica che il Model Center scarichi/riduca il modello in tempo |
| **B-C8** | Caricamento modello mentre il gioco è in esecuzione | Verifica rifiuto o degrado controllato |

Le dimensioni dei modelli sono categorie, non scelte definitive: i modelli
specifici saranno selezionati in M6 con le relative licenze.

## 5. Politiche da validare

| Politica | Descrizione | Criterio da misurare |
|---|---|---|
| P-1 Priorità Gaming | Con un gioco a schermo intero, l'AI usa al massimo un budget VRAM (valore da definire) o passa a CPU | Perdita di FPS del gioco rispetto a B-G1 |
| P-2 Scaricamento automatico | Avvio gioco → il Model Center scarica i modelli non in uso | Tempo di liberazione VRAM; nessun crash |
| P-3 Profilo AI | Senza gioco, l'AI può usare quasi tutta la VRAM | Token/s rispetto a B-A2/B-A3 |
| P-4 Controllo manuale | L'utente fissa limiti e priorità (decisione 53) | Rispetto dei limiti impostati |
| P-5 Protezione lavori | Un'operazione AI lunga non viene persa quando il gioco richiede VRAM: viene messa in pausa o spostata | Nessuna perdita, ripresa corretta |

## 6. Criteri di accettazione (da quantificare dopo le misure)

Le soglie numeriche saranno proposte al proprietario **dopo** B-00, B-G1, B-G2
(spec §4). Struttura dei criteri:

- Con profilo Gaming e AI residente inattiva (B-C1): perdita di FPS medi e 1% low entro una soglia **X%** da definire.
- Nessuno scenario B-C1…B-C8 deve causare crash del gioco, crash del driver (Xid) o blocco del desktop.
- In esaurimento VRAM (B-C4, B-C8) l'AI deve degradare (rifiuto, offload, modello più piccolo) e notificare l'utente.
- I limiti impostati manualmente devono essere rispettati con tolleranza **Y** da definire.

## 7. Risultati

| Scenario | Data | Immagine/driver | Risultato | Note |
|---|---|---|---|---|
| — | — | — | Non eseguito | |
