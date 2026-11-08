# OMNI Shell — prototipo anticipato dell'interfaccia

- **Stato:** prototipo sperimentale, versione 2 del 2026-11-08 (la v1 è nella cronologia del branch). **Non è M4**: la milestone M4 non è avviata. Questo lavoro è separato dai criteri di accettazione di M1 e non li modifica.
- **Codice:** [`../../ui/`](../../ui/) (Qt 6 / QML, CMake). Istruzioni: [`../../ui/README.md`](../../ui/README.md).
- **Schermate:** [`../../ui/screenshots/`](../../ui/screenshots/). Sono **schermate reali del prototipo in esecuzione** (Qt Quick con piattaforma `offscreen`, `QQuickWindow::grabWindow`), **non** schermate di OMNI OS installato e **non** immagini generate. Nessuna mostra il sistema operativo reale.

## 1. Obiettivo

Definire presto il linguaggio visivo OMNI e una base di componenti riutilizzabili da validare con il proprietario, senza toccare la base B3, la sessione KDE reale o le decisioni architetturali ancora aperte.

## 2. Principi di design

| Principio | Applicazione nel prototipo |
|---|---|
| Interfaccia originale (non copia di altri sistemi) | Dock flottante centrato, superfici "vetro" con bordo luminoso, sfondo con aurora e archi disegnati in codice; icone originali con tracciati SVG |
| Temi chiaro e scuro di pari qualità | Colori semantici (`bg`, `surface`, `text`, `accent`, `danger`…) definiti una volta per tema nel singleton `Theme` |
| Leggibilità | Contrasto WCAG calcolato nel tema e verificato dai test: testo primario ≥ 7:1, secondario ≥ 4,5:1 in entrambi i temi |
| Movimento sobrio e disattivabile | Durate brevi (120–320 ms) con easing; "Movimento ridotto" azzera tutte le durate |
| Onestà sullo stato | Ogni funzione non collegata al sistema porta l'etichetta "Prototipo"; il launcher non avvia programmi |

## 3. Componenti

`OmniDesign` (riutilizzabile): `Theme`, `Icons`, `OmniIcon`, `OmniAppTile`, `OmniButton`, `OmniIconButton`, `OmniSurface`, `OmniToggleTile`, `OmniSlider`, `OmniSearchField`, `PrototypeBadge`.

`OmniShell` (composizione): `Shell`, `Panel`, `Launcher`, `NotificationCenter`, `NotificationStore`, `QuickSettings`, `Toast`, `Wallpaper`.

Modello C++ `DesktopEntryModel`: legge in sola lettura i file `.desktop` dalle cartelle XDG (`XDG_DATA_HOME`, `XDG_DATA_DIRS`) rispettando la priorità, esclude le voci `NoDisplay`/`Hidden`/non applicazioni e usa nome e descrizione localizzati.

## 4. Compatibilità con KDE Plasma e Wayland

- Qt Quick/QML è la tecnologia della shell Plasma 6: i componenti potranno diventare plasmoid o un pacchetto shell Plasma senza riscrittura del codice visivo.
- Nessuna dipendenza da X11. Il prototipo funziona come normale client Wayland e, in CI, con la piattaforma `offscreen`.
- Le integrazioni reali (KWin per gli spazi di lavoro, `org.freedesktop.Notifications`, NetworkManager, PipeWire, avvio tramite `KIO::ApplicationLauncherJob`) **non** sono implementate. Andranno progettate in M4, con D-Bus e i permessi dell'utente, senza privilegi.

## 5. Verifiche

| Verifica | Strumento | Esito locale (2026-11-08) |
|---|---|---|
| Build | CMake + Qt 6.4.2 (Ubuntu 24.04) | Superata |
| Modello `.desktop` (11 casi: priorità XDG, localizzazione, esclusioni, ordinamento, demo) | QtTest | Superata |
| Tema (contrasto in entrambi i temi, movimento ridotto) | qmltestrunner | Superata |
| Ricerca del launcher (maiuscole, accenti, più parole) | qmltestrunner | Superata |
| Notifiche (aggiunta, rimozione, Non disturbare) | qmltestrunner | Superata |
| Componenti (toggle, slider, tile con colori distinti) | qmltestrunner | Superata |
| Schermate reali | `--screenshot` | 9 PNG (v2) |
| Registrazione reale | `--record` | MP4, 31 s |

Il workflow [`ui-prototipo.yml`](../../.github/workflows/ui-prototipo.yml) ripete build, test e cattura su GitHub Actions (permessi in sola lettura, nessun segreto, nessuna pubblicazione).

## 6. Limiti dichiarati

- Font: si usa Inter se installato, altrimenti il font di sistema.
- Icone delle applicazioni: monogrammi colorati, non le icone dei temi installati.
- Il prototipo non sostituisce né modifica Plasma; non viene installato nell'immagine OMNI.
- Nessuna decisione aperta (licenza DA-07, verifica del marchio REQ-TM-01) è risolta da questo lavoro. Il nome "OMNI" resta un nome di lavoro provvisorio.

## 7. Versione 2 (2026-11-08)

Richiesta del proprietario: interfaccia più evoluta, moderna, elegante e originale, non solo un cambio di colori.

| Area | v1 | v2 |
|---|---|---|
| Desktop | Sfondo a gradiente con archi, desktop vuoto | Sfondo "Aurora Flux" animato (nebulose, nastri, stelle, orizzonte), orologio grande, calendario, recenti, stato del prototipo, barra superiore |
| Icone | Tessere con sigle (FM, TE, ST) | 35 icone vettoriali originali con associazione automatica alle app reali |
| Dock | Tessere con ingrandimento singolo | Ingrandimento progressivo, etichette, indicatori, rimbalzo, anteprima di apertura, dimensione adattiva, tastiera |
| Launcher | Griglia con ricerca | Categorie, preferiti, recenti, pertinenza, stelle, navigazione da tastiera, suggerimenti dei tasti |
| Impostazioni rapide | 6 riquadri e 2 cursori | Intestazione utente, connettività, 4 funzioni operative, cursori a pillola, colori d'accento, ingresso sfalsato |
| Notifiche | Elenco semplice | Gruppi per app, pila espandibile, tempo relativo, rimozione con trascinamento |
| Temi | Chiaro/scuro | Chiaro/scuro × 4 accenti, contrasto verificato per ogni combinazione |
| Prestazioni | — | "Risparmio risorse" ferma le animazioni continue; nessun effetto grafico costoso |

Difetto corretto: la proprietà di tema `onAccent` veniva interpretata da QML come gestore di segnale e valeva nero. Rinominata `textOnAccent`, con un test di regressione.

Verifiche v2: 11 test C++ e 66 test QML superati, nessun avviso QML in esecuzione, 9 schermate reali e una registrazione reale delle interazioni (31 s, 773 fotogrammi), riprodotte anche dalla CI.
