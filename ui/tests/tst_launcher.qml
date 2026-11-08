import QtQuick
import QtTest
import OmniShell

// Launcher: ricerca (maiuscole, accenti, più parole, descrizioni), categorie, preferiti,
// recenti, ordinamento e navigazione da tastiera.
Item {
    width: 1300; height: 900
    ListModel {
        id: apps
        ListElement { name: "Impostazioni di sistema"; comment: "Configura il computer" }
        ListElement { name: "Città e mappe"; comment: "Navigazione" }
        ListElement { name: "Terminale"; comment: "Riga di comando" }
        ListElement { name: "Editor di testo"; comment: "Modifica documenti" }
    }
    SessionState { id: session }
    Launcher { id: launcher; anchors.fill: parent; apps: apps; session: session }
    SignalSpy { id: activated; target: launcher; signalName: "activated" }
    TestCase {
        name: "Launcher"
        when: windowShown
        function init() { launcher.category = "tutte"; launcher.query = ""; session.favorites = []; session.recents = []; activated.clear() }
        function test_emptyQueryShowsAll() { compare(launcher.filtered.length, 4) }
        function test_caseInsensitive() { launcher.query = "TERMINALE"; compare(launcher.filtered.length, 1); compare(launcher.filtered[0].name, "Terminale") }
        function test_accentInsensitive() { launcher.query = "citta"; compare(launcher.filtered.length, 1) }
        function test_multipleWords() { launcher.query = "editor testo"; compare(launcher.filtered.length, 1); launcher.query = "editor mappe"; compare(launcher.filtered.length, 0) }
        function test_searchesComment() { launcher.query = "comando"; compare(launcher.filtered.length, 1) }
        function test_modelChangeRefilters() { launcher.query = "nuova"; compare(launcher.filtered.length, 0); apps.append({ name: "Nuova app", comment: "" }); compare(launcher.filtered.length, 1); apps.remove(apps.count - 1) }
        function test_nameMatchesRankFirst() {
            launcher.query = "di"     // "Impostazioni di sistema" (parola), "Editor di testo" (parola)
            verify(launcher.filtered.length >= 2)
            launcher.query = "te"     // "Terminale" inizia per "te": deve essere primo
            compare(launcher.filtered[0].name, "Terminale")
        }
        function test_categories() {
            compare(launcher.counts.tutte, 4)
            launcher.category = "sistema"
            verify(launcher.filtered.every(e => e.category === "sistema"))
            verify(launcher.filtered.some(e => e.name === "Impostazioni di sistema"))
        }
        function test_favoritesAndRecents() {
            session.toggleFavorite("Terminale")
            launcher.category = "preferiti"; compare(launcher.filtered.length, 1); compare(launcher.filtered[0].name, "Terminale")
            session.noteLaunch("Editor di testo"); session.noteLaunch("Terminale")
            launcher.category = "recenti"; compare(launcher.filtered.map(e => e.name), ["Terminale", "Editor di testo"])
        }
        function test_activationSignal() {
            launcher.query = "terminale"
            launcher.launch(launcher.filtered[0], null)
            compare(activated.count, 1); compare(activated.signalArguments[0][0], "Terminale")
        }
        function test_keyboardNavigation() {
            launcher.open = true
            wait(50)
            keyClick(Qt.Key_T); keyClick(Qt.Key_E); keyClick(Qt.Key_R)      // la digitazione va al campo di ricerca
            compare(launcher.query, "ter")
            keyClick(Qt.Key_Down)                                           // passa alla griglia
            keyClick(Qt.Key_D, Qt.ControlModifier)                          // preferito
            verify(session.isFavorite("Terminale"))
            keyClick(Qt.Key_Return)                                         // apre
            compare(activated.count, 1); compare(activated.signalArguments[0][0], "Terminale")
            launcher.open = false
        }
    }
}
