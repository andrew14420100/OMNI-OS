import QtQuick
import QtTest
import OmniShell

// Ricerca del launcher: maiuscole, accenti, più parole, commenti.
Item {
    width: 1200; height: 800
    ListModel {
        id: apps
        ListElement { name: "Impostazioni di sistema"; comment: "Configura il computer" }
        ListElement { name: "Città e mappe"; comment: "Navigazione" }
        ListElement { name: "Terminale"; comment: "Riga di comando" }
        ListElement { name: "Editor di testo"; comment: "Modifica documenti" }
    }
    Launcher { id: launcher; anchors.fill: parent; apps: apps }
    TestCase {
        name: "Launcher"
        when: windowShown
        function test_emptyQueryShowsAll() { launcher.query = ""; compare(launcher.filtered.length, 4) }
        function test_caseInsensitive() { launcher.query = "TERMINALE"; compare(launcher.filtered.length, 1); compare(launcher.filtered[0].name, "Terminale") }
        function test_accentInsensitive() { launcher.query = "citta"; compare(launcher.filtered.length, 1) }
        function test_multipleWords() { launcher.query = "editor testo"; compare(launcher.filtered.length, 1); launcher.query = "editor mappe"; compare(launcher.filtered.length, 0) }
        function test_searchesComment() { launcher.query = "comando"; compare(launcher.filtered.length, 1) }
        function test_modelChangeRefilters() { launcher.query = "nuova"; compare(launcher.filtered.length, 0); apps.append({ name: "Nuova app", comment: "" }); compare(launcher.filtered.length, 1); apps.remove(apps.count - 1) }
        function test_activationSignal() {
            launcher.query = "terminale"
            const spy = Qt.createQmlObject('import QtTest; SignalSpy {}', this)
            spy.target = launcher; spy.signalName = "activated"
            launcher.activated(launcher.filtered[0].name)
            compare(spy.count, 1); compare(spy.signalArguments[0][0], "Terminale")
        }
    }
}
