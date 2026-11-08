import QtQuick
import OmniDesign
import OmniShell

// Punto di ingresso caricato da omni-shell-prototipo (src/main.cpp).
Shell {
    id: root
    width: 1600; height: 1000
    apps: appModel
    scene: initialScene
    Component.onCompleted: { Theme.dark = initialDark; Theme.reducedMotion = initialReducedMotion }
}
