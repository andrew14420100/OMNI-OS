import QtQuick
import OmniDesign

// Galleria del sistema di icone OMNI (scena "gallery"): mostra ogni glifo a tre dimensioni.
Rectangle {
    color: Theme.background
    Flow {
        anchors.fill: parent; anchors.margins: Theme.s6; spacing: Theme.s5
        Repeater {
            model: AppGlyphs.keys
            Column {
                required property string modelData
                spacing: Theme.s2
                width: 120
                Row {
                    spacing: Theme.s2; anchors.horizontalCenter: parent.horizontalCenter
                    OmniAppIcon { glyph: modelData; size: 64; anchors.bottom: parent.bottom }
                    OmniAppIcon { glyph: modelData; size: 32; anchors.bottom: parent.bottom; shadow: false }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
            }
        }
    }
}
