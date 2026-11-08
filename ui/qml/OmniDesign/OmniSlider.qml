import QtQuick
import QtQuick.Layouts

// Cursore OMNI a pillola (0–1): l'icona vive dentro la traccia riempita.
// Mouse (clic e trascinamento), rotellina e frecce della tastiera.
Item {
    id: root
    property string icon: "volume"
    property string label: ""
    property real value: 0.5
    property bool prototype: false
    implicitWidth: 340; implicitHeight: 44
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: root.label + (root.prototype ? " (" + qsTr("prototipo") + ")" : "")
    Keys.onLeftPressed: value = Math.max(0, Math.round((value - 0.05) * 100) / 100)
    Keys.onRightPressed: value = Math.min(1, Math.round((value + 0.05) * 100) / 100)

    RowLayout {
        anchors.fill: parent; spacing: Theme.s3
        Item {
            id: track; Layout.fillWidth: true; Layout.fillHeight: true
            Rectangle {
                anchors.fill: parent; radius: height / 2
                color: Theme.hover
                border.color: root.activeFocus ? Theme.accent : Theme.outline; border.width: root.activeFocus ? 2 : 1
            }
            Rectangle {
                id: fill
                height: parent.height - 6; y: 3; x: 3; radius: height / 2
                width: Math.max(height, (parent.width - 6) * root.value)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.glow }
                    GradientStop { position: 1; color: Theme.glowPair }
                }
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
                Rectangle {   // impugnatura
                    width: parent.height - 8; height: width; radius: width / 2
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    color: "#FFFFFF"; opacity: 0.95
                }
            }
            OmniIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; name: root.icon; color: root.value > 0.12 ? "#06121A" : Theme.textSecondary }
            MouseArea {
                id: drag; anchors.fill: parent
                function setFrom(mx) { root.value = Math.max(0, Math.min(1, (mx - 3) / (width - 6))) }
                onPressed: (m) => { root.forceActiveFocus(); setFrom(m.x) }
                onPositionChanged: (m) => setFrom(m.x)
                onWheel: (w) => { root.value = Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))) }
            }
        }
        Text { text: Math.round(root.value * 100) + "%"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Medium; Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight }
        PrototypeBadge { visible: root.prototype }
    }
}
