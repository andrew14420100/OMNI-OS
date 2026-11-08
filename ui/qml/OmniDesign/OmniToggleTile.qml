import QtQuick
import QtQuick.Layouts

// Riquadro commutabile delle Impostazioni rapide.
// prototype: true = non collegato al sistema reale (etichetta "Prototipo").
Rectangle {
    id: root
    property string icon: "sparkle"
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool prototype: false
    property bool large: false
    signal toggled(bool checked)

    implicitWidth: 176; implicitHeight: large ? 76 : 64
    radius: Theme.radius
    activeFocusOnTab: true
    color: checked ? Theme.accent : (mouse.containsMouse ? Theme.pressed : Theme.hover)
    border.color: activeFocus ? Theme.textPrimary : (checked ? "transparent" : Theme.outline)
    border.width: activeFocus ? 2 : 1
    scale: mouse.pressed ? 0.97 : 1.0
    Behavior on color { ColorAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.title + (root.prototype ? " (" + qsTr("prototipo") + ")" : "")
    Accessible.checked: root.checked
    Keys.onSpacePressed: toggle()
    Keys.onReturnPressed: toggle()
    function toggle() { checked = !checked; toggled(checked) }

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: Theme.s3; anchors.rightMargin: Theme.s3; spacing: Theme.s3
        Rectangle {
            Layout.preferredWidth: root.large ? 40 : 34; Layout.preferredHeight: Layout.preferredWidth; radius: width / 2
            color: root.checked ? Qt.rgba(0, 0, 0, Theme.dark ? 0.14 : 0.16) : Theme.surfaceRaised
            border.color: root.checked ? "transparent" : Theme.outline
            OmniIcon { anchors.centerIn: parent; width: 20; height: 20; name: root.icon; color: root.checked ? Theme.textOnAccent : Theme.textPrimary }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Text { text: root.title; color: root.checked ? Theme.textOnAccent : Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody - (root.large ? 0 : 1); font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: root.subtitle; visible: text.length > 0 && !root.prototype; color: root.checked ? Theme.textOnAccent : Theme.textSecondary; opacity: root.checked ? 0.85 : 1; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; elide: Text.ElideRight; Layout.fillWidth: true }
            PrototypeBadge { visible: root.prototype; inverted: root.checked }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.forceActiveFocus(); root.toggle() } }
}
