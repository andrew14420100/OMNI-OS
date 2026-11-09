import QtQuick
import OmniDesign

// Marchio OMNI: anello con gradiente aurora (pulsante Start).
Rectangle {
    property real size: 22
    width: size; height: size; radius: size / 2
    gradient: Gradient { orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.glow } GradientStop { position: 1; color: Theme.glowPair } }
    Rectangle { anchors.centerIn: parent; width: parent.size * 0.44; height: width; radius: width / 2
        color: Theme.dark ? "#0E1322" : "#F6F7FB" }
}
