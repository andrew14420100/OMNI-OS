import QtQuick

// Etichetta contestuale (nome dell'app nel dock, suggerimenti).
Rectangle {
    id: root
    property string text: ""
    property bool shown: false
    width: label.implicitWidth + Theme.s4; height: label.implicitHeight + Theme.s2 + 2
    radius: Theme.radiusSmall
    color: Theme.dark ? "#0B1020" : "#1A2136"
    border.color: Qt.rgba(1, 1, 1, 0.12)
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.92
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
    Text {
        id: label; anchors.centerIn: parent; text: root.text
        color: "#F3F6FD"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Medium
    }
}
