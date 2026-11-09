import QtQuick
import OmniDesign
import OmniShell

// Centro notifiche (notifiche REALI delle applicazioni, cronologia della sessione) e calendario.
PanelFrame {
    id: np
    property var session: null
    width: 400
    height: Math.min(860, (session ? session.availableHeight : 900) - 24)
    Keys.onEscapePressed: session.close()

    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        height: 36
        Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Notifiche"); color: Theme.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4
            OmniIconButton {
                objectName: "notes:dnd"
                icon: notificationServer.doNotDisturb ? "bell-off" : "bell"
                label: qsTr("Non disturbare")
                checked: notificationServer.doNotDisturb
                onClicked: notificationServer.doNotDisturb = !notificationServer.doNotDisturb
            }
            OmniButton { objectName: "notes:clear"; text: qsTr("Cancella tutto"); ghost: true; enabled: notificationServer.count > 0; onClicked: notificationServer.clearAll() }
        }
    }
    Text {
        id: status
        anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 16; rightMargin: 16 }
        visible: !notificationServer.available || notificationServer.doNotDisturb
        text: !notificationServer.available ? notificationServer.status : qsTr("Non disturbare: le notifiche arrivano qui senza comparire (tranne quelle urgenti)")
        wrapMode: Text.WordWrap; color: Theme.textSecondary; font.pixelSize: 11; font.family: Theme.fontFamily
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: status.visible ? status.bottom : head.bottom; bottom: cal.top; margins: 16 }
        clip: true
        spacing: 8
        model: notificationServer
        boundsBehavior: Flickable.StopAtBounds
        delegate: NoteCard {
            required property var model
            width: ListView.view.width
            note: model
            onClosed: notificationServer.dismiss(model.notificationId)
        }
        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: qsTr("Nessuna notifica")
            color: Theme.textTertiary; font.pixelSize: 13; font.family: Theme.fontFamily
        }
        add: Transition { enabled: !Theme.reducedMotion; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
        displaced: Transition { enabled: !Theme.reducedMotion; NumberAnimation { property: "y"; duration: 140; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        id: cal
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 330
        radius: np.radius
        color: Theme.dark ? "#10162A" : "#F0F2F8"
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.outline }
        Text {
            id: today
            anchors { left: parent.left; top: parent.top; margins: 16 }
            text: Qt.formatDate(np.session ? np.session.now : new Date(), "dddd d MMMM")
            color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold; font.family: Theme.fontFamily
        }
        CalendarWidget {
            anchors { left: parent.left; right: parent.right; top: today.bottom; bottom: parent.bottom; margins: 12 }
        }
    }
    onVisibleChanged: if (visible) notificationServer.markAllRead()
}
