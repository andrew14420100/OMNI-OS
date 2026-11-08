import QtQuick
import QtQuick.Layouts
import OmniDesign

// Scheda di una notifica: icona dell'app, titolo, testo, tempo relativo.
// Si chiude con il pulsante, con Canc da tastiera o trascinandola verso destra.
Item {
    id: root
    property var note: ({})
    property string timeText: ""
    signal dismissed()
    implicitHeight: body.implicitHeight + Theme.s3 * 2
    height: implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.StaticText
    Accessible.name: (note.title || "") + ". " + (note.body || "")
    Keys.onDeletePressed: dismissed()

    Rectangle {
        id: bg
        width: parent.width; height: parent.height
        x: drag.active ? dragTarget.x : 0
        opacity: 1 - Math.min(0.8, Math.abs(x) / width)
        radius: Theme.radius
        color: hover.containsMouse ? Theme.pressed : Theme.surfaceRaised
        border.color: root.activeFocus ? Theme.accent : Theme.outline
        border.width: root.activeFocus ? 2 : 1
        Behavior on x { enabled: !drag.active; NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        RowLayout {
            id: body
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.s3; spacing: Theme.s3
            OmniAppIcon { Layout.alignment: Qt.AlignTop; size: 36; shadow: false; appName: root.note.app || "" }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: root.note.title || ""; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { text: root.timeText; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontMicro }
                }
                Text { Layout.fillWidth: true; text: root.note.body || ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; lineHeight: 1.15 }
            }
        }
        OmniIconButton {
            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
            implicitWidth: 26; implicitHeight: 26; iconSize: 13; icon: "close"; label: qsTr("Chiudi notifica")
            opacity: hover.containsMouse || root.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            onClicked: root.dismissed()
        }
    }
    Item { id: dragTarget; x: 0 }
    MouseArea {
        id: hover; anchors.fill: parent; hoverEnabled: true; z: -1
        drag.target: dragTarget; drag.axis: Drag.XAxis; drag.minimumX: 0; drag.maximumX: width
        property bool active: drag.active
        onReleased: { if (dragTarget.x > width * 0.35) root.dismissed(); dragTarget.x = 0 }
    }
    QtObject { id: drag; readonly property bool active: hover.drag.active }
}
