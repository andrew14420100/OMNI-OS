import QtQuick
import QtQuick.Layouts

// Cursore OMNI (0–1), regolabile con mouse e frecce della tastiera.
Item {
    id: root
    property string icon: "volume"
    property string label: ""
    property real value: 0.5
    property bool prototype: false
    implicitWidth: 340; implicitHeight: 44
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: root.label
    Keys.onLeftPressed: value = Math.max(0, value - 0.05)
    Keys.onRightPressed: value = Math.min(1, value + 0.05)

    RowLayout {
        anchors.fill: parent; spacing: Theme.s3
        OmniIcon { Layout.preferredWidth: 22; Layout.preferredHeight: 22; name: root.icon; color: Theme.textSecondary }
        Item {
            id: track; Layout.fillWidth: true; Layout.preferredHeight: 28
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 8; radius: 4; color: Theme.outline }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter; height: 8; radius: 4
                width: Math.max(8, parent.width * root.value)
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.auroraCyan } GradientStop { position: 1; color: Theme.auroraViolet } }
            }
            Rectangle {
                width: 20; height: 20; radius: 10; y: (parent.height - height) / 2
                x: Math.max(0, Math.min(parent.width - width, parent.width * root.value - width / 2))
                color: "#FFFFFF"; border.color: root.activeFocus ? Theme.accent : Theme.outline; border.width: 2
                Behavior on x { enabled: !drag.pressed; NumberAnimation { duration: Theme.durationFast } }
            }
            MouseArea {
                id: drag; anchors.fill: parent
                function setFrom(mx) { root.value = Math.max(0, Math.min(1, mx / width)) }
                onPressed: (m) => { root.forceActiveFocus(); setFrom(m.x) }
                onPositionChanged: (m) => setFrom(m.x)
            }
        }
        Text { text: Math.round(root.value * 100) + "%"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; Layout.preferredWidth: 36 }
        PrototypeBadge { visible: root.prototype }
    }
}
