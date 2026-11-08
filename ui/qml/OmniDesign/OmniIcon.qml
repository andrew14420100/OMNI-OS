import QtQuick
import QtQuick.Shapes

// Icona vettoriale OMNI (tratto), ridimensionabile e colorabile.
Item {
    id: root
    property string name: "sparkle"
    property color color: Theme.textPrimary
    property real strokeWidth: 1.8
    implicitWidth: 24
    implicitHeight: 24

    Shape {
        anchors.centerIn: parent
        width: 24; height: 24
        scale: Math.min(root.width, root.height) / 24
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.path(root.name) }
        }
    }
}
