import QtQuick
import OmniDesign

// Menu contestuale della barra e di Start (voci: etichetta, icona, azione).
Rectangle {
    id: menu
    property var session: null
    width: 260
    height: col.implicitHeight + 12
    radius: 10
    color: Theme.dark ? "#1B2238" : "#FFFFFF"
    border.color: Theme.outlineStrong
    MouseArea { anchors.fill: parent; onClicked: {} }
    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
        Repeater {
            model: menu.session ? menu.session.menuItems : []
            delegate: Item {
                id: it
                required property var modelData
                required property int index
                width: col.width; height: 36
                objectName: "menu:" + index
                Accessible.role: Accessible.MenuItem
                Accessible.name: modelData.label
                Rectangle { anchors.fill: parent; radius: 6; color: ma.containsMouse ? Theme.hover : "transparent" }
                Row {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    OmniIcon { width: 16; height: 16; name: it.modelData.icon || "chevron-right"; color: Theme.textSecondary }
                    Text { text: it.modelData.label; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily; elide: Text.ElideRight; width: col.width - 50 }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { const f = it.modelData.act; menu.session.close(); if (f) f() } }
            }
        }
    }
}
