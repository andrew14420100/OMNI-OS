import QtQuick
import OmniDesign

// Menu energia: azioni REALI (sessionActions -> ksmserver / systemd-logind).
// Spegnimento e riavvio chiudono prima le applicazioni, che possono chiedere di salvare;
// se un programma blocca lo spegnimento viene indicato qui.
Rectangle {
    id: menu
    signal done()
    signal beforeAction()
    width: 240
    height: col.implicitHeight + 16
    radius: 10
    color: Theme.dark ? "#1B2238" : "#FFFFFF"
    border.color: Theme.outlineStrong
    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
        spacing: 2
        Repeater {
            model: [
                { id: "lock", label: qsTr("Blocca"), icon: "lock", enabled: true },
                { id: "logout", label: qsTr("Disconnetti"), icon: "logout", enabled: true },
                { id: "suspend", label: qsTr("Sospendi"), icon: "moon", enabled: sessionActions.canSuspend },
                { id: "reboot", label: qsTr("Riavvia"), icon: "restart", enabled: sessionActions.canReboot },
                { id: "shutdown", label: qsTr("Arresta"), icon: "power", enabled: sessionActions.canShutdown }
            ]
            delegate: Item {
                id: it
                required property var modelData
                width: col.width; height: 40
                objectName: "power:" + modelData.id
                opacity: modelData.enabled ? 1 : 0.45
                Accessible.role: Accessible.MenuItem
                Accessible.name: modelData.label
                Rectangle { anchors.fill: parent; radius: 6; color: ma.containsMouse && it.modelData.enabled ? Theme.hover : "transparent" }
                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 12
                    OmniIcon { width: 18; height: 18; name: it.modelData.icon; color: Theme.textPrimary }
                    Text { text: it.modelData.label; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true; enabled: it.modelData.enabled
                    onClicked: {
                        menu.beforeAction()
                        menu.done()
                        switch (it.modelData.id) {
                        case "lock": sessionActions.lock(); break
                        case "logout": sessionActions.logout(); break
                        case "suspend": sessionActions.suspend(); break
                        case "reboot": sessionActions.reboot(); break
                        case "shutdown": sessionActions.shutdown(); break
                        }
                    }
                }
            }
        }
        Text {
            visible: sessionActions.inhibitors.length > 0
            width: parent.width; wrapMode: Text.WordWrap
            topPadding: 6; leftPadding: 8; rightPadding: 8
            text: qsTr("In attesa di: ") + sessionActions.inhibitors.join("; ")
            color: Theme.prototype; font.pixelSize: 11; font.family: Theme.fontFamily
        }
        Text {
            visible: !sessionActions.canSuspend && sessionActions.suspendNote !== ""
            width: parent.width; wrapMode: Text.WordWrap
            leftPadding: 8; rightPadding: 8
            text: sessionActions.suspendNote
            color: Theme.textTertiary; font.pixelSize: 11; font.family: Theme.fontFamily
        }
    }
}
