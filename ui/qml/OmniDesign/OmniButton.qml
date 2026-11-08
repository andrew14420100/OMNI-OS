import QtQuick
import QtQuick.Layouts

// Pulsante di testo: principale (accento), secondario o "fantasma".
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool ghost: false
    signal clicked()
    implicitWidth: row.implicitWidth + Theme.s5
    implicitHeight: 34
    radius: Theme.radiusSmall
    activeFocusOnTab: true
    color: primary ? Theme.accent : (mouse.containsMouse ? Theme.pressed : (ghost ? "transparent" : Theme.hover))
    border.color: activeFocus ? Theme.accent : (primary || ghost ? "transparent" : Theme.outline)
    border.width: activeFocus ? 2 : 1
    scale: mouse.pressed ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()
    RowLayout {
        id: row; anchors.centerIn: parent; spacing: 6
        OmniIcon { visible: root.icon.length > 0; Layout.preferredWidth: 16; Layout.preferredHeight: 16; name: root.icon; color: root.primary ? Theme.textOnAccent : Theme.textPrimary }
        Text { text: root.text; color: root.primary ? Theme.textOnAccent : Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: Font.DemiBold }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.forceActiveFocus(); root.clicked() } }
}
