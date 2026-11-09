import QtQuick
import QtQuick.Window
import QtCore
import OmniDesign
import OmniShell
import OmniDesktop

// Sessione OMNI: unica interfaccia del desktop sopra KWin (il pannello e il menu di Plasma
// non sono attivi in questa sessione). Superfici: sfondo, barra delle applicazioni,
// pannelli a comparsa (Start, impostazioni rapide, notifiche), fumetti delle notifiche.
QtObject {
    id: session

    // ---------- stato ----------
    property string popup: ""                 // "", "start", "quick", "notifications", "menu"
    property date now: new Date()
    property var services: Services {}
    property var appIndex: AppIndex { model: appModel }
    readonly property int availableHeight: Screen.desktopAvailableHeight > 0 ? Screen.desktopAvailableHeight : 1000
    property var menuItems: []                 // menu contestuale (barra o Start)
    property real menuX: 0
    property real menuY: 0

    property Settings prefs: Settings {
        category: "OmniShell"
        property bool dark: true
        property int accent: 0
        property bool reducedMotion: false
        property var startPins: []
        property var barPins: []
        property bool pinsInitialized: false
    }
    property Binding pinsToTasks: Binding { target: session.services.tasks; property: "pinned"; value: session.barPins; when: session.services.tasks !== null }
    property var startPins: prefs.startPins
    property var barPins: prefs.barPins

    // ---------- rete (stato reale da NetworkManager) ----------
    readonly property bool networkConnected: systemStatus.networkConnected
    readonly property string networkIcon: !systemStatus.networkAvailable ? "network-off"
        : !systemStatus.networkConnected ? "network-off"
        : systemStatus.networkType === "wifi" ? "wifi" : systemStatus.networkType === "ethernet" ? "ethernet" : "globe"
    readonly property string networkLabel: !systemStatus.networkAvailable ? qsTr("NetworkManager non disponibile")
        : systemStatus.networkConnected ? (systemStatus.networkName || qsTr("Connesso")) : qsTr("Non connesso")

    // ---------- azioni ----------
    function toggle(p) { popup = popup === p ? "" : p }
    function close() { popup = "" }
    function openStart(searchFocus) { popup = "start"; if (searchFocus) Qt.callLater(() => popupWin.start.focusSearch()) }
    function launchEntry(e) {
        if (!e || !e.filePath) return
        close()
        noteLaunch(e.desktopId)
        if (!omniLauncher.launch(e.filePath)) notificationServer.postLocal(qsTr("Avvio non riuscito"), e.name, 1)
    }
    function launchById(id) { const e = appIndex.find(id); if (e) launchEntry(e); else notificationServer.postLocal(qsTr("Applicazione non installata"), id, 1) }
    function noteLaunch(id) { console.info("avvio dalla shell: " + id + " t=" + shellPerf.epochMs()) }
    function setDark(d) { Theme.dark = d; prefs.dark = d }
    function setReducedMotion(r) { Theme.reducedMotion = r; prefs.reducedMotion = r }

    function urlFor(id) { return "applications:" + id }
    function isBarPinned(id) { return barPins.indexOf(urlFor(id)) >= 0 }
    function setBarPinned(id, on) {
        const u = urlFor(id)
        const l = barPins.filter(x => x !== u)
        if (on) l.push(u)
        prefs.barPins = l
    }
    function isStartPinned(id) { return startPins.indexOf(id) >= 0 }
    function setStartPinned(id, on) {
        const l = startPins.filter(x => x !== id)
        if (on) l.push(id)
        prefs.startPins = l
    }
    function showMenu(items, item) {
        const p = item.mapToItem(null, 0, 0)
        menuItems = items
        menuX = p.x
        menuY = p.y
        popup = "menu"
    }
    // menu di una voce della barra: finestre del gruppo, nuova finestra, fissa, chiudi
    function openTaskMenu(row, item, model) {
        const tasks = services.tasks
        const entry = appIndex.find(model.LauncherUrlWithoutIcon || model.AppId)
        const items = []
        if (model.IsGroupParent === true && model.ChildCount > 1)
            for (let i = 0; i < model.ChildCount; ++i)
                items.push({ label: tasks.model.data(tasks.index(row, i), Qt.DisplayRole) || qsTr("Finestra %1").arg(i + 1), icon: "layers", act: () => tasks.activateChild(row, i) })
        if (entry) items.push({ label: entry.name, icon: "plus", act: () => tasks.newInstance(row) })
        if (entry) items.push(isBarPinned(entry.desktopId)
            ? { label: qsTr("Rimuovi dalla barra"), icon: "pin", act: () => setBarPinned(entry.desktopId, false) }
            : { label: qsTr("Aggiungi alla barra"), icon: "pin", act: () => setBarPinned(entry.desktopId, true) })
        if (model.IsWindow === true || model.IsGroupParent === true)
            items.push({ label: model.ChildCount > 1 ? qsTr("Chiudi tutte le finestre") : qsTr("Chiudi finestra"), icon: "close", act: () => tasks.close(row) })
        showMenu(items, item)
    }
    function openAppMenu(entry, item) {
        showMenu([
            { label: qsTr("Apri"), icon: "chevron-right", act: () => launchEntry(entry) },
            isStartPinned(entry.desktopId) ? { label: qsTr("Rimuovi da Start"), icon: "pin", act: () => setStartPinned(entry.desktopId, false) }
                                           : { label: qsTr("Aggiungi a Start"), icon: "pin", act: () => setStartPinned(entry.desktopId, true) },
            isBarPinned(entry.desktopId) ? { label: qsTr("Rimuovi dalla barra"), icon: "pin", act: () => setBarPinned(entry.desktopId, false) }
                                         : { label: qsTr("Aggiungi alla barra"), icon: "pin", act: () => setBarPinned(entry.desktopId, true) }
        ], item)
    }

    // App proposte al primo accesso (solo quelle realmente installate)
    function initPins() {
        if (prefs.pinsInitialized) return
        const want = ["org.mozilla.firefox.desktop", "firefox.desktop", "org.kde.dolphin.desktop", "org.kde.konsole.desktop",
                      "systemsettings.desktop", "org.kde.systemsettings.desktop", "org.kde.discover.desktop", "org.kde.kwrite.desktop",
                      "org.kde.kate.desktop", "org.kde.okular.desktop", "org.kde.gwenview.desktop", "org.kde.ark.desktop",
                      "org.kde.kcalc.desktop", "org.kde.elisa.desktop", "org.kde.spectacle.desktop", "org.kde.plasma-systemmonitor.desktop",
                      "org.kde.kinfocenter.desktop", "org.kde.filelight.desktop"]
        const sp = [], bp = []
        for (const id of want) {
            const e = appIndex.find(id)
            if (!e || sp.indexOf(e.desktopId) >= 0) continue
            sp.push(e.desktopId)
            if (bp.length < 5) bp.push(urlFor(e.desktopId))
        }
        prefs.startPins = sp
        prefs.barPins = bp
        prefs.pinsInitialized = true
    }

    // ---------- orologio (aggiornato al cambio di minuto, non ogni secondo) ----------
    property Timer clock: Timer {
        running: true; repeat: true
        interval: 60000 - (new Date().getSeconds() * 1000 + new Date().getMilliseconds())
        onTriggered: { session.now = new Date(); interval = 60000 - (session.now.getSeconds() * 1000 + session.now.getMilliseconds()) }
    }

    // ---------- servizi di sistema ----------
    property Connections metaKey: Connections {
        target: plasmaShell
        function onStartRequested() { session.toggle("start") }
        function onShowDesktopRequested() { session.close(); kwinActions.invokeShortcut("Show Desktop") }
    }
    property Connections control: Connections {
        target: shellControl
        function onPopupRequested(name) { session.popup = name === "chiudi" ? "" : name }
    }
    property Connections sessionErrors: Connections {
        target: sessionActions
        function onActionFailed(what, reason) { notificationServer.postLocal(qsTr("Operazione non riuscita: %1").arg(what), reason, 2) }
    }
    property Connections systemErrors: Connections {
        target: systemStatus
        function onFailed(what, reason) { notificationServer.postLocal(qsTr("Operazione non riuscita: %1").arg(what), reason, 1) }
    }
    property Connections kwinErrors: Connections {
        target: kwinActions
        function onFailed(what, reason) { notificationServer.postLocal(qsTr("Operazione non riuscita: %1").arg(what), reason, 1) }
    }

    // ---------- superfici ----------
    property var backgroundWin: LayerWindow {
        objectName: "sfondo"
        scopeName: "omni-sfondo"
        shellLayer: layerBackground
        edges: edgeTop | edgeBottom | edgeLeft | edgeRight
        zone: -1
        width: Screen.width; height: Screen.height
        color: Theme.background
        visible: true
        Wallpaper { anchors.fill: parent; animate: false }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: session.close() }
    }

    property var barWin: LayerWindow {
        id: barWindow
        objectName: "barra"
        scopeName: "omni-barra"
        shellLayer: layerTop
        edges: edgeBottom | edgeLeft | edgeRight
        zone: 48
        width: Screen.width; height: 48
        visible: true
        property bool firstFrame: false
        onFrameSwapped: if (!firstFrame) {
            firstFrame = true
            shellPerf.mark("primo fotogramma")
            Qt.callLater(session.afterFirstFrame)
        }
        Taskbar { anchors.fill: parent; session: session }
    }

    property var popupWin: LayerWindow {
        id: popupWindow
        objectName: "pannelli"
        scopeName: "omni-pannelli"
        shellLayer: layerTop
        edges: edgeTop | edgeBottom | edgeLeft | edgeRight
        zone: 0
        keyboard: session.popup !== "" ? keyboardExclusive : keyboardNone
        width: Screen.width; height: Screen.height - 48
        visible: session.popup !== ""
        property alias start: startMenu
        onVisibleChanged: if (visible) {
            if (session.popup === "start") { startMenu.reset(); startMenu.focusSearch() }
            if (session.popup === "quick") quickPanel.reset()
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: session.close()
            // clic fuori dai pannelli: chiude (come in Windows)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: session.close() }
            StartMenu {
                id: startMenu
                session: session
                shown: session.popup === "start"
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
                focus: shown
            }
            QuickPanel {
                id: quickPanel
                session: session
                shown: session.popup === "quick"
                anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                focus: shown
            }
            NotificationPanel {
                id: notePanel
                session: session
                shown: session.popup === "notifications"
                anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                focus: shown
            }
            ContextMenu {
                session: session
                visible: session.popup === "menu"
                x: Math.min(parent.width - width - 8, Math.max(8, session.menuX))
                y: Math.min(parent.height - height - 8, session.menuY - height - 8 < 8 ? session.menuY + 8 : session.menuY - height - 8)
            }
        }
    }

    property var toastWin: LayerWindow {
        objectName: "notifiche"
        scopeName: "omni-notifiche"
        shellLayer: layerOverlay
        edges: edgeBottom | edgeRight
        zone: 0
        width: 396; height: Math.max(1, toasts.implicitHeight + 16)
        visible: toasts.ids.length > 0 && session.popup !== "notifications"
        ToastStack { id: toasts; x: 8; y: 8; onOpenCenter: session.popup = "notifications" }
    }

    function afterFirstFrame() {
        services.loadLate()
        systemStatus.refresh()
        sessionActions.refresh()
        initPins()
        shellPerf.mark("servizi collegati")
    }

    Component.onCompleted: {
        Theme.dark = prefs.dark
        Theme.accentIndex = prefs.accent
        Theme.reducedMotion = prefs.reducedMotion || initialReducedMotion
        Theme.lowPower = true          // sfondo statico: nessuna animazione continua nella sessione
        services.loadEarly()
        console.info("sessione OMNI: interfaccia caricata (" + appModel.count + " applicazioni, finestre " + (services.tasks ? "reali" : "NON disponibili") + ")")
    }
}
