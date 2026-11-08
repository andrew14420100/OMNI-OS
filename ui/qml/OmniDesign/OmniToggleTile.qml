import QtQuick
import QtQuick.Layouts

// Riquadro commutabile delle Impostazioni rapide.
// prototype: true = non collegato al sistema reale (mostra l'etichetta "Prototipo").
Rectangle {
    id: root
    property string icon: "sparkle"
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool prototype: false
    signal toggled(bool checked)

    implicitWidth: 196; implicitHeight: 80
    radius: Theme.radius
    activeFocusOnTab: true
    color: checked ? Theme.accent : Theme.surfaceRaised
    border.color: activeFocus ? Theme.textPrimary : Theme.outline
    border.width: activeFocus ? 2 : 1
    scale: mouse.pressed ? 0.97 : 1.0
    Behavior on color { ColorAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.title
    Accessible.checked: root.checked
    Keys.onSpacePressed: toggle()
    Keys.onReturnPressed: toggle()
    function toggle() { checked = !checked; toggled(checked) }

    RowLayout {
        anchors.fill: parent; anchors.margins: Theme.s3; spacing: Theme.s3
        OmniIcon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; name: root.icon; color: root.checked ? Theme.onAccent : Theme.textPrimary }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { text: root.title; color: root.checked ? Theme.onAccent : Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: root.subtitle; visible: text.length > 0; color: root.checked ? Theme.onAccent : Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; elide: Text.ElideRight; Layout.fillWidth: true }
            PrototypeBadge { visible: root.prototype; inverted: root.checked }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; onClicked: { root.forceActiveFocus(); root.toggle() } }
}
