import QtQuick
import QtTest
import OmniDesign

// Sistema di icone applicative: associazione nome/categorie → glifo e disegno di ogni glifo.
Item {
    width: 800; height: 400
    Repeater { id: all; model: AppGlyphs.keys; OmniAppIcon { required property string modelData; glyph: modelData; size: 32 } }
    TestCase {
        name: "AppGlyphs"
        when: windowShown
        function test_demoApps() {
            const expected = {
                "OMNI File Manager": "files", "OMNI Terminal": "terminal", "OMNI Store": "store", "OMNI Browser": "browser",
                "OMNI Update Center": "update", "OMNI Security Center": "security", "OMNI Performance Center": "performance",
                "OMNI Network Center": "network", "OMNI Storage Center": "storage", "OMNI Media Suite": "media",
                "OMNI Office Suite": "office", "OMNI Gaming Hub": "gaming", "OMNI Developer Studio": "developer",
                "OMNI Display Center": "display", "OMNI Audio Center": "audio", "OMNI Accessibility": "accessibility" }
            for (const n in expected) compare(AppGlyphs.resolve(n, "", "", []), expected[n], n)
        }
        function test_realDesktopNames() {
            compare(AppGlyphs.resolve("Dolphin", "org.kde.dolphin.desktop", "system-file-manager", ["System", "FileManager"]), "files")
            compare(AppGlyphs.resolve("Konsole", "org.kde.konsole.desktop", "utilities-terminal", ["System", "TerminalEmulator"]), "terminal")
            compare(AppGlyphs.resolve("Firefox", "org.mozilla.firefox.desktop", "org.mozilla.firefox", ["Network", "WebBrowser"]), "browser")
            compare(AppGlyphs.resolve("Impostazioni di sistema", "systemsettings.desktop", "preferences-system", ["Settings"]), "settings")
            compare(AppGlyphs.resolve("Discover", "org.kde.discover.desktop", "plasmadiscover", ["System"]), "store")
        }
        function test_officeVariantsAndEditors() {
            compare(AppGlyphs.resolve("LibreOffice Calc", "libreoffice-calc.desktop", "libreoffice-calc", ["Office", "Spreadsheet"]), "spreadsheet")
            compare(AppGlyphs.resolve("LibreOffice Impress", "libreoffice-impress.desktop", "libreoffice-impress", ["Office"]), "presentation")
            compare(AppGlyphs.resolve("LibreOffice Draw", "libreoffice-draw.desktop", "libreoffice-draw", ["Graphics"]), "drawing")
            compare(AppGlyphs.resolve("LibreOffice Writer", "libreoffice-writer.desktop", "libreoffice-writer", ["Office"]), "office")
            compare(AppGlyphs.resolve("KCalc", "org.kde.kcalc.desktop", "accessories-calculator", ["Utility"]), "calculator")
            compare(AppGlyphs.resolve("ImageMagick (color depth=q16)", "display-im6.q16.desktop", "display-im6.q16", ["Graphics"]), "photos")
            compare(AppGlyphs.resolve("Vim", "vim.desktop", "gvim", ["Utility", "TextEditor"]), "texteditor")
        }
        function test_kdeAppsInTheVm() {
            // nomi reali osservati nel launcher dentro la VM Fedora Kinoite 45
            compare(AppGlyphs.resolve("Ark", "org.kde.ark.desktop", "ark", ["Qt", "KDE", "Utility", "Archiving"]), "archive")
            compare(AppGlyphs.resolve("Help Center", "org.kde.khelpcenter.desktop", "help-browser", ["Qt", "KDE", "Core"]), "help")
            compare(AppGlyphs.resolve("Journald Browser", "org.kde.kjournaldbrowser.desktop", "utilities-log-viewer", ["Qt", "KDE", "System"]), "logs")
            compare(AppGlyphs.resolve("KDE Connect", "org.kde.kdeconnect.app.desktop", "kdeconnect", ["Qt", "KDE", "Network"]), "phone")
            compare(AppGlyphs.resolve("Emoji Selector", "org.kde.plasma.emojier.desktop", "preferences-desktop-emoticons", ["Utility"]), "chars")
            compare(AppGlyphs.resolve("KCharSelect", "org.kde.kcharselect.desktop", "accessories-character-map", ["Utility"]), "chars")
            compare(AppGlyphs.resolve("Crashed Processes Viewer", "org.kde.drkonqi.coredump.gui.desktop", "tools-report-bug", ["Qt", "KDE", "System"]), "bug")
            compare(AppGlyphs.resolve("KDebugSettings", "org.kde.kdebugsettings.desktop", "debug-run", ["Qt", "KDE", "Utility"]), "bug")
            compare(AppGlyphs.resolve("Park", "x.desktop", "x", []), "generic")      // "ark" solo come parola intera
        }
        function test_categoryFallback() {
            compare(AppGlyphs.resolve("Qualcosa", "x.desktop", "x", ["Game"]), "gaming")
            compare(AppGlyphs.resolve("Qualcosa", "x.desktop", "x", ["Graphics"]), "photos")
            compare(AppGlyphs.resolve("Qualcosa", "x.desktop", "x", []), "generic")
        }
        function test_everyGlyphHasLayersAndRenders() {
            compare(all.count, AppGlyphs.keys.length)
            verify(AppGlyphs.keys.length >= 25)
            for (let i = 0; i < AppGlyphs.keys.length; ++i) {
                const g = AppGlyphs.glyph(AppGlyphs.keys[i])
                verify(g.layers.length > 0, AppGlyphs.keys[i]); verify(g.c1 !== g.c2, AppGlyphs.keys[i])
            }
        }
        function test_circleHelper() { compare(AppGlyphs.circle(24, 24, 4), "M24 20a4 4 0 1 1 0 8a4 4 0 1 1 0 -8z") }
    }
}
