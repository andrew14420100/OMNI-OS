import QtQuick
import OmniDesign

// Pagina di un'app OMNI: titolo, descrizione e contenuto scorrevole.
Item {
    id: page
    property string title: ""
    property string subtitle: ""
    default property alias content: col.data
    property alias spacing: col.spacing
    Flickable {
        id: fl
        anchors.fill: parent
        contentHeight: col.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            x: 32; y: 24
            width: fl.width - 64
            spacing: 10
            Text { text: page.title; color: Theme.textPrimary; font.pixelSize: 26; font.weight: Font.DemiBold; font.family: Theme.fontFamily; bottomPadding: page.subtitle ? 0 : 8 }
            Text { visible: page.subtitle !== ""; width: parent.width; text: page.subtitle; color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily; wrapMode: Text.WordWrap; bottomPadding: 8 }
        }
    }
}
