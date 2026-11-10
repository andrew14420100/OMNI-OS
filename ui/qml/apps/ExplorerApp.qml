import QtQuick
import QtQuick.Window
import OmniDesign
import OmniApps
import OmniFiles
import "explorer"
import "../OmniApps/sys.js" as Sys

// OMNI Explorer: gestione dei file reale (KIO nel sistema OMNI). Schede, cronologia,
// barra degli indirizzi, ricerca, anteprima, viste Dettagli/Icone, appunti condivisi con
// le altre app, cestino con ripristino, proprietà e permessi, ZIP, avanzamento annullabile.
// Le eliminazioni definitive chiedono sempre conferma.
Window {
    id: app
    width: 1280; height: 800
    minimumWidth: 820; minimumHeight: 520
    visible: true
    title: trashMode ? qsTr("Cestino — Esplora file") : (folderName(currentPath) + qsTr(" — Esplora file"))
    color: Theme.dark ? "#0F1424" : "#F3F5FA"

    FolderModel { id: folder; showHidden: app.showHidden }
    FileOps { id: ops }

    property var tabs: [{ path: omniSystem.homePath(), back: [], fwd: [], trash: false }]
    property int tab: 0
    readonly property string currentPath: tabs[tab].path
    readonly property bool trashMode: tabs[tab].trash
    property var selection: []
    property int anchorRow: -1
    property bool gridView: false
    property bool showHidden: false
    property bool showPreview: true
    property var trashList: []
    property string message: ""
    property int messageKind: 0
    property var volumeList: ops.volumes()

    function applyPrefs() { Theme.dark = shellSettings.dark; Theme.accentIndex = shellSettings.accent; Theme.reducedMotion = shellSettings.reducedMotion }
    Connections { target: shellSettings; function onChanged() { app.applyPrefs() } }
    Component.onCompleted: {
        applyPrefs()
        const a = Qt.application.arguments
        // cartella iniziale: --cartella <percorso>, oppure un percorso/URL file:// passato
        // dal sistema (apertura di una cartella da un'altra app, Exec=... %U)
        for (let i = 1; i < a.length; ++i) {
            let p = a[i] === "--cartella" ? a[i + 1] : (a[i - 1] !== "--cartella" && a[i - 1] !== "--app" && /^(\/|file:\/\/)/.test(a[i]) ? a[i] : "")
            if (!p) continue
            if (p.startsWith("file://")) p = decodeURIComponent(p.slice(7))
            if (omniSystem.exists(p)) { navigate(p); break }
        }
        folder.path = currentPath
        shellPerf.mark("finestra creata")
    }
    onFrameSwapped: shellPerf.mark("primo fotogramma")

    readonly property var places: ops.places()
    function folderName(p) { if (p === "/") return qsTr("Sistema"); if (p === omniSystem.homePath()) return qsTr("Home"); const i = p.lastIndexOf("/"); return p.slice(i + 1) }
    function setTab(t) { const c = tabs.slice(); c[tab] = t; tabs = c }
    function navigate(path, keepHistory) {
        const t = Object.assign({}, tabs[tab])
        if (!keepHistory && (t.path !== path || t.trash)) { t.back = t.back.concat([t.trash ? "trash:" : t.path]); t.fwd = [] }
        t.path = path; t.trash = false
        setTab(t); selection = []; anchorRow = -1; search.text = ""
        folder.path = path
    }
    function openTrash() {
        const t = Object.assign({}, tabs[tab])
        if (!t.trash) { t.back = t.back.concat([t.path]); t.fwd = [] }
        t.trash = true; setTab(t); selection = []; refreshTrash()
    }
    function goBack() { const t = Object.assign({}, tabs[tab]); if (!t.back.length) return; const p = t.back[t.back.length - 1]
        t.back = t.back.slice(0, -1); t.fwd = [t.trash ? "trash:" : t.path].concat(t.fwd); applyHistory(t, p) }
    function goForward() { const t = Object.assign({}, tabs[tab]); if (!t.fwd.length) return; const p = t.fwd[0]
        t.fwd = t.fwd.slice(1); t.back = t.back.concat([t.trash ? "trash:" : t.path]); applyHistory(t, p) }
    function applyHistory(t, p) { if (p === "trash:") { t.trash = true; setTab(t); refreshTrash() } else { t.trash = false; t.path = p; setTab(t); folder.path = p } selection = [] }
    function goUp() { if (!trashMode && folder.parentPath()) navigate(folder.parentPath()) }
    function newTab(path) { tabs = tabs.concat([{ path: path || omniSystem.homePath(), back: [], fwd: [], trash: false }]); switchTab(tabs.length - 1) }
    function closeTab(i) { if (tabs.length === 1) { app.close(); return } const c = tabs.slice(); c.splice(i, 1); tabs = c; switchTab(Math.min(tab, tabs.length - 1)) }
    function switchTab(i) { tab = i; selection = []; if (trashMode) refreshTrash(); else folder.path = currentPath }
    function refreshTrash() { trashList = ops.trashItems() }

    // selezione: clic singolo, Ctrl (aggiungi/togli), Maiusc (intervallo)
    function select(row, path, mods) {
        const view = files
        if (mods & Qt.ShiftModifier && anchorRow >= 0) {
            const a = Math.min(anchorRow, row), b = Math.max(anchorRow, row), s = []
            for (let i = a; i <= b; ++i) s.push(view.row(i).path)
            selection = s
        } else if (mods & Qt.ControlModifier) {
            selection = selection.indexOf(path) >= 0 ? selection.filter(p => p !== path) : selection.concat([path]); anchorRow = row
        } else { selection = [path]; anchorRow = row }
    }
    readonly property var selectedItem: {
        if (selection.length !== 1) return null
        if (trashMode) return trashList.find(x => x.path === selection[0]) || null
        const r = folder.indexOfPath(selection[0]); return r >= 0 ? folder.get(r) : null
    }
    function activate(row) {
        const d = files.row(row)
        if (trashMode) return
        if (d.isDir) navigate(d.path)
        else if (/zip$/.test(d.mime) && ops.zip) extractHere(d.path)
        else if (!ops.open(d.path)) say(qsTr("Nessuna applicazione può aprire \"%1\"").arg(d.name), 2)
    }
    function say(text, kind) { message = text; messageKind = kind || 0; msgTimer.restart() }
    Timer { id: msgTimer; interval: 6000; onTriggered: app.message = "" }

    // operazioni: l'esito arriva dal sistema (FileOps.finished), mai dichiarato in anticipo
    property var pending: ({})
    function track(id, okText) { const p = Object.assign({}, pending); p[id] = okText; pending = p }
    Connections {
        target: ops
        function onFinished(id, ok, error) {
            const t = app.pending[id]; const p = Object.assign({}, app.pending); delete p[id]; app.pending = p
            if (ok) app.say(t || qsTr("Operazione completata"), 1); else app.say(error, 2)
            if (app.trashMode) app.refreshTrash(); else folder.refresh()
            app.volumeList = ops.volumes()
        }
    }
    function copySel(cut) { if (!selection.length || trashMode) return; ops.setClipboard(selection, cut); say(cut ? qsTr("%n elementi da spostare: incolla nella destinazione", "", selection.length) : qsTr("%n elementi copiati negli appunti", "", selection.length)) }
    function paste() {
        if (trashMode) return
        const c = ops.clipboard(); if (!c.paths.length) return
        if (c.cut) { track(ops.move(c.paths, currentPath), qsTr("Spostamento completato")); ops.setClipboard([], false) }
        else track(ops.copy(c.paths, currentPath), qsTr("Copia completata"))
    }
    function dropOn(urls, dest, copy) {
        const paths = []
        for (let i = 0; i < urls.length; ++i) { const u = urls[i].toString(); if (u.startsWith("file://")) paths.push(decodeURIComponent(u.slice(7))) }
        const ok = paths.filter(p => p !== dest && p.slice(0, p.lastIndexOf("/")) !== dest)
        if (!ok.length) return
        if (copy) track(ops.copy(ok, dest), qsTr("Copia completata")); else track(ops.move(ok, dest), qsTr("Spostamento completato"))
    }
    function trashSel() { if (!selection.length || trashMode) return; track(ops.trash(selection), qsTr("%n elementi spostati nel cestino (ripristinabili)", "", selection.length)); selection = [] }
    function askDelete() {
        if (!selection.length) return
        if (trashMode) confirm.ask(qsTr("Eliminare definitivamente %n elementi dal cestino? Non sarà possibile recuperarli.", "", selection.length), qsTr("Elimina definitivamente"), function() {
            const names = trashList.filter(x => selection.indexOf(x.path) >= 0).map(x => x.trashName)
            const e = ops.removeFromTrash(names); say(e || qsTr("Elementi eliminati definitivamente"), e ? 2 : 1); selection = []; refreshTrash() })
        else { const sel = selection.slice(); confirm.ask(qsTr("Eliminare definitivamente %n elementi senza passare dal cestino? Non sarà possibile recuperarli.", "", sel.length), qsTr("Elimina definitivamente"), function() {
            track(ops.remove(sel), qsTr("Elementi eliminati definitivamente")); selection = [] }) }
    }
    function restoreSel() { const names = trashList.filter(x => selection.indexOf(x.path) >= 0).map(x => x.trashName); const e = ops.restore(names); say(e || qsTr("Ripristinati nella posizione originale"), e ? 2 : 1); selection = []; refreshTrash() }
    function emptyTrash() { if (!trashList.length) return; confirm.ask(qsTr("Svuotare il cestino? %n elementi verranno eliminati definitivamente.", "", trashList.length), qsTr("Svuota cestino"), function() {
        const e = ops.removeFromTrash(trashList.map(x => x.trashName)); say(e || qsTr("Cestino svuotato"), e ? 2 : 1); refreshTrash() }) }
    function newFolder() { if (trashMode) return; nameDlg.ask(qsTr("Nuova cartella"), ops.uniqueName(currentPath, qsTr("Nuova cartella")), function(n) {
        const e = ops.mkdir(currentPath, n); if (e) { say(e, 2); return false } folder.refresh(); selection = [currentPath + "/" + n]; return true }) }
    function renameSel() { if (selection.length !== 1 || trashMode) return; const p = selection[0], old = p.slice(p.lastIndexOf("/") + 1)
        nameDlg.ask(qsTr("Rinomina"), old, function(n) { const e = ops.rename(p, n); if (e) { say(e, 2); return false } folder.refresh(); selection = [p.slice(0, p.lastIndexOf("/") + 1) + n]; return true }) }
    function compressSel() { if (!selection.length || trashMode || !ops.zip) return
        const base = selection.length === 1 ? selection[0].slice(selection[0].lastIndexOf("/") + 1) : qsTr("Archivio")
        track(ops.compress(selection, currentPath + "/" + ops.uniqueName(currentPath, base + ".zip")), qsTr("Archivio ZIP creato")) }
    function extractHere(zip) { const base = zip.slice(zip.lastIndexOf("/") + 1).replace(/\.zip$/i, "")
        track(ops.extract(zip, currentPath + "/" + ops.uniqueName(currentPath, base)), qsTr("Archivio estratto")) }

    // ------------------------------------------------------------------ scorciatoie da tastiera
    Shortcut { sequences: [StandardKey.Copy]; onActivated: app.copySel(false) }
    Shortcut { sequences: [StandardKey.Cut]; onActivated: app.copySel(true) }
    Shortcut { sequences: [StandardKey.Paste]; onActivated: app.paste() }
    Shortcut { sequence: "Delete"; onActivated: app.trashMode ? app.askDelete() : app.trashSel() }
    Shortcut { sequence: "Shift+Delete"; onActivated: app.askDelete() }
    Shortcut { sequence: "F2"; onActivated: app.renameSel() }
    Shortcut { sequence: "F5"; onActivated: app.trashMode ? app.refreshTrash() : folder.refresh() }
    Shortcut { sequence: "Ctrl+T"; onActivated: app.newTab(app.currentPath) }
    Shortcut { sequence: "Ctrl+W"; onActivated: app.closeTab(app.tab) }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: app.newFolder() }
    Shortcut { sequence: "Ctrl+H"; onActivated: app.showHidden = !app.showHidden }
    Shortcut { sequence: "Ctrl+F"; onActivated: search.inputItem.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+L"; onActivated: crumbs.edit() }
    Shortcut { sequence: "Alt+Left"; onActivated: app.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: app.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: app.goUp() }
    Shortcut { sequence: "Backspace"; enabled: !search.inputItem.activeFocus && !crumbs.editing; onActivated: app.goUp() }
    Shortcut { sequence: StandardKey.SelectAll; enabled: !search.inputItem.activeFocus; onActivated: { const s = []; for (let i = 0; i < files.rows; ++i) s.push(files.row(i).path); app.selection = s } }
    Shortcut { sequences: ["Return", "Enter"]; enabled: app.selection.length === 1 && !crumbs.editing && !nameDlg.visible; onActivated: { const r = app.trashMode ? -1 : folder.indexOfPath(app.selection[0]); if (r >= 0) app.activate(r) } }
    Shortcut { sequence: "Escape"; onActivated: { if (menu.visible) menu.visible = false; else app.selection = [] } }

    // ------------------------------------------------------------------------- schede
    Rectangle {
        id: tabBar
        width: parent.width; height: 42
        color: Theme.dark ? "#0A0E1A" : "#E4E8F2"
        Row {
            x: 8; height: parent.height; spacing: 4
            Repeater {
                model: app.tabs.length
                delegate: Rectangle {
                    required property int index
                    readonly property var t: app.tabs[index]
                    objectName: "scheda:" + index
                    y: 6; width: 200; height: 36; radius: 8
                    color: index === app.tab ? (Theme.dark ? "#0F1424" : "#F3F5FA") : (tm.containsMouse ? Theme.hover : "transparent")
                    OmniIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; name: t.trash ? "trash" : "folder"; color: Theme.textSecondary }
                    Text { x: 34; width: parent.width - 66; anchors.verticalCenter: parent.verticalCenter; text: t.trash ? qsTr("Cestino") : app.folderName(t.path); elide: Text.ElideRight; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: (m) => m.button === Qt.MiddleButton ? app.closeTab(index) : app.switchTab(index) }
                    OmniIconButton { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; iconSize: 12; icon: "close"; label: qsTr("Chiudi scheda"); onClicked: app.closeTab(index) }
                }
            }
            OmniIconButton { y: 8; width: 30; height: 30; iconSize: 14; icon: "plus"; label: qsTr("Nuova scheda (Ctrl+T)"); objectName: "scheda:nuova"; onClicked: app.newTab(app.currentPath) }
        }
    }

    // ------------------------------------------------------------- navigazione e indirizzo
    Row {
        id: nav
        anchors { top: tabBar.bottom; topMargin: 8; left: parent.left; leftMargin: 12 }
        spacing: 4; height: 36
        OmniIconButton { width: 34; height: 34; iconSize: 16; icon: "arrow-left"; label: qsTr("Indietro (Alt+Sinistra)"); enabled: app.tabs[app.tab].back.length > 0; opacity: enabled ? 1 : 0.4; onClicked: app.goBack() }
        OmniIconButton { width: 34; height: 34; iconSize: 16; icon: "arrow-right"; label: qsTr("Avanti (Alt+Destra)"); enabled: app.tabs[app.tab].fwd.length > 0; opacity: enabled ? 1 : 0.4; onClicked: app.goForward() }
        OmniIconButton { width: 34; height: 34; iconSize: 16; icon: "arrow-up"; label: qsTr("Cartella superiore (Alt+Su)"); enabled: !app.trashMode && app.currentPath !== "/"; opacity: enabled ? 1 : 0.4; onClicked: app.goUp() }
        OmniIconButton { width: 34; height: 34; iconSize: 16; icon: "restart"; label: qsTr("Aggiorna (F5)"); onClicked: app.trashMode ? app.refreshTrash() : folder.refresh() }
    }
    Rectangle {
        id: crumbs
        objectName: "esplora:indirizzo"
        property bool editing: false
        function edit() { if (app.trashMode) return; editing = true; addr.text = app.currentPath; addr.forceActiveFocus(); addr.selectAll() }
        anchors { top: nav.top; left: nav.right; leftMargin: 8; right: search.left; rightMargin: 8 }
        height: 36; radius: 8; color: Theme.surfaceSunken; border.color: editing ? Theme.accent : Theme.outline
        Row {
            visible: !crumbs.editing; x: 8; height: parent.height; spacing: 0; clip: true; width: parent.width - 16
            Repeater {
                model: {
                    if (app.trashMode) return [{ label: qsTr("Cestino"), path: "" }]
                    const p = app.currentPath, home = omniSystem.homePath(), out = []
                    let base = "", rest = p
                    if (p === home || p.startsWith(home + "/")) { out.push({ label: qsTr("Home"), path: home }); base = home; rest = p.slice(home.length) }
                    else out.push({ label: qsTr("Sistema"), path: "/" })
                    rest.split("/").filter(x => x).forEach(x => { base = base + "/" + x; out.push({ label: x, path: base }) })
                    return out
                }
                delegate: Row {
                    required property var modelData
                    required property int index
                    height: crumbs.height
                    OmniIcon { visible: index > 0; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; name: "chevron-right"; color: Theme.textTertiary }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 28; width: ct.width + 16; radius: 6; color: cm.containsMouse ? Theme.hover : "transparent"
                        Text { id: ct; anchors.centerIn: parent; text: modelData.label; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; onClicked: if (modelData.path) app.navigate(modelData.path) } }
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; enabled: !crumbs.editing; onClicked: crumbs.edit() }
        TextInput {
            id: addr
            visible: crumbs.editing; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
            color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily; selectByMouse: true; clip: true
            onAccepted: { crumbs.editing = false; if (omniSystem.exists(text)) app.navigate(text); else app.say(qsTr("Percorso non trovato: %1").arg(text), 2) }
            onActiveFocusChanged: if (!activeFocus) crumbs.editing = false
            Keys.onEscapePressed: crumbs.editing = false
        }
    }
    OmniSearchField {
        id: search
        objectName: "esplora:cerca"
        anchors { top: nav.top; right: parent.right; rightMargin: 12 }
        width: 280; height: 36
        placeholder: app.trashMode ? qsTr("Cerca nel cestino") : qsTr("Cerca in %1").arg(app.folderName(app.currentPath))
        onTextChanged: searchDelay.restart()
        Timer { id: searchDelay; interval: 300; onTriggered: if (!app.trashMode) folder.searchText = search.text }
    }

    // ----------------------------------------------------------------- barra dei comandi
    Row {
        id: commands
        anchors { top: nav.bottom; topMargin: 8; left: parent.left; leftMargin: 12 }
        spacing: 4; height: 34
        component Cmd: OmniIconButton { width: 34; height: 34; iconSize: 16; opacity: enabled ? 1 : 0.35 }
        Cmd { icon: "plus"; label: qsTr("Nuova cartella (Ctrl+Maiusc+N)"); objectName: "cmd:nuova"; visible: !app.trashMode; onClicked: app.newFolder() }
        Cmd { icon: "cut"; label: qsTr("Taglia (Ctrl+X)"); visible: !app.trashMode; enabled: app.selection.length > 0; onClicked: app.copySel(true) }
        Cmd { icon: "copy"; label: qsTr("Copia (Ctrl+C)"); visible: !app.trashMode; enabled: app.selection.length > 0; onClicked: app.copySel(false) }
        Cmd { icon: "paste"; label: qsTr("Incolla (Ctrl+V)"); visible: !app.trashMode; enabled: ops.hasClipboard; onClicked: app.paste() }
        Cmd { icon: "edit"; label: qsTr("Rinomina (F2)"); visible: !app.trashMode; enabled: app.selection.length === 1; onClicked: app.renameSel() }
        Cmd { icon: "archive"; label: qsTr("Comprimi in ZIP"); visible: !app.trashMode && ops.zip; enabled: app.selection.length > 0; onClicked: app.compressSel() }
        Cmd { icon: "trash"; label: qsTr("Sposta nel cestino (Canc)"); objectName: "cmd:cestina"; visible: !app.trashMode; enabled: app.selection.length > 0; onClicked: app.trashSel() }
        Cmd { icon: "history"; label: qsTr("Ripristina"); objectName: "cmd:ripristina"; visible: app.trashMode; enabled: app.selection.length > 0; onClicked: app.restoreSel() }
        Cmd { icon: "close"; label: qsTr("Elimina definitivamente (Maiusc+Canc)"); enabled: app.selection.length > 0; onClicked: app.askDelete() }
        Cmd { icon: "info"; label: qsTr("Proprietà"); visible: !app.trashMode; enabled: app.selection.length === 1; onClicked: props.show(app.selection[0]) }
        OmniButton { visible: app.trashMode; text: qsTr("Svuota cestino"); enabled: app.trashList.length > 0; onClicked: app.emptyTrash() }
    }
    Row {
        anchors { top: commands.top; right: parent.right; rightMargin: 12 }
        spacing: 6; height: 34
        OmniChip { text: qsTr("Nascosti"); checked: app.showHidden; visible: !app.trashMode; onClicked: app.showHidden = !app.showHidden }
        OmniChip { text: qsTr("Anteprima"); checked: app.showPreview; onClicked: app.showPreview = !app.showPreview }
        OmniIconButton { width: 34; height: 34; iconSize: 16; icon: "list"; label: qsTr("Dettagli"); checked: !app.gridView; onClicked: app.gridView = false }
        OmniIconButton { width: 34; height: 34; iconSize: 16; icon: "grid"; label: qsTr("Icone"); objectName: "vista:icone"; checked: app.gridView; onClicked: app.gridView = true }
    }

    // ----------------------------------------------------------------------- contenuto
    Item {
        id: body
        anchors { top: commands.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: status.top }
        Sidebar {
            id: side
            width: 230; height: parent.height
            currentPath: app.currentPath; trashMode: app.trashMode
            places: app.places; volumes: app.volumeList
            onOpenPath: (p) => app.navigate(p)
            onOpenTrash: app.openTrash()
            onDropped: (urls, p, copy) => app.dropOn(urls, p, copy)
        }
        FileList {
            id: files
            anchors { left: side.right; right: preview.visible ? preview.left : parent.right; top: parent.top; bottom: parent.bottom; topMargin: 4 }
            folder: folder
            trashItems: app.trashMode ? app.trashList.filter(x => !search.text || x.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0) : null
            grid: app.gridView
            selection: app.selection
            currentPath: app.currentPath
            onSelect: (row, path, mods) => app.select(row, path, mods)
            onActivate: (row) => app.activate(row)
            onClearSelection: app.selection = []
            onContextMenu: (row, x, y) => { if (row >= 0 && app.selection.indexOf(files.row(row).path) < 0) app.select(row, files.row(row).path, 0); menu.open(mapToItem(app.contentItem, x, y)) }
            onDropOn: (urls, p, copy) => app.dropOn(urls, p, copy)
        }
        PreviewPane {
            id: preview
            visible: app.showPreview && app.width > 1000
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 300; item: app.selectedItem; ops: ops
            Rectangle { width: 1; height: parent.height; color: Theme.outline }
        }
    }

    // --------------------------------------------------------- stato e operazioni in corso
    Rectangle {
        id: status
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 34 + jobsCol.height
        color: Theme.dark ? "#0A0E1A" : "#E4E8F2"
        Column {
            id: jobsCol
            x: 12; width: parent.width - 24
            Repeater {
                model: ops.jobs
                delegate: Item {
                    required property var modelData
                    width: jobsCol.width; height: 36
                    Text { y: 4; text: modelData.label; color: Theme.textPrimary; font.pixelSize: 12; font.family: Theme.fontFamily }
                    Rectangle { y: 22; width: parent.width - 110; height: 6; radius: 3; color: Theme.surfaceSunken
                        Rectangle { width: parent.width * modelData.fraction; height: parent.height; radius: 3; color: Theme.accent } }
                    OmniButton { anchors.right: parent.right; y: 2; text: qsTr("Annulla"); ghost: true; onClicked: ops.cancel(modelData.id) }
                }
            }
        }
        Text {
            anchors { left: parent.left; leftMargin: 14; bottom: parent.bottom; bottomMargin: 9 }
            color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily
            text: (app.trashMode ? qsTr("%n elementi nel cestino", "", app.trashList.length) : (folder.searchText ? qsTr("%n risultati", "", folder.count) : qsTr("%n elementi", "", folder.count)))
                  + (app.selection.length ? qsTr(" · %n selezionati", "", app.selection.length) : "")
                  + (app.selectedItem && !app.selectedItem.isDir ? " · " + Sys.humanBytes(app.selectedItem.size) : "")
        }
        Text {
            objectName: "esplora:messaggio"
            anchors { right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 9 }
            width: parent.width * 0.55; horizontalAlignment: Text.AlignRight; elide: Text.ElideMiddle
            text: app.message; font.pixelSize: 12; font.family: Theme.fontFamily
            color: app.messageKind === 2 ? Theme.danger : (app.messageKind === 1 ? Theme.success : Theme.textSecondary)
        }
    }

    // -------------------------------------------------------------------- menu contestuale
    MouseArea { anchors.fill: parent; visible: menu.visible; z: 9; acceptedButtons: Qt.AllButtons; onPressed: menu.visible = false }
    Rectangle {
        id: menu
        objectName: "esplora:menu"
        visible: false; z: 10
        width: 240; height: menuCol.height + 12; radius: 10
        color: Theme.dark ? "#1A2136" : "#FFFFFF"; border.color: Theme.outline
        function open(p) { x = Math.min(p.x, app.width - width - 8); y = Math.min(p.y, app.height - height - 8); visible = true }
        function act(f) { visible = false; f() }
        readonly property bool any: app.selection.length > 0
        readonly property bool one: app.selection.length === 1
        readonly property bool isZip: one && !app.trashMode && /\.zip$/i.test(app.selection[0])
        Column {
            id: menuCol
            x: 6; y: 6; width: parent.width - 12
            component MItem: Rectangle {
                property string text; property string hint; signal triggered()
                width: menuCol.width; height: visible ? 32 : 0; radius: 6; color: mi.containsMouse ? Theme.hover : "transparent"
                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.text; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.hint; color: Theme.textTertiary; font.pixelSize: 11; font.family: Theme.fontFamily }
                MouseArea { id: mi; anchors.fill: parent; hoverEnabled: true; onClicked: parent.triggered() }
            }
            MItem { visible: menu.one && !app.trashMode; text: qsTr("Apri"); hint: qsTr("Invio"); onTriggered: menu.act(() => app.activate(folder.indexOfPath(app.selection[0]))) }
            MItem { visible: menu.one && !app.trashMode && !!app.selectedItem && app.selectedItem.isDir; text: qsTr("Apri in una nuova scheda"); onTriggered: menu.act(() => app.newTab(app.selection[0])) }
            MItem { visible: menu.any && !app.trashMode; text: qsTr("Taglia"); hint: "Ctrl+X"; onTriggered: menu.act(() => app.copySel(true)) }
            MItem { visible: menu.any && !app.trashMode; text: qsTr("Copia"); hint: "Ctrl+C"; onTriggered: menu.act(() => app.copySel(false)) }
            MItem { visible: !app.trashMode && ops.hasClipboard; text: qsTr("Incolla"); hint: "Ctrl+V"; onTriggered: menu.act(app.paste) }
            MItem { visible: menu.one && !app.trashMode; text: qsTr("Rinomina"); hint: "F2"; onTriggered: menu.act(app.renameSel) }
            MItem { visible: menu.any && !app.trashMode && ops.zip; text: qsTr("Comprimi in ZIP"); onTriggered: menu.act(app.compressSel) }
            MItem { visible: menu.isZip && ops.zip; text: qsTr("Estrai qui"); onTriggered: menu.act(() => app.extractHere(app.selection[0])) }
            MItem { visible: !menu.any && !app.trashMode; text: qsTr("Nuova cartella"); hint: "Ctrl+Maiusc+N"; onTriggered: menu.act(app.newFolder) }
            MItem { visible: menu.any && !app.trashMode; text: qsTr("Sposta nel cestino"); hint: qsTr("Canc"); onTriggered: menu.act(app.trashSel) }
            MItem { visible: menu.any && app.trashMode; text: qsTr("Ripristina"); onTriggered: menu.act(app.restoreSel) }
            MItem { visible: menu.any; text: qsTr("Elimina definitivamente…"); hint: qsTr("Maiusc+Canc"); onTriggered: menu.act(app.askDelete) }
            MItem { visible: menu.one && !app.trashMode; text: qsTr("Proprietà"); onTriggered: menu.act(() => props.show(app.selection[0])) }
            MItem { visible: !menu.any && !app.trashMode; text: qsTr("Proprietà della cartella"); onTriggered: menu.act(() => props.show(app.currentPath)) }
        }
    }

    // ---------------------------------------------------------------------- finestre di dialogo
    component Dialog: Item {
        id: dlg
        default property alias content: box.data
        property string heading
        anchors.fill: parent; z: 20; visible: false
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.45); MouseArea { anchors.fill: parent } }
        Rectangle {
            id: box
            anchors.centerIn: parent; width: 460; height: childrenRect.height + 40; radius: 12
            color: Theme.dark ? "#1A2136" : "#FFFFFF"; border.color: Theme.outline
            Text { x: 20; y: 18; text: dlg.heading; color: Theme.textPrimary; font.pixelSize: 17; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
        }
    }
    Dialog {
        id: nameDlg
        objectName: "esplora:nome"
        property var callback: null
        function ask(h, initial, cb) { heading = h; field.text = initial; callback = cb; visible = true; field.forceActiveFocus()
            const dot = initial.lastIndexOf("."); field.select(0, dot > 0 ? dot : initial.length) }
        function accept() { if (callback && callback(field.text.trim()) !== false) visible = false }
        Rectangle { x: 20; y: 56; width: 420; height: 38; radius: 8; color: Theme.surfaceSunken; border.color: Theme.accent
            TextInput { id: field; objectName: "esplora:nome:campo"; anchors.fill: parent; anchors.margins: 10; color: Theme.textPrimary; font.pixelSize: 14; font.family: Theme.fontFamily; selectByMouse: true; clip: true
                onAccepted: nameDlg.accept(); Keys.onEscapePressed: nameDlg.visible = false } }
        Row { x: 20; y: 110; spacing: 8
            OmniButton { text: qsTr("OK"); primary: true; objectName: "esplora:nome:ok"; onClicked: nameDlg.accept() }
            OmniButton { text: qsTr("Annulla"); ghost: true; onClicked: nameDlg.visible = false } }
    }
    Dialog {
        id: confirm
        objectName: "esplora:conferma"
        heading: qsTr("Conferma")
        property var action: null
        property alias text: ctext.text
        property alias okText: cok.text
        function ask(t, ok, f) { text = t; okText = ok; action = f; visible = true }
        Text { id: ctext; x: 20; y: 56; width: 420; wrapMode: Text.Wrap; color: Theme.textSecondary; font.pixelSize: 14; font.family: Theme.fontFamily }
        Row { x: 20; y: ctext.y + ctext.height + 20; spacing: 8
            OmniButton { id: cok; objectName: "esplora:conferma:ok"; primary: true; onClicked: { confirm.visible = false; if (confirm.action) confirm.action() } }
            OmniButton { text: qsTr("Annulla"); ghost: true; onClicked: confirm.visible = false } }
    }
    Dialog {
        id: props
        objectName: "esplora:proprieta"
        property var p: ({})
        property string sizeText: ""
        property int sizeJob: -1
        heading: qsTr("Proprietà")
        function show(path) {
            p = ops.properties(path); visible = true
            if (p.isDir) { sizeText = qsTr("calcolo in corso…"); sizeJob = ops.folderSize(path) } else sizeText = Sys.humanBytes(p.size)
        }
        Connections { target: ops; function onSizeReady(id, bytes, files) { if (id === props.sizeJob) props.sizeText = qsTr("%1 · %n file", "", files).arg(Sys.humanBytes(bytes)) } }
        Column {
            x: 20; y: 56; width: 420; spacing: 6
            component KV: Row { property string k; property string v; spacing: 8
                Text { width: 130; text: parent.k; color: Theme.textTertiary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Text { width: 282; text: parent.v; wrapMode: Text.WrapAnywhere; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily } }
            KV { k: qsTr("Nome"); v: props.p.name || "" }
            KV { k: qsTr("Tipo"); v: (props.p.type || "") + (props.p.isLink ? qsTr(" (collegamento a %1)").arg(props.p.target) : "") }
            KV { k: qsTr("Percorso"); v: props.p.folder || "" }
            KV { k: qsTr("Dimensione"); v: props.sizeText }
            KV { k: qsTr("Modificato"); v: props.p.modified ? Qt.formatDateTime(props.p.modified, "dd/MM/yyyy HH:mm:ss") : "" }
            KV { k: qsTr("Creato"); v: props.p.created ? Qt.formatDateTime(props.p.created, "dd/MM/yyyy HH:mm:ss") : qsTr("non registrato dal file system") }
            KV { k: qsTr("Proprietario"); v: (props.p.owner || "") + " · " + qsTr("gruppo %1").arg(props.p.group || "") }
            KV { k: qsTr("Unità"); v: (props.p.volume || "") + " · " + qsTr("%1 liberi").arg(Sys.humanBytes(props.p.free)) }
            Text { topPadding: 8; text: qsTr("Permessi") + (props.p.mine ? "" : qsTr(" (solo il proprietario può modificarli)")); color: Theme.textTertiary; font.pixelSize: 13; font.family: Theme.fontFamily }
            Grid {
                columns: 4; columnSpacing: 14; rowSpacing: 6
                Repeater {
                    model: [qsTr("Proprietario"), qsTr("Gruppo"), qsTr("Altri")]
                    delegate: Item { id: prow; required property int index; required property string modelData; width: 412; height: 26
                        Row { spacing: 14
                            Text { width: 110; text: modelData; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                            Repeater { model: [[4, qsTr("lettura")], [2, qsTr("scrittura")], [1, props.p.isDir ? qsTr("accesso") : qsTr("esecuzione")]]
                                delegate: OmniChip { required property var modelData
                                    readonly property int bit: modelData[0] << (3 * (2 - prow.index))
                                    text: modelData[1]; checked: ((props.p.mode || 0) & bit) !== 0; enabled: !!props.p.mine
                                    onClicked: { const e = ops.setPermissions(props.p.path, (props.p.mode || 0) ^ bit); if (e) app.say(e, 2); props.p = ops.properties(props.p.path) } } } } }
                }
            }
            Item { width: 1; height: 8 }
            OmniButton { text: qsTr("Chiudi"); primary: true; onClicked: props.visible = false }
        }
    }
}
