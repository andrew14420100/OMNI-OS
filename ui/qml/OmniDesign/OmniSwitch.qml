import QtQuick

// Interruttore OMNI con animazione del cursore; Spazio/Invio da tastiera.
Item {
    id: root
    property bool checked: false
    property string label: ""
    property bool accentSurface: false
    opacity: enabled ? 1 : 0.4      // disattivato: visibilmente non cliccabile
    signal toggled(bool checked)
    implicitWidth: 40; implicitHeight: 24
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.label
    Accessible.checked: root.checked
    function toggle() { checked = !checked; toggled(checked) }
    Keys.onSpacePressed: toggle()
    Keys.onReturnPressed: toggle()
    Rectangle {
        anchors.fill: parent; radius: height / 2
        color: root.checked ? (root.accentSurface ? Theme.textOnAccent : Theme.accent) : Theme.outlineStrong
        border.color: root.activeFocus ? Theme.textPrimary : "transparent"; border.width: 2
        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
        Rectangle {
            width: parent.height - 6; height: width; radius: width / 2; y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? (root.accentSurface ? Theme.accent : Theme.textOnAccent) : "#FFFFFF"
            Behavior on x { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingEmphasized } }
        }
    }
    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { root.forceActiveFocus(); root.toggle() } }
}
