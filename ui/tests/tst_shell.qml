import QtQuick
import QtTest
import OmniDesign
import OmniShell

// Shell completa: preferiti iniziali, scene, anteprima di apertura, Esc.
Item {
    id: top
    width: 1600; height: 1000
    ListModel {
        id: apps
        ListElement { name: "OMNI File Manager"; comment: "" }
        ListElement { name: "OMNI Terminal"; comment: "" }
        ListElement { name: "OMNI Browser"; comment: "" }
        ListElement { name: "OMNI Store"; comment: "" }
        ListElement { name: "OMNI Gaming Hub"; comment: "" }
    }
    Shell { id: shell; anchors.fill: parent; apps: apps; focus: true }
    // Avvio reale: un lanciatore finto registra le richieste
    QtObject { id: fakeLauncher; property bool enabled: true; property var calls: []
        function launch(p) { calls = calls.concat([p]); return p !== "rifiuta" } }
    Shell { id: realShell; width: 1600; height: 1000; visible: false; apps: apps; appLauncher: fakeLauncher }
    TestCase {
        name: "Shell"
        when: windowShown
        function findChild(it, typeName) {
            for (let i = 0; i < it.children.length; ++i) {
                const c = it.children[i]
                if (String(c).indexOf(typeName) === 0) return c
                const r = findChild(c, typeName); if (r) return r
            }
            return null
        }
        function test_defaultFavoritesFromCatalog() {
            compare(shell.catalog.length, 5)
            compare(shell.dockItems.length, 5)
            compare(shell.dockItems[0].glyph, "files")
        }
        function test_defaultFavoritesSkipDiagnostics() {
            const list = [ { desktopId: "a", glyph: "bug" }, { desktopId: "b", glyph: "files" }, { desktopId: "c", glyph: "chars" },
                           { desktopId: "d", glyph: "archive" }, { desktopId: "e", glyph: "logs" } ]
            compare(shell.defaultFavorites(list), ["b", "d"])
        }
        function test_scenesToggle() {
            shell.scene = "desktop"
            shell.toggle("launcher"); compare(shell.scene, "launcher")
            shell.toggle("launcher"); compare(shell.scene, "desktop")
            shell.toggle("quicksettings"); compare(shell.scene, "quicksettings")
            shell.forceActiveFocus(); keyClick(Qt.Key_Escape); compare(shell.scene, "desktop")
        }
        function test_launchRecordsSessionAndShowsPreview() {
            const e = shell.catalog[1]
            shell.launch(e, 100, 900)
            const preview = findChild(shell, "LaunchPreview")
            verify(preview !== null)
            tryVerify(() => preview.active, 1000)
            compare(preview.entry.name, "OMNI Terminal")
            tryVerify(() => !preview.active, 5000)      // si richiude da sola: nessuna app avviata
        }
        function test_realLaunchUsesLauncherNotPreview() {
            verify(realShell.realLaunch); verify(!shell.realLaunch)
            const e = Object.assign({}, realShell.catalog[0], { filePath: "/usr/share/applications/prova.desktop" })
            realShell.launch(e, 10, 10)
            compare(fakeLauncher.calls, ["/usr/share/applications/prova.desktop"])
            const preview = findChild(realShell, "LaunchPreview")
            wait(100); verify(!preview.active)                 // nessuna anteprima simulata
            const e2 = Object.assign({}, realShell.catalog[1], { filePath: "rifiuta" })
            realShell.launch(e2, 10, 10)                      // avvio fallito: non entra nei recenti
            const bar = findChild(realShell, "DesktopCards")
            verify(bar !== null)
        }
        function test_demoNotificationsPresent() {
            const store = findChild(shell, "NotificationStore")
            // l'archivio è un QtObject: si verifica tramite il contatore mostrato dalla barra
            const bar = findChild(shell, "TopBar")
            verify(bar.notificationCount >= 5)
        }
    }
}
