import QtQuick
import QtQuick.Layouts

// Campo di ricerca OMNI.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: qsTr("Cerca")
    signal accepted()
    implicitWidth: 520; implicitHeight: 52
    radius: Theme.radius
    color: Theme.surfaceRaised
    border.color: input.activeFocus ? Theme.accent : Theme.outline
    border.width: input.activeFocus ? 2 : 1
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    function focusInput() { input.forceActiveFocus() }

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: Theme.s4; anchors.rightMargin: Theme.s4; spacing: Theme.s3
        OmniIcon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; name: "search"; color: Theme.textSecondary }
        TextInput {
            id: input; Layout.fillWidth: true
            color: Theme.textPrimary; selectionColor: Theme.accentSoft
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle
            onAccepted: root.accepted()
            Accessible.role: Accessible.EditableText
            Accessible.name: root.placeholder
            Text { anchors.fill: parent; text: root.placeholder; visible: !input.text && !input.activeFocus; color: Theme.textSecondary; font: input.font }
        }
    }
}
