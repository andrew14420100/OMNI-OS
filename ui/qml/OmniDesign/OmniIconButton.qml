import QtQuick

// Pulsante con sola icona; raggiungibile da tastiera (Tab, Spazio, Invio).
Rectangle {
    id: root
    property string icon: "sparkle"
    property bool checked: false
    property string label: icon
    property int badge: 0
    signal clicked()

    implicitWidth: 44; implicitHeight: 44
    radius: Theme.radiusSmall
    activeFocusOnTab: true
    color: checked ? Theme.accentSoft : (mouse.containsMouse || activeFocus ? Theme.outline : "transparent")
    border.color: activeFocus ? Theme.accent : "transparent"
    border.width: 2
    scale: mouse.pressed ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()

    OmniIcon { anchors.centerIn: parent; width: 22; height: 22; name: root.icon; color: root.checked ? Theme.accent : Theme.textPrimary }
    Rectangle {
        visible: root.badge > 0
        anchors { top: parent.top; right: parent.right; margins: 5 }
        width: Math.max(16, badgeText.implicitWidth + 8); height: 16; radius: 8
        color: Theme.accent
        Text { id: badgeText; anchors.centerIn: parent; text: root.badge; color: Theme.onAccent; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.forceActiveFocus(); root.clicked() } }
}
