import QtQuick
import QtQuick.Layouts
import OmniDesign

// Avviso temporaneo a comparsa sotto la barra superiore, con barra di avanzamento.
OmniSurface {
    id: root
    property string app: ""
    property string title: ""
    property string body: ""
    property bool prototypeNote: false
    width: 380; height: row.implicitHeight + Theme.s3 * 2 + 3
    radius: Theme.radius + 2
    strong: true
    opacity: 0
    visible: opacity > 0
    transform: Translate { id: tr; y: -16 }
    function show(a, t, b, isPrototype) { app = a; title = t; body = b; prototypeNote = !!isPrototype; anim.restart() }
    SequentialAnimation {
        id: anim
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.durationNormal }
            NumberAnimation { target: tr; property: "y"; from: -16; to: 0; duration: Theme.durationSlow; easing.type: Theme.easingEmphasized }
            NumberAnimation { target: progress; property: "width"; from: root.width - 2 * Theme.radius; to: root.width - 2 * Theme.radius; duration: 0 }
        }
        NumberAnimation { target: progress; property: "width"; to: 0; duration: 3600 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: Theme.durationNormal }
            NumberAnimation { target: tr; property: "y"; to: -10; duration: Theme.durationNormal }
        }
    }
    RowLayout {
        id: row; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.s3; spacing: Theme.s3
        OmniAppIcon { Layout.alignment: Qt.AlignTop; size: 36; shadow: false; appName: root.app; glyph: root.prototypeNote ? "ai" : AppGlyphs.resolve(root.app, "", "", []) }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { text: root.title; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { text: root.body; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            PrototypeBadge { visible: root.prototypeNote }
        }
    }
    Rectangle {
        id: progress
        anchors.bottom: parent.bottom; anchors.bottomMargin: 4; x: Theme.radius
        height: 2; radius: 1; color: Theme.accent; opacity: 0.7
    }
}
