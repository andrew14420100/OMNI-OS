import QtQuick

// Superficie "vetro" OMNI v2: fondo traslucido, riflesso superiore, bordo luminoso
// e ombra morbida opzionale. Base per pannelli, schede e finestre di sistema.
Item {
    id: root
    property bool raised: false
    property bool strong: false
    property bool elevated: true
    property real radius: Theme.radius
    property color color: raised ? Theme.surfaceRaised : (strong ? Theme.surfaceGlassStrong : Theme.surfaceGlass)
    property alias border: bg.border
    default property alias content: inner.data

    OmniShadow {
        visible: root.elevated && !root.raised
        anchors.fill: parent
        radius: root.radius
        offsetY: 14; spread: 22
    }
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.color: Theme.outline
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
    }
    // riflesso e bordo superiore luminoso (profondità)
    Rectangle {
        visible: !root.raised
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Theme.highlightEdge
        opacity: Theme.dark ? 0.55 : 0.9
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.dark ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.55) }
            GradientStop { position: 0.35; color: "transparent" }
        }
    }
    Item { id: inner; anchors.fill: parent }
}
