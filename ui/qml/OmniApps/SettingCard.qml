import QtQuick
import OmniDesign

// Riga di impostazione: icona, titolo, descrizione e controllo a destra (come nelle
// Impostazioni di Windows 11, con lo stile OMNI). Facoltativamente cliccabile.
Rectangle {
    id: card
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool clickable: false
    property bool warning: false
    default property alias control: right.data
    signal clicked()
    width: parent ? parent.width : 600
    height: Math.max(64, textCol.implicitHeight + 24)
    radius: 8
    color: ma.containsMouse && clickable ? (Theme.dark ? "#1E2640" : "#EEF1F8") : (Theme.dark ? "#161D31" : "#FFFFFF")
    border.color: warning ? Theme.prototype : Theme.outline
    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 90 } }
    Accessible.role: clickable ? Accessible.Button : Accessible.Grouping
    Accessible.name: title
    OmniIcon {
        id: ic
        visible: card.icon !== ""
        x: 20; anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20; name: card.icon || "settings"; color: Theme.textPrimary
    }
    Column {
        id: textCol
        anchors { left: card.icon !== "" ? ic.right : parent.left; leftMargin: card.icon !== "" ? 16 : 20; right: right.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        Text { width: parent.width; text: card.title; color: Theme.textPrimary; font.pixelSize: 14; font.family: Theme.fontFamily; elide: Text.ElideRight }
        Text { width: parent.width; visible: text !== ""; text: card.subtitle; color: card.warning ? Theme.prototype : Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily; wrapMode: Text.WordWrap }
    }
    Row {
        id: right
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 8
    }
    MouseArea { id: ma; anchors.fill: parent; z: -1; hoverEnabled: true; enabled: card.clickable; onClicked: card.clicked() }
}
