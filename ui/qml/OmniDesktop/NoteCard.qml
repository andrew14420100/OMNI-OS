import QtQuick
import OmniDesign

// Notifica reale (dal server org.freedesktop.Notifications di OMNI Shell).
Rectangle {
    id: card
    property var note: null            // ruoli: notificationId, appName, appIcon, summary, body, actions, urgency, created, expired
    property bool toast: false
    signal closed()
    width: parent ? parent.width : 360
    height: col.implicitHeight + 24
    radius: 10
    color: Theme.dark ? "#1B2238" : "#FFFFFF"
    border.color: note && note.urgency === 2 ? Theme.danger : Theme.outline
    objectName: "note:" + (note ? note.notificationId : 0)
    Accessible.role: Accessible.AlertMessage
    Accessible.name: note ? note.summary + ". " + note.body : ""

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; rightMargin: 36 }
        spacing: 4
        Row {
            spacing: 8
            Image {
                width: 16; height: 16
                visible: card.note && card.note.appIcon !== ""
                source: card.note && card.note.appIcon ? "image://omniicon/" + encodeURIComponent(card.note.appIcon) : ""
                sourceSize: Qt.size(32, 32); asynchronous: true
            }
            Text { text: card.note ? card.note.appName : ""; color: Theme.textSecondary; font.pixelSize: 11; font.family: Theme.fontFamily }
            Text { text: card.note && card.note.created ? Qt.formatTime(card.note.created, "HH:mm") : ""; color: Theme.textTertiary; font.pixelSize: 11; font.family: Theme.fontFamily }
        }
        Text { width: parent.width; text: card.note ? card.note.summary : ""; color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold; font.family: Theme.fontFamily; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
        Text { width: parent.width; visible: text !== ""; text: card.note ? card.note.body : ""; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily; wrapMode: Text.WordWrap; maximumLineCount: card.toast ? 3 : 6; elide: Text.ElideRight; textFormat: Text.PlainText }
        Flow {
            width: parent.width; spacing: 6
            visible: card.note && !card.note.expired && card.note.actions && card.note.actions.length > 0
            Repeater {
                model: card.note && card.note.actions ? card.note.actions : []
                delegate: OmniButton { required property var modelData; text: modelData.label; onClicked: notificationServer.invokeAction(card.note.notificationId, modelData.key) }
            }
        }
    }
    OmniIconButton {
        objectName: "note:close"
        anchors { right: parent.right; top: parent.top; margins: 4 }
        icon: "close"; label: qsTr("Elimina notifica"); iconSize: 14
        onClicked: card.closed()
    }
}
