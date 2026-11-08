import QtQuick

// Ombra morbida per superfici arrotondate, costruita con pochi rettangoli
// semitrasparenti concentrici: nessun effetto grafico, costo minimo anche su GPU modeste.
Item {
    id: root
    property real radius: Theme.radius
    property real offsetY: 10
    property real spread: 18          // estensione dell'ombra
    property real strength: 1.0
    property int steps: 5
    Repeater {
        model: root.steps
        Rectangle {
            required property int index
            readonly property real t: (index + 1) / root.steps
            x: -root.spread * t; y: -root.spread * t + root.offsetY * t
            width: root.width + 2 * root.spread * t; height: root.height + 2 * root.spread * t
            radius: root.radius + root.spread * t
            color: Theme.shadow
            opacity: root.strength * (Theme.dark ? 0.34 : 0.20) * (1 - t * 0.85) / root.steps * 2.2
        }
    }
}
