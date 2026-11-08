import QtQuick
import QtQuick.Shapes

// Icona applicativa OMNI: squircle con gradiente, riflesso superiore, bordo luminoso
// e glifo vettoriale (AppGlyphs). Il glifo si sceglie con "glyph" oppure si ricava
// da nome, id .desktop, icona e categorie dell'applicazione.
Item {
    id: root
    property string appName: ""
    property string desktopId: ""
    property string iconName: ""
    property var categories: []
    property string glyph: AppGlyphs.resolve(appName, desktopId, iconName, categories)
    property real size: 56
    property bool shadow: true
    readonly property var spec: AppGlyphs.glyph(glyph)
    readonly property real k: size / 48

    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.Graphic
    Accessible.name: appName

    // Ombra morbida (rettangoli sovrapposti: nessun effetto grafico costoso).
    Repeater {
        model: root.shadow ? 3 : 0
        Rectangle {
            required property int index
            x: -index * root.k; width: root.size + 2 * index * root.k
            y: root.size * 0.10 + index * root.k; height: root.size
            radius: root.size * 0.32 + index * root.k
            color: Theme.shadow
            opacity: (Theme.dark ? 0.30 : 0.22) / (index + 1)
        }
    }

    Item {
        id: canvas
        width: 48; height: 48
        scale: root.k
        transformOrigin: Item.TopLeft
        // Rendering vettoriale con antialiasing multicampione, a risoluzione doppia.
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))

        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 48; y2: 48
                    GradientStop { position: 0; color: root.spec.c1 }
                    GradientStop { position: 1; color: root.spec.c2 }
                }
                PathSvg { path: AppGlyphs.squircle }
            }
            // riflesso superiore
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: 30
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.30) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.0) }
                }
                PathSvg { path: AppGlyphs.squircle }
            }
            // bordo luminoso sottile
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(1, 1, 1, 0.22)
                strokeWidth: 0.8
                PathSvg { path: "M24 0.6C40.4 0.6 47.4 7.6 47.4 24S40.4 47.4 24 47.4 0.6 40.4 0.6 24 7.6 0.6 24 0.6z" }
            }
        }

        Repeater {
            model: root.spec.layers
            Shape {
                id: layerShape
                required property var modelData
                anchors.fill: parent
                opacity: modelData.opacity !== undefined ? modelData.opacity : 1
                function col(c) { return c === "ink" ? root.spec.ink : (c || "transparent") }
                function pathOf(d) {
                    if (d.indexOf("circle:") === 0) {
                        const a = d.substring(7).split(",").map(Number)
                        return AppGlyphs.circle(a[0], a[1], a[2])
                    }
                    return d
                }
                ShapePath {
                    fillColor: layerShape.col(layerShape.modelData.fill)
                    strokeColor: layerShape.col(layerShape.modelData.stroke)
                    strokeWidth: layerShape.modelData.stroke ? layerShape.modelData.w : -1
                    strokeStyle: layerShape.modelData.dash ? ShapePath.DashLine : ShapePath.SolidLine
                    dashPattern: layerShape.modelData.dash ? layerShape.modelData.dash : [4, 2]
                    capStyle: layerShape.modelData.dash ? ShapePath.FlatCap : ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: layerShape.pathOf(layerShape.modelData.d) }
                }
            }
        }
    }
}
