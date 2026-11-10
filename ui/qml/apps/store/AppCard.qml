import QtQuick
import OmniDesign

// Scheda di un'app del catalogo (icona reale dal catalogo AppStream, nome, riassunto).
Rectangle {
    id: card
    property string appId
    property string name
    property string summary
    property string icon
    property bool installed
    property bool updateAvailable
    property var busy: null
    signal clicked()
    width: 300; height: 96; radius: 12
    color: ma.containsMouse ? (Theme.dark ? "#1C2440" : "#FFFFFF") : (Theme.dark ? "#161D31" : "#FBFCFF")
    border.color: Theme.outline
    Image { id: ic; x: 14; anchors.verticalCenter: parent.verticalCenter; width: 56; height: 56; sourceSize: Qt.size(112, 112); asynchronous: true
        source: card.icon ? "file://" + card.icon : ""; fillMode: Image.PreserveAspectFit }
    Rectangle { visible: ic.status !== Image.Ready; x: 14; anchors.verticalCenter: parent.verticalCenter; width: 56; height: 56; radius: 14; color: Theme.accentSoft
        Text { anchors.centerIn: parent; text: card.name.charAt(0).toUpperCase(); color: Theme.accent; font.pixelSize: 24; font.weight: Font.DemiBold; font.family: Theme.fontFamily } }
    Column {
        x: 84; width: parent.width - 96; anchors.verticalCenter: parent.verticalCenter; spacing: 3
        Text { width: parent.width; text: card.name; elide: Text.ElideRight; color: Theme.textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
        Text { width: parent.width; text: card.summary; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily }
        Text { visible: card.installed || !!card.busy; text: card.busy ? card.busy.action + "…" : (card.updateAvailable ? qsTr("Aggiornamento disponibile") : qsTr("Installata"))
            color: card.updateAvailable ? Theme.glowPair : Theme.success; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: card.clicked() }
}
