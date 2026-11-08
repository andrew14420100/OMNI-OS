# OMNI Shell — prototipo anticipato dell'interfaccia (v2)

> **Stato: prototipo sperimentale.** Non è la milestone M4, che non è avviata. È separato dai criteri di accettazione di M1. Nessuna decisione architetturale aperta viene adottata qui.

Seconda versione dell'interfaccia originale OMNI in Qt 6/QML. È **codice reale ed eseguibile**: gira come normale applicazione utente, senza privilegi, senza modificare la sessione KDE e senza servizi di sistema.

## Cosa funziona davvero e cosa è un prototipo

| Componente | Stato | Note |
|---|---|---|
| Sistema di design `OmniDesign` | Funzionante | Temi chiaro e scuro, 4 colori d'accento, scala tipografica Inter, superfici "vetro" con ombre leggere, contrasto WCAG verificato dai test per ogni tema e accento |
| Icone applicative | Funzionante | 29 icone vettoriali originali (squircle con gradiente e glifo); associazione automatica da nome, id `.desktop`, icona e categorie freedesktop |
| Sfondo "Aurora Flux" | Funzionante | Nebulose in lento movimento, nastri d'aurora, campo di stelle, orizzonte a griglia; animazione ferma con "Movimento ridotto" o "Risparmio risorse" |
| Desktop | Funzionante | Orologio e data reali, calendario mensile navigabile, attività recenti della sessione, scheda onesta sullo stato del prototipo |
| Barra superiore | Parziale | Data e ora reali; accesso a launcher, notifiche e impostazioni rapide. **Spazi di lavoro: prototipo** (non collegati a KWin) |
| Dock | Funzionante nel prototipo | Ingrandimento progressivo vicino al puntatore, etichette, indicatori, rimbalzo, dimensione adattiva, tastiera. **Avvio delle app: disattivato**: si vede solo l'animazione di apertura, dichiarata come tale |
| Launcher | Funzionante nel prototipo | Ricerca senza distinzione di maiuscole e accenti, anche su più parole, con ordinamento per pertinenza; categorie, preferiti (stella o Ctrl+D), recenti; navigazione completa da tastiera. Elenco letto **in sola lettura** dai file `.desktop` XDG |
| Centro notifiche | Funzionante nel prototipo | Schede raggruppate per app (pila compressa ed espandibile), tempo relativo, rimozione con pulsante, tasto Canc o trascinamento, "Cancella tutto", Non disturbare. **Non** collegato a `org.freedesktop.Notifications` |
| Impostazioni rapide | Parziale | Funzionano: tema, accento, movimento ridotto, risparmio risorse, Non disturbare. **Prototipi**: Wi-Fi, Bluetooth, volume, luminosità, Assistente AI, blocco e spegnimento |

Ogni funzione non operativa porta l'etichetta **"Prototipo"**. Preferiti e recenti restano solo in memoria, nella sessione del prototipo.

## Compilare, provare, eseguire

```bash
cmake -S ui -B ui/build && cmake --build ui/build
ctest --test-dir ui/build --output-on-failure            # 11 test C++ + 66 test QML
ui/build/omni-shell-prototipo                            # finestra interattiva
ui/build/omni-shell-prototipo --demo-apps --scene launcher --theme light --accent 1 \
    --screenshot launcher.png                            # schermata reale e uscita
ui/build/omni-shell-prototipo --demo-apps --record demo.mp4 --script ui/demo/interazioni.json
```

Con `--record` la finestra riceve **veri eventi di input Qt** (mouse e tastiera) letti da `ui/demo/interazioni.json`. Ogni fotogramma viene catturato con `grabWindow` e codificato con ffmpeg. Il tempo delle animazioni avanza a passo fisso. Puntatore, didascalie e filigrana sono disegnati dal registratore sopra il fotogramma.

Requisiti: Qt ≥ 6.4 (Quick, Shapes, QuickTest), CMake ≥ 3.22, font Inter consigliato, ffmpeg solo per `--record`.

## Tastiera

| Dove | Tasti |
|---|---|
| Ovunque | Tab per spostarsi, Invio o Spazio per attivare, Esc per chiudere il pannello aperto |
| Launcher | Digitare per cercare; ↓ per entrare nella griglia; frecce per spostarsi; Invio per aprire; Ctrl+D per i preferiti |
| Notifiche | Canc sulla scheda selezionata |
| Cursori | ← → per regolare |

## Compatibilità progettuale con KDE Plasma e Wayland

- Solo Qt Quick/QML, lo stesso linguaggio della shell Plasma 6: i componenti potranno diventare plasmoid o un pacchetto shell senza riscrivere la parte grafica.
- Nessuna API X11. Il prototipo funziona come client Wayland; in CI gira con la piattaforma `offscreen`.
- Nessun effetto grafico costoso: ombre fatte di rettangoli, icone vettoriali con antialiasing a campioni multipli, animazioni continue disattivabili.
- Le integrazioni future (KWin, notifiche di sessione, rete, audio, avvio con `KIO::ApplicationLauncherJob`) passeranno da D-Bus con i permessi dell'utente (ADR-0006). Qui **non** sono implementate.
