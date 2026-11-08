import QtQuick
import OmniDesign

// Radice della shell OMNI prototipale. Gira come normale applicazione utente:
// nessun privilegio, nessuna modifica alla sessione KDE reale.
Item {
    id: shell
    property var apps: null
    // scena iniziale: "desktop", "launcher", "notifications", "quicksettings"
    property string scene: "desktop"
    readonly property bool launcherOpen: scene === "launcher"
    readonly property bool notificationsOpen: scene === "notifications"
    readonly property bool quickSettingsOpen: scene === "quicksettings"
    function toggle(s) { scene = (scene === s) ? "desktop" : s }

    NotificationStore {
        id: notifications
        onPosted: (title, body) => toast.show(title, body)
    }
    Component.onCompleted: {
        // Notifiche dimostrative del prototipo (non provengono dal sistema reale).
        notifications.add("OMNI Update Center", qsTr("Sistema aggiornato"), qsTr("Esempio: il deployment 0.1.1 è pronto. Ritorno alla versione precedente disponibile."), "sparkle", true)
        notifications.add("OMNI Security Center", qsTr("Firma verificata"), qsTr("Esempio: immagine accettata solo con firma valida."), "power", true)
        notifications.add("OMNI Prototipo", qsTr("Benvenuto nel prototipo"), qsTr("Le funzioni con l'etichetta «Prototipo» non sono ancora collegate al sistema."), "bell", true)
    }

    Wallpaper { anchors.fill: parent }

    Keys.onEscapePressed: shell.scene = "desktop"
    focus: true

    QuickSettings { anchors.fill: parent; store: notifications; open: shell.quickSettingsOpen; onCloseRequested: shell.scene = "desktop" }
    NotificationCenter { anchors.fill: parent; store: notifications; open: shell.notificationsOpen; onCloseRequested: shell.scene = "desktop" }
    Launcher {
        anchors.fill: parent; apps: shell.apps; open: shell.launcherOpen
        onCloseRequested: shell.scene = "desktop"
        onActivated: (name) => { shell.scene = "desktop"; toast.show(qsTr("Avvio disattivato nel prototipo"), qsTr("«%1» non viene avviata: il prototipo non agisce sulla sessione reale.").arg(name)) }
    }

    Panel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s4
        apps: shell.apps
        notificationCount: notifications.count
        launcherOpen: shell.launcherOpen; notificationsOpen: shell.notificationsOpen; quickSettingsOpen: shell.quickSettingsOpen
        onLauncherRequested: shell.toggle("launcher")
        onNotificationsRequested: shell.toggle("notifications")
        onQuickSettingsRequested: shell.toggle("quicksettings")
        onAppActivated: (name) => toast.show(qsTr("Avvio disattivato nel prototipo"), qsTr("«%1» non viene avviata dal prototipo.").arg(name))
    }

    Toast { id: toast; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: Theme.s5 }

    Text {
        anchors { left: parent.left; bottom: parent.bottom; margins: Theme.s4 }
        text: qsTr("OMNI Shell · prototipo anticipato · non è M4")
        color: Theme.textSecondary; opacity: 0.8; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption
    }
}
