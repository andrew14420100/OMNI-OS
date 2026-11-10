import QtQuick
import QtQuick.Window
import OmniDesign
import OmniShell
import OmniDesktop

// Sessione OMNI: unica interfaccia del desktop sopra KWin (il pannello e il menu di Plasma
// non sono attivi in questa sessione). Superfici: sfondo, barra delle applicazioni,
// pannelli a comparsa (Start, impostazioni rapide, notifiche), fumetti delle notifiche.
QtObject {
    id: omni

    // ---------- stato ----------
    property string popup: ""                 // "", "start", "quick", "notifications", "menu"
    property date now: new Date()
    property var services: Services {}
    property var appIndex: AppIndex { model: appModel }
    readonly property int availableHeight: Screen.desktopAvailableHeight > 0 ? Screen.desktopAvailableHeight : 1000
    property var menuItems: []                 // menu contestuale (barra o Start)
    property bool panelsReady: false           // pannelli creati dopo il primo fotogramma
    property real menuX: 0
    property real menuY: 0

    property var prefs: shellSettings          // preferenze salvate (C++, QSettings)
    property Binding pinsToTasks: Binding { target: omni.services.tasks; property: "pinned"; value: omni.barPins; when: omni.services.tasks !== null }
    property var startPins: prefs.startPins
    property var barPins: prefs.barPins
    // personalizzazione condivisa con OMNI Settings: applicata dal vivo (QFileSystemWatcher)
    readonly property int barSize: [40, 48, 56].indexOf(prefs.barSize) >= 0 ? prefs.barSize : 48
    readonly property string wallpaperFile: prefs.wallpaper && omniSystem.exists(prefs.wallpaper) ? prefs.wallpaper : ""
    property Connections prefsWatch: Connections {
        target: shellSettings
        function onChanged() {
            if (Theme.dark !== shellSettings.dark) Theme.dark = shellSettings.dark
            if (Theme.accentIndex !== shellSettings.accent) Theme.accentIndex = shellSettings.accent
            const rm = shellSettings.reducedMotion || initialReducedMotion
            if (Theme.reducedMotion !== rm) Theme.reducedMotion = rm
        }
    }

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
    function openStart(searchFocus) { popup = "start"; if (searchFocus) Qt.callLater(() => { if (popupWin.start.item) popupWin.start.item.focusSearch() }) }
    function launchEntry(e) {
        if (!e || !e.filePath) return
        close()
        noteLaunch(e.desktopId)
        if (!omniLauncher.launch(e.filePath)) notificationServer.postLocal(qsTr("Avvio non riuscito"), e.name, 1)
    }
    function launchById(id) { const e = appIndex.find(id); if (e) launchEntry(e); else notificationServer.postLocal(qsTr("Applicazione non installata"), id, 1) }
    function noteLaunch(id) { console.info("avvio dalla shell: " + id + " t=" + shellPerf.epochMs()) }
    function setDark(d) { Theme.dark = d; prefs.dark = d }
    function setReducedMotion(r) { Theme.reducedMotion = r; prefs.reducedMotion = r; kwinActions.setSystemReducedMotion(r) }
    function showMenuAt(items, x, y) { menuItems = items; menuX = x; menuY = y + 8; popup = "menu" }

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
        // multitasking con le funzioni reali di KWin (affiancamento, desktop virtuali)
        if (model.IsWindow === true && model.IsGroupParent !== true) {
            const onWin = (shortcut) => () => { tasks.activate(row); kwinActions.invokeShortcutLater(shortcut) }
            items.push({ label: qsTr("Affianca a sinistra"), icon: "chevron-right", act: onWin("Window Quick Tile Left") })
            items.push({ label: qsTr("Affianca a destra"), icon: "chevron-right", act: onWin("Window Quick Tile Right") })
            items.push({ label: model.IsMaximized ? qsTr("Ripristina dimensioni") : qsTr("Ingrandisci"), icon: "display", act: () => tasks.toggleMaximized(row) })
            if (tasks.desktopCount > 1) items.push({ label: qsTr("Sposta sul desktop successivo"), icon: "layers", act: onWin("Window to Next Desktop") })
        }
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
        // un'app per ruolo: prima quella OMNI, poi l'equivalente KDE (nessun doppione)
        const want = [["org.mozilla.firefox.desktop", "firefox.desktop"], ["org.omnios.Explorer.desktop", "org.kde.dolphin.desktop"],
                      ["org.kde.konsole.desktop"], ["org.omnios.Settings.desktop", "systemsettings.desktop", "org.kde.systemsettings.desktop"],
                      ["org.omnios.Store.desktop", "org.kde.discover.desktop"], ["org.kde.kwrite.desktop", "org.kde.kate.desktop"],
                      ["org.kde.okular.desktop"], ["org.kde.gwenview.desktop"], ["org.kde.ark.desktop"], ["org.kde.kcalc.desktop"],
                      ["org.kde.elisa.desktop"], ["org.kde.spectacle.desktop"], ["org.omnios.TaskManager.desktop", "org.kde.plasma-systemmonitor.desktop"],
                      ["org.kde.filelight.desktop"]]
        const sp = [], bp = []
        for (const group of want) {
            let e = null
            for (const id of group) { e = appIndex.find(id); if (e) break }
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
        onTriggered: { omni.now = new Date(); interval = 60000 - (omni.now.getSeconds() * 1000 + omni.now.getMilliseconds()) }
    }

    // ---------- servizi di sistema ----------
    property Connections metaKey: Connections {
        target: plasmaShell
        function onStartRequested() { omni.toggle("start") }
        function onShowDesktopRequested() { omni.close(); kwinActions.invokeShortcut("Show Desktop") }
    }
    property Connections control: Connections {
        target: shellControl
        function onPopupRequested(name) { omni.popup = name === "chiudi" ? "" : name }
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
        Wallpaper { anchors.fill: parent; animate: false; visible: !wallImage.visible }
        // sfondo scelto dall'utente: decodificato alla risoluzione dello schermo (memoria contenuta)
        Image {
            id: wallImage
            anchors.fill: parent
            visible: omni.wallpaperFile !== "" && status === Image.Ready
            source: omni.wallpaperFile ? "file://" + omni.wallpaperFile : ""
            sourceSize: Qt.size(Screen.width * Screen.devicePixelRatio, Screen.height * Screen.devicePixelRatio)
            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
        }
        // clic destro sul desktop: menu come in Windows (schermo, aspetto, impostazioni)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button !== Qt.RightButton) { omni.close(); return }
                omni.showMenuAt([
                    { label: qsTr("Impostazioni dello schermo"), icon: "display", act: () => { systemStatus.refreshDisplay(); omni.popup = "quick"; Qt.callLater(() => { if (omni.popupWin.quick.item) omni.popupWin.quick.item.page = "display" }) } },
                    { label: Theme.dark ? qsTr("Tema chiaro") : qsTr("Tema scuro"), icon: Theme.dark ? "sun" : "moon", act: () => omni.setDark(!Theme.dark) },
                    { label: qsTr("Personalizza"), icon: "palette", act: () => systemStatus.openOmniApp("impostazioni", "aspetto") },
                    { label: qsTr("Impostazioni"), icon: "settings", act: () => systemStatus.openSettings("") }
                ], mouse.x, mouse.y)
            }
        }
    }

    property var barWin: LayerWindow {
        id: barWindow
        objectName: "barra"
        scopeName: "omni-barra"
        shellLayer: layerTop
        edges: edgeBottom | edgeLeft | edgeRight
        zone: omni.barSize
        width: Screen.width; height: omni.barSize
        visible: true
        property bool firstFrame: false
        onFrameSwapped: if (!firstFrame) {
            firstFrame = true
            shellPerf.mark("primo fotogramma")
            Qt.callLater(omni.afterFirstFrame)
        }
        Taskbar { anchors.fill: parent; session: omni }
    }

    property var popupWin: LayerWindow {
        id: popupWindow
        objectName: "pannelli"
        scopeName: "omni-pannelli"
        shellLayer: layerTop
        edges: edgeTop | edgeBottom | edgeLeft | edgeRight
        zone: 0
        keyboard: omni.popup !== "" ? keyboardExclusive : keyboardNone
        width: Screen.width; height: Screen.height - omni.barSize
        visible: omni.popup !== ""
        property alias start: startLoader
        property alias quick: quickLoader
        onVisibleChanged: if (visible) {
            if (omni.popup === "start" && startLoader.item) { startLoader.item.reset(); startLoader.item.focusSearch() }
            if (omni.popup === "quick" && quickLoader.item) quickLoader.item.reset()
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: omni.close()
            // clic fuori dai pannelli: chiude (come in Windows)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: omni.close() }
            // Pannelli creati in background dopo il primo fotogramma della barra (avvio più rapido);
            // se l'utente apre un pannello prima, viene creato subito.
            Loader {
                id: startLoader
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
                active: omni.panelsReady || omni.popup === "start"
                asynchronous: omni.popup !== "start"
                focus: omni.popup === "start"
                sourceComponent: StartMenu { session: omni; shown: omni.popup === "start"; focus: true }
                onLoaded: if (omni.popup === "start") { item.reset(); item.focusSearch() }
            }
            Loader {
                id: quickLoader
                anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                active: omni.panelsReady || omni.popup === "quick"
                asynchronous: omni.popup !== "quick"
                focus: omni.popup === "quick"
                sourceComponent: QuickPanel { session: omni; shown: omni.popup === "quick"; focus: true }
            }
            Loader {
                id: notesLoader
                anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                active: omni.panelsReady || omni.popup === "notifications"
                asynchronous: omni.popup !== "notifications"
                focus: omni.popup === "notifications"
                sourceComponent: NotificationPanel { session: omni; shown: omni.popup === "notifications"; focus: true }
            }
            ContextMenu {
                session: omni
                visible: omni.popup === "menu"
                x: Math.min(parent.width - width - 8, Math.max(8, omni.menuX))
                y: Math.min(parent.height - height - 8, omni.menuY - height - 8 < 8 ? omni.menuY + 8 : omni.menuY - height - 8)
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
        visible: toasts.ids.length > 0 && omni.popup !== "notifications"
        ToastStack { id: toasts; x: 8; y: 8; onOpenCenter: omni.popup = "notifications" }
    }

    function afterFirstFrame() {
        kwinActions.splashDesktopReady()
        panelsReady = true
        if (softwareRendering) kwinActions.optimizeForSoftwareRendering()
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
