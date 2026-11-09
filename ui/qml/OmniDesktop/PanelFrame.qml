import QtQuick
import OmniDesign

// Contenitore dei pannelli a comparsa (Start, impostazioni rapide, notifiche): superficie
// opaca con bordo sottile e ombra a rettangoli (nessun effetto di sfocatura: costa troppo
// con il rendering software). Animazione breve di comparsa, assente con movimento ridotto.
Item {
    id: frame
    property bool shown: false
    default property alias content: inner.data
    property real radius: 12
    visible: opacity > 0
    opacity: shown ? 1 : 0
    transform: Translate { y: frame.shown || Theme.reducedMotion ? 0 : 14; Behavior on y { enabled: !Theme.reducedMotion; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
    Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: 120 } }
    OmniShadow { anchors.fill: parent; radius: frame.radius; offsetY: 8; spread: 14; strength: 0.7; steps: 3 }
    Rectangle {
        anchors.fill: parent
        radius: frame.radius
        color: Theme.dark ? "#141A2C" : "#FAFBFE"
        border.color: Theme.outlineStrong
        border.width: 1
    }
    Item { id: inner; anchors.fill: parent; anchors.margins: 1 }
    // i clic dentro il pannello non lo chiudono
    MouseArea { anchors.fill: parent; z: -1; onClicked: {} }
}
