import QtQuick
import OmniDesign

// Barra laterale di OMNI Explorer: cartelle personali, cestino, unità. Accetta il rilascio
// di file (spostamento; con Ctrl copia).
Rectangle {
    id: side
    property string currentPath: ""
    property bool trashMode: false
    property var places: []
    property var volumes: []
    signal openPath(string path)
    signal openTrash()
    signal dropped(var urls, string path, bool copy)
    color: Theme.dark ? "#0C1120" : "#EBEEF6"

    component Place: Rectangle {
        id: pl
        property string label; property string glyph; property string path; property bool active; property string detail
        signal activated()
        width: col.width; height: detail ? 46 : 34; radius: 8
        color: active ? Theme.accentSoft : (ma.containsMouse || dz.containsDrag ? Theme.hover : "transparent")
        border.color: dz.containsDrag ? Theme.accent : "transparent"
        Rectangle { visible: pl.active; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 16; radius: 2; color: Theme.accent }
        OmniIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; name: pl.glyph; color: pl.active ? Theme.accent : Theme.textSecondary }
        Column {
            x: 40; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48
            Text { width: parent.width; text: pl.label; elide: Text.ElideRight; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
            Text { visible: !!pl.detail; width: parent.width; text: pl.detail; elide: Text.ElideRight; color: Theme.textTertiary; font.pixelSize: 11; font.family: Theme.fontFamily }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: pl.activated() }
        DropArea { id: dz; anchors.fill: parent; enabled: !!pl.path
            onDropped: (drop) => { if (drop.hasUrls) { side.dropped(drop.urls, pl.path, (drop.modifiers & Qt.ControlModifier) !== 0); drop.accept(Qt.CopyAction) } } }
    }

    Flickable {
        anchors.fill: parent; anchors.margins: 10
        contentHeight: col.height; clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: parent.width; spacing: 2
            Repeater {
                model: side.places
                delegate: Place { required property var modelData; objectName: "luogo:" + modelData.id
                    label: modelData.label; glyph: modelData.glyph; path: modelData.path
                    active: !side.trashMode && side.currentPath === modelData.path; onActivated: side.openPath(modelData.path) }
            }
            Place { objectName: "luogo:cestino"; label: qsTr("Cestino"); glyph: "trash"; active: side.trashMode; onActivated: side.openTrash() }
            Item { width: 1; height: 12 }
            Text { leftPadding: 12; text: qsTr("Unità"); color: Theme.textTertiary; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
            Repeater {
                model: side.volumes
                delegate: Place { required property var modelData
                    label: modelData.name; glyph: "drive"; path: modelData.path; active: !side.trashMode && side.currentPath === modelData.path
                    detail: qsTr("%1 liberi di %2").arg(humanBytes(modelData.free)).arg(humanBytes(modelData.total)) + (modelData.readOnly ? qsTr(" · sola lettura") : "")
                    onActivated: side.openPath(modelData.path) }
            }
        }
    }
    function humanBytes(b) { const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0; while (b >= 1024 && i < 4) { b /= 1024; ++i } return (i ? b.toFixed(b < 10 ? 1 : 0) : b) + " " + u[i] }
}
