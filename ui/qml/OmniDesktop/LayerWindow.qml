import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

// Superficie della shell (protocollo wlr-layer-shell di KWin): sfondo, barra e pannelli sono
// parti del desktop, non finestre normali (niente voce nel task switcher, niente bordo,
// spazio riservato alla barra rispettato dalle finestre massimizzate).
Window {
    id: w
    property string scopeName: "omni"
    property int shellLayer: LayerShell.Window.LayerTop
    property int edges: 0
    property int zone: 0
    property int keyboard: LayerShell.Window.KeyboardInteractivityNone
    readonly property int edgeTop: LayerShell.Window.AnchorTop
    readonly property int edgeBottom: LayerShell.Window.AnchorBottom
    readonly property int edgeLeft: LayerShell.Window.AnchorLeft
    readonly property int edgeRight: LayerShell.Window.AnchorRight
    readonly property int layerBackground: LayerShell.Window.LayerBackground
    readonly property int layerTop: LayerShell.Window.LayerTop
    readonly property int layerOverlay: LayerShell.Window.LayerOverlay
    readonly property int keyboardNone: LayerShell.Window.KeyboardInteractivityNone
    readonly property int keyboardExclusive: LayerShell.Window.KeyboardInteractivityExclusive
    readonly property int keyboardOnDemand: LayerShell.Window.KeyboardInteractivityOnDemand
    color: "transparent"
    LayerShell.Window.scope: scopeName
    LayerShell.Window.layer: shellLayer
    LayerShell.Window.anchors: edges
    LayerShell.Window.exclusionZone: zone
    LayerShell.Window.keyboardInteractivity: keyboard
}
