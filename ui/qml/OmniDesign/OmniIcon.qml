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

    Item {
        width: 24; height: 24
        scale: Math.min(root.width, root.height) / 24
        anchors.centerIn: parent
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(24, Math.ceil(root.width * 2)), Math.max(24, Math.ceil(root.height * 2)))
        Shape {
            anchors.fill: parent
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
}
