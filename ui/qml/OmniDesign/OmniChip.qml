import QtQuick
import QtQuick.Layouts

// Etichetta selezionabile (categorie del launcher, filtri). Navigabile da tastiera.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool checked: false
    property int count: -1
    opacity: enabled ? 1 : 0.4      // disattivato: visibilmente non cliccabile
    signal clicked()
    implicitWidth: row.implicitWidth + Theme.s4 * 2
    implicitHeight: 36
    radius: Theme.radiusSmall
    activeFocusOnTab: true
    color: checked ? Theme.accentSoft : (mouse.containsMouse ? Theme.hover : "transparent")
    border.color: activeFocus ? Theme.accent : (checked ? Theme.accentStrong : "transparent")
    border.width: activeFocus ? 2 : 1
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Accessible.role: Accessible.RadioButton
    Accessible.name: root.text
    Accessible.checked: root.checked
    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()
    RowLayout {
        id: row; anchors.verticalCenter: parent.verticalCenter; x: Theme.s4; spacing: Theme.s2
        OmniIcon { visible: root.icon.length > 0; Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: root.icon; color: root.checked ? Theme.accent : Theme.textSecondary }
        Text { text: root.text; color: root.checked ? Theme.textPrimary : Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: root.checked ? Font.DemiBold : Font.Medium }
        Text { visible: root.count >= 0; text: root.count; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.forceActiveFocus(); root.clicked() } }
}
