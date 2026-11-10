import QtQuick
import OmniDesign
import "../../OmniApps/sys.js" as Sys

// Riquadro di anteprima: immagini (ridotte, caricate in modo asincrono), testo (primi 8 KB),
// altrimenti icona e dettagli. Solo lettura.
Rectangle {
    id: pane
    property var item: null          // voce selezionata (get(row) del modello)
    property var ops: null
    readonly property bool isImage: !!item && !item.isDir && /^image\/(png|jpeg|gif|webp|bmp|svg\+xml)$/.test(item.mime)
    readonly property bool isText: !!item && !item.isDir && (/^text\//.test(item.mime) || /json|xml|x-shellscript|javascript|x-desktop/.test(item.mime))
    color: Theme.dark ? "#121829" : "#FFFFFF"
    Column {
        anchors.fill: parent; anchors.margins: 16; spacing: 12
        visible: !!pane.item
        Item {
            width: parent.width; height: Math.min(width, 260)
            Image { anchors.fill: parent; visible: pane.isImage; asynchronous: true; fillMode: Image.PreserveAspectFit
                source: pane.isImage ? "file://" + pane.item.path : ""; sourceSize.width: 520; sourceSize.height: 520 }
            Image { id: bigIcon; anchors.centerIn: parent; visible: !pane.isImage; width: 96; height: 96; sourceSize: Qt.size(96, 96)
                source: pane.item ? "image://omniicon/strict/" + pane.item.iconName : "" }
            OmniIcon { anchors.centerIn: parent; visible: !pane.isImage && bigIcon.status !== Image.Ready; width: 80; height: 80; strokeWidth: 1.2
                name: pane.item && pane.item.isDir ? "folder" : "file"; color: Theme.textSecondary }
        }
        Text { width: parent.width; text: pane.item ? pane.item.name : ""; wrapMode: Text.WrapAnywhere; color: Theme.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
        Text { width: parent.width; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily; wrapMode: Text.Wrap
            text: pane.item ? pane.item.typeName + (pane.item.isDir ? "" : " · " + Sys.humanBytes(pane.item.size)) + "\n" + (pane.item.modified ? qsTr("Modificato: %1").arg(Qt.formatDateTime(pane.item.modified, "dd/MM/yyyy HH:mm")) : "") : "" }
        Rectangle {
            visible: pane.isText; width: parent.width; height: Math.max(80, pane.height - y - 16); radius: 6; color: Theme.surfaceSunken; clip: true
            Text { anchors.fill: parent; anchors.margins: 8; text: pane.isText && pane.ops ? pane.ops.readText(pane.item.path, 8192) : ""
                color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace"; wrapMode: Text.WrapAnywhere; elide: Text.ElideRight }
        }
    }
    Text { anchors.centerIn: parent; visible: !pane.item; text: qsTr("Seleziona un file per l'anteprima"); color: Theme.textTertiary; font.pixelSize: 13; font.family: Theme.fontFamily }
}
