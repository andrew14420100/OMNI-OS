import QtQuick
import QtQuick.Shapes

// Icona di interfaccia OMNI (tratto, opzionalmente riempita), ridimensionabile e colorabile.
Item {
    id: root
    property string name: "sparkle"
    property color color: Theme.textPrimary
    property real strokeWidth: 1.8
    property bool filled: false
    implicitWidth: 24
    implicitHeight: 24

    // Antialiasing analitico (Shape.CurveRenderer, Qt >= 6.6) e tassellazione in background:
    // nessun buffer multicampione per icona (prima: un FBO MSAA 4x per ogni icona, costoso in 4K).
    // Con Qt più vecchi (solo test locali) si torna al livello multicampione.
    Shape {
        id: shape
        readonly property bool curve: typeof Shape.CurveRenderer !== "undefined"
        width: 24; height: 24
        scale: Math.min(root.width, root.height) / 24
        anchors.centerIn: parent
        asynchronous: true
        layer.enabled: !curve
        layer.samples: 4
        layer.smooth: true
        Component.onCompleted: if (curve) preferredRendererType = Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: root.filled ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.path(root.name) }
        }
    }
}
