import QtQuick
import QtQuick.Layouts
import OmniDesign

// Avviso temporaneo a comparsa (notifica appena ricevuta o messaggio del prototipo).
OmniSurface {
    id: root
    property string title: ""
    property string body: ""
    width: 360; height: col.implicitHeight + Theme.s4 * 2
    opacity: 0
    visible: opacity > 0
    function show(t, b) { title = t; body = b; anim.restart() }
    SequentialAnimation {
        id: anim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.durationNormal }
        PauseAnimation { duration: 3200 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: Theme.durationNormal }
    }
    ColumnLayout {
        id: col; anchors.fill: parent; anchors.margins: Theme.s4; spacing: 4
        Text { text: root.title; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { text: root.body; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
}
