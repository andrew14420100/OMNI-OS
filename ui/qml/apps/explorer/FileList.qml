import QtQuick
import OmniDesign
import "../../OmniApps/sys.js" as Sys

// Elenco dei file: vista Dettagli (colonne ordinabili) o Icone. Selezione multipla
// (Ctrl, Maiusc), doppio clic per aprire, menu contestuale, trascinamento verso cartelle,
// barra laterale e altre app (text/uri-list), rilascio da altre app.
Item {
    id: fl
    property var folder: null              // FolderModel
    property var trashItems: null          // elenco del cestino (modalità Cestino)
    property bool grid: false
    property var selection: []
    property string currentPath: ""
    readonly property bool trash: trashItems !== null
    readonly property int rows: trash ? trashItems.length : (folder ? folder.count : 0)
    signal select(int row, string path, int modifiers)
    signal activate(int row)
    signal contextMenu(int row, real x, real y)
    signal dropOn(var urls, string path, bool copy)
    signal clearSelection()
    // revisione: cambia a ogni ricarica/ordinamento del modello, così le righe si aggiornano
    // anche quando il numero di elementi resta uguale
    property int revision: 0
    Connections { target: fl.folder; function onCountChanged() { fl.revision++ } }
    function row(i) { return trash ? trashItems[i] : folder.get(i) }
    function isSel(p) { return selection.indexOf(p) >= 0 }
    function urlsFor(p) { const list = isSel(p) ? selection : [p]; return list.map(x => "file://" + encodeURI(x)).join("\r\n") }

    component Header: Item {
        id: hd
        property string label; property string key; property real w
        width: w; height: 30
        Text { anchors.verticalCenter: parent.verticalCenter; leftPadding: 8; text: hd.label + (!fl.trash && fl.folder && fl.folder.sortKey === hd.key ? (fl.folder.descending ? "  ▴" : "  ▾") : "")
            color: Theme.textSecondary; font.pixelSize: 12; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
        MouseArea { anchors.fill: parent; enabled: !fl.trash; onClicked: { if (fl.folder.sortKey === hd.key) fl.folder.descending = !fl.folder.descending; else { fl.folder.sortKey = hd.key; fl.folder.descending = false } } }
    }
    Row {
        id: header
        visible: !fl.grid
        x: 12; width: parent.width - 24; height: 30
        Header { label: qsTr("Nome"); key: "name"; w: header.width * 0.44 }
        Header { label: fl.trash ? qsTr("Posizione originale") : qsTr("Ultima modifica"); key: "date"; w: header.width * (fl.trash ? 0.30 : 0.20) }
        Header { label: fl.trash ? qsTr("Eliminato il") : qsTr("Tipo"); key: "type"; w: header.width * (fl.trash ? 0.14 : 0.22) }
        Header { label: qsTr("Dimensione"); key: "size"; w: header.width * (fl.trash ? 0.12 : 0.14) }
    }
    Rectangle { visible: !fl.grid; anchors.top: header.bottom; x: 12; width: parent.width - 24; height: 1; color: Theme.outline }

    // clic sullo spazio vuoto: deseleziona; rilascio da altre app nella cartella corrente
    MouseArea {
        anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; z: -1
        onClicked: (m) => { fl.clearSelection(); if (m.button === Qt.RightButton) fl.contextMenu(-1, m.x, m.y) }
    }
    DropArea {
        anchors.fill: parent; enabled: !fl.trash
        onDropped: (drop) => { if (drop.hasUrls) { fl.dropOn(drop.urls, fl.currentPath, (drop.modifiers & Qt.ControlModifier) !== 0); drop.accept(Qt.CopyAction) } }
    }

    component Entry: Rectangle {
        id: en
        required property int index
        readonly property var d: (fl.revision, fl.row(index)) || ({})
        readonly property bool sel: fl.isSel(d.path)
        property bool asGrid: false
        radius: 6
        color: sel ? Theme.accentSoft : (ma.containsMouse || dz.containsDrag ? Theme.hover : "transparent")
        border.color: dz.containsDrag ? Theme.accent : (sel ? Theme.alpha(Theme.accent, 0.5) : "transparent")
        opacity: d.hidden ? 0.6 : 1
        Item {
            id: dragProxy
            Drag.active: ma.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.MoveAction | Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": fl.urlsFor(en.d.path) })
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: fl.trash ? null : dragProxy
            onPressed: (m) => { if (!en.sel || m.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) fl.select(en.index, en.d.path, m.modifiers) }
            onClicked: (m) => { if (m.button === Qt.RightButton) { const p = mapToItem(fl, m.x, m.y); fl.contextMenu(en.index, p.x, p.y) }
                                else if (en.sel && !(m.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) fl.select(en.index, en.d.path, 0) }
            onDoubleClicked: fl.activate(en.index)
        }
        DropArea { id: dz; anchors.fill: parent; enabled: !fl.trash && !!en.d.isDir && !en.sel
            onDropped: (drop) => { if (drop.hasUrls) { fl.dropOn(drop.urls, en.d.path, (drop.modifiers & Qt.ControlModifier) !== 0); drop.accept(Qt.CopyAction) } } }
    }

    ListView {
        id: list
        objectName: "esplora:elenco"
        visible: !fl.grid
        anchors { top: header.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
        clip: true; boundsBehavior: Flickable.StopAtBounds; reuseItems: true
        model: fl.rows
        delegate: Entry {
            width: list.width; height: 32
            Image { id: ic; x: 8; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; sourceSize: Qt.size(40, 40); asynchronous: true; source: "image://omniicon/strict/" + (d.iconName || "unknown") }
            OmniIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; visible: ic.status !== Image.Ready; name: d.isDir ? "folder" : "file"; color: d.isDir ? Theme.accent : Theme.textSecondary }
            Text { x: 36; width: list.width * 0.44 - 40; anchors.verticalCenter: parent.verticalCenter; text: d.name || ""; elide: Text.ElideMiddle; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
            Text { x: list.width * 0.44 + 8; width: list.width * (fl.trash ? 0.30 : 0.20) - 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideMiddle; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily
                text: fl.trash ? (d.originalPath || "") : (d.modified ? Qt.formatDateTime(d.modified, "dd/MM/yyyy HH:mm") : "") }
            Text { x: list.width * (fl.trash ? 0.74 : 0.64) + 8; width: list.width * (fl.trash ? 0.14 : 0.22) - 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily
                text: fl.trash ? (d.deleted ? Qt.formatDateTime(d.deleted, "dd/MM/yyyy HH:mm") : "") : (d.typeName || "") }
            Text { x: list.width * 0.86 + 8; width: list.width * 0.14 - 16; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily
                text: d.isDir ? "" : Sys.humanBytes(d.size) }
        }
    }
    GridView {
        id: gridView
        objectName: "esplora:griglia"
        visible: fl.grid
        anchors.fill: parent; anchors.margins: 12
        clip: true; boundsBehavior: Flickable.StopAtBounds; reuseItems: true
        cellWidth: 116; cellHeight: 124
        model: fl.rows
        delegate: Entry {
            width: 108; height: 116
            OmniIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 14; width: 48; height: 48; visible: gi.status !== Image.Ready; name: d.isDir ? "folder" : "file"; color: d.isDir ? Theme.accent : Theme.textSecondary; strokeWidth: 1.4 }
            Image { id: gi; anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 56; height: 56; sourceSize: Qt.size(112, 112); asynchronous: true
                source: (!d.isDir && /^image\/(png|jpeg|webp|gif)$/.test(d.mime || "")) ? "file://" + d.path : "image://omniicon/strict/" + (d.iconName || "unknown") ; fillMode: Image.PreserveAspectFit }
            Text { x: 6; y: 72; width: parent.width - 12; height: 36; text: d.name || ""; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight
                color: Theme.textPrimary; font.pixelSize: 12; font.family: Theme.fontFamily }
        }
    }
    Text { anchors.centerIn: parent; visible: fl.rows === 0; color: Theme.textTertiary; font.pixelSize: 14; font.family: Theme.fontFamily
        text: fl.trash ? qsTr("Il cestino è vuoto") : (fl.folder && fl.folder.error ? fl.folder.error : (fl.folder && fl.folder.searching ? qsTr("Ricerca in corso…") : qsTr("Questa cartella è vuota"))) }
    function positionAt(row) { if (grid) gridView.positionViewAtIndex(row, GridView.Contain); else list.positionViewAtIndex(row, ListView.Contain) }
}
