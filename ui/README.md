# OMNI Shell — prototipo anticipato dell'interfaccia

> **Stato: prototipo sperimentale.** Non è la milestone M4 e non è dichiarata avviata
> né conclusa. È separato dai criteri di accettazione di M1. Nessuna decisione
> architetturale aperta viene adottata qui.

Prima struttura Qt 6/QML dell'interfaccia originale OMNI. È **codice reale ed eseguibile**: gira come normale applicazione utente, senza privilegi, senza modificare la sessione KDE e senza servizi di sistema.

## Cosa funziona davvero

| Componente | Stato | Note |
|---|---|---|
| Sistema di design `OmniDesign` | Funzionante | Temi chiaro e scuro, spaziature, raggi, tipografia, movimento; contrasto WCAG verificato dai test |
| Tema scuro / chiaro | Funzionante | Commutazione dal vivo nelle Impostazioni rapide |
| Movimento ridotto | Funzionante | Azzera tutte le animazioni (decisione 39, RF-10) |
| Pannello (dock flottante) | Funzionante nel prototipo | Applicazioni fissate con ingrandimento, contatore notifiche, orologio reale |
| Launcher | Funzionante nel prototipo | Ricerca istantanea senza distinzione di maiuscole e accenti, anche su più parole; elenco letto **in sola lettura** dai file `.desktop` XDG |
| Avvio delle applicazioni | **Prototipo (disattivato)** | Il prototipo non agisce sulla sessione reale |
| Centro notifiche | Funzionante nel prototipo | Rimozione animata, "Cancella tutto", Non disturbare. **Non** collegato a `org.freedesktop.Notifications` |
| Impostazioni rapide | Parziale | Tema, movimento ridotto e Non disturbare funzionano; Wi-Fi, Bluetooth, volume, luminosità e Assistente AI sono **prototipi** con etichetta |
| Spazi di lavoro | **Prototipo** | Indicatore non collegato a KWin |

Ogni funzione non operativa porta l'etichetta **"Prototipo"**.

## Struttura

```
ui/
├── CMakeLists.txt
├── src/main.cpp              avvio, opzioni, cattura di schermate reali
├── src/desktopentries.*      modello C++ delle applicazioni (.desktop XDG, sola lettura)
├── qml/OmniDesign/           sistema di design e componenti riutilizzabili
├── qml/OmniShell/            pannello, launcher, notifiche, impostazioni rapide, sfondo
├── tests/                    QtTest (C++) e qmltestrunner (QML)
└── screenshots/              schermate reali del prototipo in esecuzione
```

## Compilare, provare, eseguire

```bash
cmake -S ui -B ui/build && cmake --build ui/build
ctest --test-dir ui/build --output-on-failure
ui/build/omni-shell-prototipo                    # finestra interattiva
ui/build/omni-shell-prototipo --demo-apps --scene launcher --theme light \
    --screenshot launcher.png                    # schermata reale e uscita
```

Requisiti: Qt ≥ 6.4 (Quick, Shapes, QuickTest), CMake ≥ 3.22, font Inter consigliato.

## Compatibilità progettuale con KDE Plasma e Wayland

- Solo Qt Quick/QML, lo stesso linguaggio dei plasmoid di Plasma 6: i componenti potranno diventare plasmoid o parte di una shell Plasma senza riscrittura.
- Nessuna API X11; il rendering usa le astrazioni di Qt Quick, quindi funziona sotto Wayland. In CI gira con `offscreen`.
- Le integrazioni future (KWin per gli spazi di lavoro, notifiche di sessione, rete, audio) passeranno da D-Bus con le autorizzazioni dell'utente (ADR-0006). Qui **non** sono implementate.
