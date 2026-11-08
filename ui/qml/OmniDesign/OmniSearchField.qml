import QtQuick
import QtQuick.Layouts

// Campo di ricerca OMNI con anello di messa a fuoco luminoso.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: qsTr("Cerca")
    property string hint: ""
    property alias inputItem: input
    signal accepted()
    signal downPressed()
    implicitWidth: 520; implicitHeight: 56
    radius: Theme.radius + 2
    color: Theme.surfaceSunken
    border.color: input.activeFocus ? Theme.accent : Theme.outline
    border.width: input.activeFocus ? 2 : 1
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    function focusInput() { input.forceActiveFocus() }

    Rectangle {   // alone di messa a fuoco
        anchors.fill: parent; anchors.margins: -4; radius: parent.radius + 4
        color: "transparent"; border.width: 4; border.color: Theme.accentSoft
        visible: input.activeFocus
    }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: Theme.s4; anchors.rightMargin: Theme.s4; spacing: Theme.s3
        OmniIcon { Layout.preferredWidth: 22; Layout.preferredHeight: 22; name: "search"; color: input.activeFocus ? Theme.accent : Theme.textSecondary; strokeWidth: 2 }
        TextInput {
            id: input; Layout.fillWidth: true
            color: Theme.textPrimary; selectionColor: Theme.accentStrong; selectedTextColor: Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontHeading - 1
            clip: true
            onAccepted: root.accepted()
            Keys.onDownPressed: root.downPressed()
            Accessible.role: Accessible.EditableText
            Accessible.name: root.placeholder
            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: root.placeholder; visible: !input.text; color: Theme.textTertiary; font: input.font }
        }
        Text { visible: root.hint.length > 0; text: root.hint; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
    }
}
