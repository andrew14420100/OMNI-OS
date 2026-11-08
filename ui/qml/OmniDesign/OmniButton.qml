import QtQuick

// Pulsante di testo: variante principale (accento) o secondaria.
Rectangle {
    id: root
    property string text: ""
    property bool primary: false
    signal clicked()
    implicitWidth: label.implicitWidth + Theme.s5
    implicitHeight: 36
    radius: Theme.radiusSmall
    activeFocusOnTab: true
    color: primary ? Theme.accent : (mouse.containsMouse ? Theme.outline : "transparent")
    border.color: activeFocus ? Theme.accent : Theme.outline
    border.width: activeFocus ? 2 : 1
    scale: mouse.pressed ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Text {
        id: label; anchors.centerIn: parent; text: root.text
        color: root.primary ? Theme.onAccent : Theme.textPrimary
        font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.Medium
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
