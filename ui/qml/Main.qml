import QtQuick
import OmniDesign
import OmniShell

// Punto di ingresso caricato da omni-shell-prototipo (src/main.cpp).
Item {
    id: root
    width: 1600; height: 1000
    Component.onCompleted: { Theme.dark = initialDark; Theme.reducedMotion = initialReducedMotion; Theme.accentIndex = initialAccent }
    Loader {
        anchors.fill: parent
        focus: true
        sourceComponent: initialScene === "gallery" ? gallery : shell
    }
    Component { id: gallery; Gallery {} }
    Component { id: shell; Shell { apps: appModel; userName: currentUser; scene: initialScene; focus: true } }
}
