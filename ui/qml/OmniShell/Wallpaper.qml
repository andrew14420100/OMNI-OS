import QtQuick
import QtQuick.Shapes
import OmniDesign

// Sfondo originale OMNI: gradiente "aurora" e anelli orbitali vettoriali.
Item {
    id: root
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.dark ? "#0A1022" : "#E7ECF8" }
            GradientStop { position: 0.55; color: Theme.dark ? "#120E2E" : "#EDE7FA" }
            GradientStop { position: 1.0; color: Theme.dark ? "#06131C" : "#E2F4F8" }
        }
        Behavior on color { ColorAnimation { duration: Theme.durationSlow } }
    }
    Repeater {
        model: 3
        Shape {
            anchors.fill: parent
            opacity: Theme.dark ? 0.55 - index * 0.12 : 0.40 - index * 0.09
            ShapePath {
                strokeWidth: 2 - index * 0.4
                fillColor: "transparent"
                strokeColor: index === 0 ? Theme.auroraCyan : (index === 1 ? Theme.auroraViolet : Theme.auroraMagenta)
                PathAngleArc {
                    centerX: root.width * (0.72 - index * 0.04); centerY: root.height * (0.38 + index * 0.06)
                    radiusX: root.width * (0.28 + index * 0.09); radiusY: root.height * (0.20 + index * 0.07)
                    startAngle: 200 + index * 25; sweepAngle: 230
                }
            }
        }
    }
    Text {
        anchors { left: parent.left; top: parent.top; margins: Theme.s6 }
        text: "OMNI"
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0.05, 0.08, 0.2, 0.06)
        font.family: Theme.fontFamily; font.pixelSize: 160; font.weight: Font.Black; font.letterSpacing: 18
    }
}
