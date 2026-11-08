import QtQuick
import OmniDesign

// Orologio del desktop: ora grande, data e saluto in base all'ora (dati reali del sistema).
Item {
    id: root
    implicitWidth: col.implicitWidth; implicitHeight: col.implicitHeight
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    function greeting(h) { return h < 5 ? qsTr("Buonanotte") : h < 13 ? qsTr("Buongiorno") : h < 18 ? qsTr("Buon pomeriggio") : qsTr("Buonasera") }
    Column {
        id: col; spacing: 2
        Text {
            text: root.greeting(root.now.getHours())
            color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.Medium
        }
        Text {
            text: root.now.toLocaleTimeString(Qt.locale(), "HH:mm")
            color: Theme.textPrimary; font.family: Theme.fontDisplayFamily; font.pixelSize: 96; font.weight: Font.Light
            style: Text.Raised; styleColor: Theme.dark ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.6)
        }
        Text {
            text: root.now.toLocaleDateString(Qt.locale(), "dddd d MMMM yyyy")
            color: Theme.textPrimary; opacity: 0.85; font.family: Theme.fontFamily; font.pixelSize: Theme.fontHeading; font.weight: Font.Medium
        }
    }
}
