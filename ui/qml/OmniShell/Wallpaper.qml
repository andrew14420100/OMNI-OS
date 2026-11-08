import QtQuick
import QtQuick.Shapes
import OmniDesign

// Sfondo originale OMNI "Aurora Flux": gradiente profondo, nebulose luminose che si
// muovono lentamente, nastri d'aurora, campo di stelle e orizzonte a griglia.
// Le animazioni continue si fermano con "movimento ridotto" o "risparmio risorse".
Item {
    id: root
    clip: true
    property bool animate: Theme.ambientMotion
    property real phase: 0
    NumberAnimation on phase { from: 0; to: 1; duration: 60000; loops: Animation.Infinite; running: root.animate }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.dark ? "#060915" : "#EEF2FB" }
            GradientStop { position: 0.55; color: Theme.dark ? "#0B0C24" : "#EBE7FA" }
            GradientStop { position: 1.0; color: Theme.dark ? "#04101A" : "#E3F2F7" }
        }
    }

    // Nebulose: gradienti radiali in movimento lento (lissajous)
    Repeater {
        model: [
            { c: Theme.glow,          x: 0.80, y: 0.28, r: 0.50, ax: 0.05, ay: 0.04, a: 0.55 },
            { c: Theme.glowPair,      x: 0.22, y: 0.78, r: 0.58, ax: 0.06, ay: 0.03, a: 0.50 },
            { c: Theme.auroraMagenta, x: 0.52, y: 0.02, r: 0.38, ax: 0.04, ay: 0.05, a: 0.30 }
        ]
        Shape {
            id: blob
            required property var modelData
            required property int index
            readonly property real rr: Math.max(root.width, root.height) * modelData.r
            readonly property real cx: root.width * (modelData.x + modelData.ax * Math.sin(2 * Math.PI * (root.phase + index * 0.31)))
            readonly property real cy: root.height * (modelData.y + modelData.ay * Math.cos(2 * Math.PI * (root.phase * 2 + index * 0.17)))
            x: cx - rr; y: cy - rr; width: rr * 2; height: rr * 2
            opacity: Theme.dark ? modelData.a : modelData.a * 0.75
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: blob.rr; centerY: blob.rr; centerRadius: blob.rr
                    focalX: blob.rr; focalY: blob.rr
                    GradientStop { position: 0.0; color: blob.modelData.c }
                    GradientStop { position: 0.45; color: Theme.alpha(blob.modelData.c, 0.35) }
                    GradientStop { position: 1.0; color: Theme.alpha(blob.modelData.c, 0.0) }
                }
                PathAngleArc { centerX: blob.rr; centerY: blob.rr; radiusX: blob.rr; radiusY: blob.rr; startAngle: 0; sweepAngle: 360 }
            }
        }
    }

    // Nastri d'aurora: per ogni nastro un alone ampio e tenue e un nucleo sottile
    Repeater {
        model: [ { i: 0, k: 3.2, a: 0.22 }, { i: 0, k: 1.0, a: 0.55 }, { i: 1, k: 3.0, a: 0.16 },
                 { i: 1, k: 0.9, a: 0.42 }, { i: 2, k: 2.6, a: 0.12 }, { i: 2, k: 0.8, a: 0.32 } ]
        Shape {
            id: ribbon
            required property var modelData
            readonly property int index: modelData.i
            anchors.fill: parent
            asynchronous: true
            readonly property real w: root.width
            readonly property real h: root.height
            readonly property real wave: Math.sin(2 * Math.PI * (root.phase * 1.5 + index * 0.27)) * h * 0.035
            readonly property real thick: h * (0.022 - index * 0.004) * modelData.k
            readonly property real base: h * (0.60 + index * 0.075) - thick / 2
            opacity: Theme.dark ? modelData.a : modelData.a * 0.8
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: ribbon.w; y2: 0
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.glow, 0.0) }
                    GradientStop { position: 0.3; color: Theme.alpha(Theme.glow, 0.8) }
                    GradientStop { position: 0.7; color: Theme.alpha(Theme.glowPair, 0.8) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.glowPair, 0.0) }
                }
                startX: -ribbon.w * 0.05; startY: ribbon.base
                PathCubic { x: ribbon.w * 1.05; y: ribbon.base - ribbon.h * 0.32
                            control1X: ribbon.w * 0.35; control1Y: ribbon.base - ribbon.h * 0.22 + ribbon.wave
                            control2X: ribbon.w * 0.65; control2Y: ribbon.base + ribbon.h * 0.06 - ribbon.wave }
                PathLine { x: ribbon.w * 1.05; y: ribbon.base - ribbon.h * 0.32 + ribbon.thick }
                PathCubic { x: -ribbon.w * 0.05; y: ribbon.base + ribbon.thick
                            control1X: ribbon.w * 0.65; control1Y: ribbon.base + ribbon.h * 0.06 - ribbon.wave + ribbon.thick
                            control2X: ribbon.w * 0.35; control2Y: ribbon.base - ribbon.h * 0.22 + ribbon.wave + ribbon.thick }
            }
        }
    }

    // Campo di stelle e orizzonte a griglia (disegnati una volta sola)
    Canvas {
        id: field
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        property bool darkMode: Theme.dark
        onDarkModeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            let seed = 7
            function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646 }
            const n = Math.round(width * height / 9000)
            for (let i = 0; i < n; ++i) {
                const x = rnd() * width, y = rnd() * height * 0.62, r = rnd() * 1.1 + 0.2
                ctx.fillStyle = darkMode ? Qt.rgba(1, 1, 1, 0.15 + rnd() * 0.45) : Qt.rgba(0.2, 0.25, 0.5, 0.05 + rnd() * 0.12)
                ctx.beginPath(); ctx.arc(x, y, r, 0, 2 * Math.PI); ctx.fill()
            }
            // orizzonte prospettico
            const hy = height * 0.80, vx = width * 0.5
            ctx.lineWidth = 1
            for (let k = -14; k <= 14; ++k) {
                ctx.strokeStyle = darkMode ? Qt.rgba(0.55, 0.85, 1, 0.07) : Qt.rgba(0.2, 0.3, 0.6, 0.06)
                ctx.beginPath(); ctx.moveTo(vx + k * 18, hy); ctx.lineTo(vx + k * width * 0.16, height); ctx.stroke()
            }
            for (let j = 0; j < 9; ++j) {
                const t = Math.pow(j / 8, 1.8), y = hy + (height - hy) * t
                ctx.strokeStyle = darkMode ? Qt.rgba(0.55, 0.85, 1, 0.05 + t * 0.05) : Qt.rgba(0.2, 0.3, 0.6, 0.04 + t * 0.04)
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }

    // vignettatura per profondità
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.dark ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.25; color: "transparent" }
            GradientStop { position: 0.85; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0.85, 0.88, 0.96, 0.4) }
        }
    }
}
