import QtQuick
import OmniDesign

// Dock OMNI (decisione 6: dock dinamico). Ingrandimento progressivo vicino al puntatore,
// etichette, indicatori delle app aperte nell'anteprima, rimbalzo all'attivazione,
// dimensione adattiva alla larghezza dello schermo e navigazione da tastiera.
// Le app NON vengono avviate: il prototipo mostra solo l'animazione di apertura.
Item {
    id: root
    property var items: []            // voci (AppCatalog.entry) da mostrare
    property var session: null
    property bool launcherOpen: false
    property real availableWidth: 1600
    signal launcherRequested()
    signal activated(var entry, real gx, real gy)

    readonly property int count: items.length + 1
    readonly property real baseSize: Math.max(36, Math.min(52, (availableWidth - 320) / (count + 3)))
    readonly property real maxScale: Theme.reducedMotion ? 1.0 : 1.55
    property real pointerX: -10000
    property bool hovering: false
    readonly property real padding: 10

    width: row.width + padding * 2
    height: baseSize + padding * 2 + 8

    // Posizioni "a riposo" (senza ingrandimento): evitano dipendenze circolari tra
    // larghezza delle icone e loro posizione. slot 0 = launcher, poi separatore e app.
    readonly property real spacing: 6
    readonly property real restWidth: count * baseSize + (count - 1) * spacing + 1 + spacing
    function restCenter(slot) { return slot * (baseSize + spacing) + baseSize / 2 + (slot > 0 ? 1 + spacing : 0) }
    // pointerX è espresso nelle coordinate a riposo (0 = inizio della fila)
    function magnify(cx) {
        if (!hovering || Theme.reducedMotion) return 1
        const d = (cx - pointerX) / (baseSize * 1.25)
        return 1 + (maxScale - 1) * Math.exp(-d * d)
    }

    OmniSurface {
        id: plate
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: row.width + root.padding * 2
        height: root.baseSize + root.padding * 2
        radius: Theme.radiusLarge + 2
        strong: true
    }

    // HoverHandler passivo: riceve la posizione del puntatore anche sopra le icone
    HoverHandler {
        id: tracker
        onPointChanged: { root.pointerX = point.position.x - root.width / 2 + root.restWidth / 2 }
        onHoveredChanged: root.hovering = hovered
    }

    Row {
        id: row
        x: root.padding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding
        spacing: root.spacing

        // pulsante del launcher
        DockItem {
            id: launcherItem
            objectName: "dock:launcher"
            size: root.baseSize
            scaleFactor: root.magnify(root.restCenter(0))
            label: qsTr("Applicazioni")
            active: root.launcherOpen
            launcher: true
            tracking: root.hovering
            onTriggered: root.launcherRequested()
        }
        Rectangle { width: 1; height: root.baseSize * 0.6; anchors.bottom: parent.bottom; anchors.bottomMargin: root.baseSize * 0.2; color: Theme.outlineStrong }

        Repeater {
            model: root.items
            DockItem {
                required property var modelData
                required property int index
                objectName: "dock:" + modelData.glyph
                size: root.baseSize
                scaleFactor: root.magnify(root.restCenter(index + 1))
                label: modelData.name
                entry: modelData
                open: root.session ? (root.session.opened, root.session.isOpen(modelData.desktopId)) : false
                tracking: root.hovering
                onTriggered: { const p = mapToItem(null, width / 2, height / 2); root.activated(modelData, p.x, p.y) }
            }
        }
    }

    component DockItem: Item {
        id: di
        property real size: 48
        property real scaleFactor: 1
        property string label: ""
        property var entry: null
        property bool open: false
        property bool active: false
        property bool launcher: false
        property bool tracking: false
        signal triggered()
        width: size * scaleFactor
        height: size * scaleFactor
        anchors.bottom: parent ? parent.bottom : undefined
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: activate()
        Keys.onSpacePressed: activate()
        Behavior on width { enabled: !di.tracking; NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
        Behavior on height { enabled: !di.tracking; NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }

        function activate() { bounce.restart(); triggered() }

        Item {
            id: body
            width: parent.width; height: parent.height
            transform: Translate { id: lift; y: 0 }
            // icona applicativa o pulsante launcher
            OmniAppIcon {
                visible: !di.launcher
                size: parent.width
                appName: di.entry ? di.entry.name : ""
                glyph: di.entry ? di.entry.glyph : "generic"
            }
            Rectangle {
                visible: di.launcher
                anchors.fill: parent; radius: width * 0.32
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.alpha(Theme.glow, Theme.dark ? 0.95 : 0.9) }
                    GradientStop { position: 1; color: Theme.alpha(Theme.glowPair, Theme.dark ? 0.95 : 0.9) }
                }
                border.color: Qt.rgba(1, 1, 1, 0.3)
                OmniIcon { anchors.centerIn: parent; width: parent.width * 0.46; height: width; name: "apps"; color: "#FFFFFF"; strokeWidth: 2.2 }
            }
        }
        // anello di messa a fuoco da tastiera
        Rectangle {
            anchors.fill: parent; anchors.margins: -4; radius: width * 0.34
            color: "transparent"; border.color: Theme.accent; border.width: 2
            visible: di.activeFocus
        }
        // indicatore "aperta" / "attiva"
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom; anchors.topMargin: 3
            width: di.active ? 14 : 5; height: 5; radius: 2.5
            color: di.active ? Theme.accent : Theme.textPrimary
            opacity: (di.open || di.active) ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
            Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingEmphasized } }
        }
        OmniTooltip {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top; anchors.bottomMargin: 10
            text: di.label
            shown: mouse.containsMouse || di.activeFocus
        }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: di.activate() }
        SequentialAnimation {
            id: bounce
            NumberAnimation { target: lift; property: "y"; to: -di.size * 0.35; duration: Theme.durationNormal; easing.type: Easing.OutQuad }
            NumberAnimation { target: lift; property: "y"; to: 0; duration: Theme.durationSlow; easing.type: Easing.OutBounce }
        }
    }
}
