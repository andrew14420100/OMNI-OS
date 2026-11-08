import QtQuick

// Selettore a segmenti con indicatore scorrevole (es. tema chiaro/scuro).
Rectangle {
    id: root
    property var options: []        // [{ text, icon }]
    property int currentIndex: 0
    signal activated(int index)
    implicitWidth: 260; implicitHeight: 40
    radius: Theme.radiusSmall + 2
    color: Theme.surfaceSunken
    border.color: Theme.outline
    activeFocusOnTab: true
    Accessible.role: Accessible.PageTabList
    Keys.onLeftPressed: if (currentIndex > 0) activated(currentIndex - 1)
    Keys.onRightPressed: if (currentIndex < options.length - 1) activated(currentIndex + 1)
    readonly property real segW: (width - 8) / Math.max(1, options.length)
    Rectangle {
        x: 4 + root.currentIndex * root.segW; y: 4
        width: root.segW; height: root.height - 8; radius: Theme.radiusSmall
        color: Theme.surface
        border.color: root.activeFocus ? Theme.accent : Theme.outline; border.width: root.activeFocus ? 2 : 1
        Behavior on x { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
    }
    Row {
        x: 4; y: 4
        Repeater {
            model: root.options
            Item {
                required property var modelData
                required property int index
                width: root.segW; height: root.height - 8
                Row {
                    anchors.centerIn: parent; spacing: 6
                    OmniIcon { visible: !!modelData.icon; width: 16; height: 16; name: modelData.icon || "sparkle"; color: index === root.currentIndex ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: modelData.text; color: index === root.currentIndex ? Theme.textPrimary : Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; onClicked: { root.forceActiveFocus(); root.activated(index) } }
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.text
            }
        }
    }
}
