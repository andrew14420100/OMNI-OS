import QtQuick
import OmniDesign

// Icona di un'applicazione: glifo OMNI per le app note (identità visiva),
// altrimenti l'icona reale del tema di sistema (Breeze), nitida a ogni scala.
Item {
    id: root
    property string appName: ""
    property string desktopId: ""
    property string iconName: ""
    property var categories: []
    property real size: 32
    readonly property string glyph: AppGlyphs.resolve(appName, desktopId, iconName, categories)
    implicitWidth: size
    implicitHeight: size
    Accessible.ignored: true

    Loader {
        anchors.fill: parent
        sourceComponent: root.glyph !== "generic" || root.iconName === "" ? glyphIcon : themeIcon
    }
    Component { id: glyphIcon; OmniAppIcon { size: root.size; shadow: false; glyph: root.glyph; appName: root.appName } }
    Component {
        id: themeIcon
        Image {
            source: "image://omniicon/" + encodeURIComponent(root.iconName)
            sourceSize: Qt.size(Math.ceil(root.size * Screen.devicePixelRatio), Math.ceil(root.size * Screen.devicePixelRatio))
            asynchronous: true
            smooth: true
            fillMode: Image.PreserveAspectFit
        }
    }
}
