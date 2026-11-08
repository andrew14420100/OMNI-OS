import QtQuick

// Pulsante con sola icona; raggiungibile da tastiera (Tab, Spazio, Invio).
Rectangle {
    id: root
    property string icon: "sparkle"
    property bool checked: false
    property string label: icon
    property int badge: 0
    property real iconSize: 20
    property bool round: false
    signal clicked()

    implicitWidth: 40; implicitHeight: 40
    radius: round ? width / 2 : Theme.radiusSmall
    activeFocusOnTab: true
    color: checked ? Theme.accentSoft : (mouse.containsMouse ? Theme.hover : "transparent")
    border.color: activeFocus ? Theme.accent : "transparent"
    border.width: 2
    scale: mouse.pressed ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()

    OmniIcon { anchors.centerIn: parent; width: root.iconSize; height: root.iconSize; name: root.icon; color: root.checked ? Theme.accent : Theme.textPrimary }
    Rectangle {
        visible: root.badge > 0
        anchors { top: parent.top; right: parent.right; topMargin: 3; rightMargin: 2 }
        width: Math.max(16, badgeText.implicitWidth + 8); height: 16; radius: 8
        color: Theme.accent
        border.color: Theme.background; border.width: 2
        Text { id: badgeText; anchors.centerIn: parent; text: root.badge; color: Theme.textOnAccent; font.pixelSize: 9; font.bold: true; font.family: Theme.fontFamily }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.forceActiveFocus(); root.clicked() } }
}
