import QtQuick
import OmniDesign

// Radice della shell OMNI prototipale (v2). Gira come normale applicazione utente:
// nessun privilegio, nessuna modifica alla sessione KDE reale, nessun processo avviato.
FocusScope {
    id: shell
    property var apps: null
    property string userName: ""
    // scena iniziale: "desktop", "launcher", "notifications", "quicksettings"
    property string scene: "desktop"
    readonly property bool launcherOpen: scene === "launcher"
    readonly property bool notificationsOpen: scene === "notifications"
    readonly property bool quickSettingsOpen: scene === "quicksettings"
    readonly property bool appsFromSystem: apps && apps.demo !== undefined ? !apps.demo : true
    function toggle(s) { scene = (scene === s) ? "desktop" : s }

    // voci normalizzate e dock (preferiti della sessione)
    property var catalog: []
    function rebuildCatalog() {
        const out = []
        if (apps) for (let i = 0; i < apps.count; ++i) out.push(AppCatalog.entry(apps.get(i)))
        catalog = out
        if (session.favorites.length === 0) session.favorites = defaultFavorites(out)
    }
    // preferiti iniziali: una per tipo, nell'ordine indicato, poi le prime disponibili
    function defaultFavorites(list) {
        const wanted = ["files", "browser", "terminal", "store", "media", "office", "gaming", "settings", "developer",
                        "texteditor", "photos", "music", "mail", "calculator", "archive", "performance", "help"]
        // strumenti di diagnostica e utilità minori non entrano nel dock predefinito
        const skip = ["bug", "logs", "chars", "generic"]
        const out = []
        wanted.forEach(g => { const e = list.find(x => x.glyph === g && out.indexOf(x.desktopId) < 0); if (e && out.length < 8) out.push(e.desktopId) })
        for (let i = 0; i < list.length && out.length < 8; ++i)
            if (out.indexOf(list[i].desktopId) < 0 && skip.indexOf(list[i].glyph) < 0) out.push(list[i].desktopId)
        return out.slice(0, 8)
    }
    readonly property var dockItems: {
        const fav = session.favorites.map(id => catalog.find(e => e.desktopId === id)).filter(e => !!e)
        const extra = session.opened.filter(id => session.favorites.indexOf(id) < 0).map(id => catalog.find(e => e.desktopId === id)).filter(e => !!e)
        return fav.concat(extra)
    }
    onAppsChanged: rebuildCatalog()
    Connections { target: shell.apps; ignoreUnknownSignals: true; function onCountChanged() { shell.rebuildCatalog() } }

    SessionState { id: session }
    NotificationStore {
        id: notifications
        onPosted: (nid, app, title, body) => toast.show(app, title, body, false)
    }
    function launch(entry, gx, gy) {
        if (!entry) return
        if (scene !== "desktop") scene = "desktop"
        session.noteLaunch(entry.desktopId)
        preview.play(entry, gx, gy)
    }
    Component.onCompleted: {
        rebuildCatalog()
        // Notifiche dimostrative del prototipo (non provengono dal sistema reale).
        notifications.add("OMNI Security Center", qsTr("Firma dell'immagine verificata"), qsTr("Esempio: il sistema accetta solo immagini con firma valida."), "", true, 52)
        notifications.add("OMNI Update Center", qsTr("Aggiornamento pronto"), qsTr("Esempio: il deployment 0.1.1 è pronto. Il ritorno alla versione precedente resta disponibile."), "", true, 34)
        notifications.add("OMNI Update Center", qsTr("Controllo completato"), qsTr("Esempio: nessun altro aggiornamento disponibile."), "", true, 33)
        notifications.add("OMNI Update Center", qsTr("Istantanea creata"), qsTr("Esempio: punto di ripristino creato prima dell'aggiornamento."), "", true, 31)
        notifications.add("OMNI Performance Center", qsTr("Profilo Gioco disponibile"), qsTr("Esempio: priorità alla GPU durante le sessioni di gioco."), "", true, 12)
        notifications.add("OMNI Prototipo", qsTr("Benvenuto in OMNI Shell v2"), qsTr("Le funzioni con l'etichetta «Prototipo» non sono ancora collegate al sistema."), "", true, 0)
    }

    Wallpaper { anchors.fill: parent }

    Keys.onEscapePressed: { if (preview.active) preview.dismiss(); else shell.scene = "desktop" }
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_Meta || (ev.key === Qt.Key_Space && (ev.modifiers & Qt.AltModifier))) { shell.toggle("launcher"); ev.accepted = true }
    }

    // --- desktop: orologio, calendario, schede ---
    Item {
        id: desktop
        anchors.fill: parent
        anchors.topMargin: 72; anchors.bottomMargin: 120
        anchors.leftMargin: Theme.s7; anchors.rightMargin: Theme.s7
        readonly property bool wide: width > 1100
        opacity: shell.launcherOpen ? 0.0 : (shell.quickSettingsOpen || shell.notificationsOpen ? 0.45 : 1)
        scale: shell.launcherOpen ? 0.98 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
        Behavior on scale { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }

        Reveal {
            shown: true; delay: 80
            width: clock.implicitWidth; height: clock.implicitHeight
            ClockWidget { id: clock }
        }
        Reveal {
            shown: true; delay: 160
            y: clock.implicitHeight + Theme.s5
            width: 320; height: cal.implicitHeight
            CalendarWidget { id: cal; width: 320 }
        }
        Reveal {
            visible: desktop.wide
            shown: true; delay: 240
            anchors.right: parent.right
            width: 380; height: cards.implicitHeight
            DesktopCards {
                id: cards; width: 380
                session: session; catalog: shell.catalog; store: notifications; appsFromSystem: shell.appsFromSystem
                onActivated: (e, gx, gy) => shell.launch(e, gx, gy)
            }
        }
    }

    // --- dock ---
    Dock {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s3
        availableWidth: shell.width
        items: shell.dockItems
        session: session
        launcherOpen: shell.launcherOpen
        onLauncherRequested: shell.toggle("launcher")
        onActivated: (e, gx, gy) => shell.launch(e, gx, gy)
        z: 5
    }

    Launcher {
        anchors.fill: parent; apps: shell.apps; session: session; open: shell.launcherOpen
        onCloseRequested: shell.scene = "desktop"
        onActivatedEntry: (e, gx, gy) => shell.launch(e, gx, gy)
        z: 4
    }
    QuickSettings { anchors.fill: parent; store: notifications; userName: shell.userName; open: shell.quickSettingsOpen; onCloseRequested: shell.scene = "desktop"; z: 6 }
    NotificationCenter { anchors.fill: parent; store: notifications; open: shell.notificationsOpen; onCloseRequested: shell.scene = "desktop"; z: 6 }

    TopBar {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.s2
        notificationCount: notifications.count
        doNotDisturb: notifications.doNotDisturb
        quickSettingsOpen: shell.quickSettingsOpen
        notificationsOpen: shell.notificationsOpen
        onQuickSettingsRequested: shell.toggle("quicksettings")
        onNotificationsRequested: shell.toggle("notifications")
        onLauncherRequested: shell.toggle("launcher")
        z: 7
    }

    LaunchPreview {
        id: preview; anchors.fill: parent; z: 8
        onFinished: session.close(entry ? entry.desktopId : "")
    }
    Toast { id: toast; anchors.horizontalCenter: parent.horizontalCenter; y: 60; z: 9 }

    Text {
        anchors { left: parent.left; bottom: parent.bottom; margins: Theme.s4 }
        text: qsTr("OMNI Shell v2 · prototipo anticipato · non è M4")
        color: Theme.textSecondary; opacity: 0.85; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption
        z: 10
    }
}
