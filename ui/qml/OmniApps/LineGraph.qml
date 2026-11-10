import QtQuick
import QtQuick.Shapes
import OmniDesign
// Grafico a linea leggero (Shape, nessun Canvas da ridisegnare): ultimi N valori.
Item {
    id: g
    property var values: []
    property real maxValue: 100
    property int capacity: 60
    property color color: Theme.accent
    readonly property real peak: Math.max(maxValue, Math.max.apply(null, values.length ? values : [0]))
    Rectangle { anchors.fill: parent; radius: 6; color: Theme.dark ? "#0F1528" : "#F4F6FB"; border.color: Theme.outline }
    Shape {
        anchors.fill: parent
        anchors.margins: 1
        asynchronous: true
        ShapePath {
            strokeColor: g.color; strokeWidth: 1.5; fillColor: Theme.alpha(g.color, 0.15)
            PathPolyline {
                path: {
                    const pts = [], n = g.values.length, w = g.width - 2, h = g.height - 2
                    if (n === 0) return [Qt.point(0, h), Qt.point(w, h)]
                    pts.push(Qt.point(w - (n - 1) * w / (g.capacity - 1), h))
                    for (let i = 0; i < n; ++i) pts.push(Qt.point(w - (n - 1 - i) * w / (g.capacity - 1), h - h * Math.min(1, g.values[i] / g.peak)))
                    pts.push(Qt.point(w, h))
                    return pts
                }
            }
        }
    }
}
