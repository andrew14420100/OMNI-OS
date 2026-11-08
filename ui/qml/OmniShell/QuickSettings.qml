import QtQuick
import QtQuick.Layouts
import OmniDesign

// Impostazioni rapide OMNI (decisione 20). Funzionanti nel prototipo: tema scuro,
// movimento ridotto, non disturbare. Wi-Fi, Bluetooth, volume e luminosità sono
// PROTOTIPI non collegati al sistema (etichetta "Prototipo").
Item {
    id: root
    property var store: null
    property bool open: false
    signal closeRequested()
    visible: card.opacity > 0
    Rectangle { anchors.fill: parent; color: "transparent"; MouseArea { anchors.fill: parent; enabled: root.open; onClicked: root.closeRequested() } }

    OmniSurface {
        id: card
        width: 432; height: grid.implicitHeight + Theme.s4 * 2
        anchors.right: parent.right; anchors.rightMargin: Theme.s4
        y: parent.height - height - 96 + (root.open ? 0 : 16)
        opacity: root.open ? 1 : 0
        radius: Theme.radiusLarge
        Behavior on y { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: grid; anchors.fill: parent; anchors.margins: Theme.s4; spacing: Theme.s3
            Text { text: qsTr("Impostazioni rapide"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.Bold }
            GridLayout {
                columns: 2; columnSpacing: Theme.s2; rowSpacing: Theme.s2
                OmniToggleTile { icon: Theme.dark ? "moon" : "sun"; title: qsTr("Tema scuro"); subtitle: Theme.dark ? qsTr("Attivo") : qsTr("Disattivo"); checked: Theme.dark; onToggled: (c) => Theme.dark = c }
                OmniToggleTile { icon: "motion"; title: qsTr("Movimento ridotto"); subtitle: qsTr("Accessibilità"); checked: Theme.reducedMotion; onToggled: (c) => Theme.reducedMotion = c }
                OmniToggleTile { icon: "moon-off"; title: qsTr("Non disturbare"); subtitle: qsTr("Avvisi silenziati"); checked: root.store && root.store.doNotDisturb; onToggled: (c) => root.store.doNotDisturb = c }
                OmniToggleTile { icon: "wifi"; title: qsTr("Wi-Fi"); checked: true; prototype: true }
                OmniToggleTile { icon: "bluetooth"; title: qsTr("Bluetooth"); prototype: true }
                OmniToggleTile { icon: "sparkle"; title: qsTr("Assistente AI"); subtitle: qsTr("Spento"); prototype: true }
            }
            OmniSlider { Layout.fillWidth: true; icon: "volume"; label: qsTr("Volume"); value: 0.62; prototype: true }
            OmniSlider { Layout.fillWidth: true; icon: "sun"; label: qsTr("Luminosità"); value: 0.8; prototype: true }
        }
    }
}
