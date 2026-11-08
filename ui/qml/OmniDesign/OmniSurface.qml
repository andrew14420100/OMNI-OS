import QtQuick

// Superficie "vetro" OMNI: base per pannelli, schede e finestre di sistema.
Rectangle {
    property bool raised: false
    color: raised ? Theme.surfaceRaised : Theme.surfaceGlass
    radius: Theme.radius
    border.color: Theme.outline
    border.width: 1
    Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
}
