import QtQuick
import QtQuick.Layouts
import OmniDesign

// Anteprima dell'ANIMAZIONE di apertura di un'applicazione: una finestra segnaposto si
// espande dall'icona e si richiude. L'applicazione NON viene avviata (prototipo): la
// finestra lo dichiara esplicitamente.
Item {
    id: root
    property var entry: null
    property real originX: width / 2
    property real originY: height
    readonly property bool active: win.opacity > 0
    signal finished()

    function play(e, gx, gy) {
        entry = e; originX = gx; originY = gy
        seq.stop(); seq.start()
    }
    function dismiss() { seq.stop(); closeAnim.start() }

    readonly property real targetW: Math.min(760, width - 120)
    readonly property real targetH: Math.min(470, height - 220)

    OmniSurface {
        id: win
        radius: Theme.radiusLarge
        strong: true
        opacity: 0
        visible: opacity > 0
        x: root.originX - width / 2; y: root.originY - height / 2
        width: 60; height: 60
        MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: Theme.s4; spacing: Theme.s3
            opacity: win.width > root.targetW * 0.8 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.s3
                OmniAppIcon { size: 40; shadow: false; appName: root.entry ? root.entry.name : ""; glyph: root.entry ? root.entry.glyph : "generic" }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: root.entry ? root.entry.name : ""; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontHeading; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: qsTr("Anteprima dell'animazione di apertura"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1 }
                }
                PrototypeBadge { text: qsTr("Prototipo · l'app non viene avviata") }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.surfaceSunken; border.color: Theme.outline
                ColumnLayout {
                    anchors.centerIn: parent; spacing: Theme.s2; width: parent.width * 0.7
                    Repeater { model: 4; Rectangle { required property int index; Layout.fillWidth: true; Layout.preferredWidth: parent.width * (1 - index * 0.18); height: 12; radius: 6; color: Theme.hover } }
                    Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: Theme.s3; text: qsTr("Il prototipo non agisce sulla sessione reale."); color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1 }
                }
            }
        }
    }

    SequentialAnimation {
        id: seq
        ScriptAction { script: { win.width = 60; win.height = 60; win.x = root.originX - 30; win.y = root.originY - 30 } }
        ParallelAnimation {
            NumberAnimation { target: win; property: "opacity"; to: 1; duration: Theme.durationFast }
            NumberAnimation { target: win; property: "width"; to: root.targetW; duration: Theme.durationEmphasis; easing.type: Easing.OutQuint }
            NumberAnimation { target: win; property: "height"; to: root.targetH; duration: Theme.durationEmphasis; easing.type: Easing.OutQuint }
            NumberAnimation { target: win; property: "x"; to: (root.width - root.targetW) / 2; duration: Theme.durationEmphasis; easing.type: Easing.OutQuint }
            NumberAnimation { target: win; property: "y"; to: (root.height - root.targetH) / 2 - 30; duration: Theme.durationEmphasis; easing.type: Easing.OutQuint }
        }
        PauseAnimation { duration: 1700 }
        ScriptAction { script: closeAnim.start() }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: win; property: "opacity"; to: 0; duration: Theme.durationSlow }
        NumberAnimation { target: win; property: "width"; to: 60; duration: Theme.durationSlow; easing.type: Easing.InCubic }
        NumberAnimation { target: win; property: "height"; to: 60; duration: Theme.durationSlow; easing.type: Easing.InCubic }
        NumberAnimation { target: win; property: "x"; to: root.originX - 30; duration: Theme.durationSlow; easing.type: Easing.InCubic }
        NumberAnimation { target: win; property: "y"; to: root.originY - 30; duration: Theme.durationSlow; easing.type: Easing.InCubic }
        onFinished: root.finished()
    }
}
