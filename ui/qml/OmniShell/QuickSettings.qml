import QtQuick
import QtQuick.Layouts
import OmniDesign

// Impostazioni rapide OMNI (decisione 20). Funzionanti nel prototipo: tema chiaro/scuro,
// colore d'accento, movimento ridotto, risparmio risorse, non disturbare.
// Wi-Fi, Bluetooth, volume, luminosità, Assistente AI, blocco e spegnimento sono PROTOTIPI
// non collegati al sistema (etichetta "Prototipo").
Item {
    id: root
    property var store: null
    property bool open: false
    property string userName: ""
    signal closeRequested()
    visible: card.opacity > 0

    MouseArea { anchors.fill: parent; enabled: root.open; onClicked: root.closeRequested() }
    onOpenChanged: if (open) card.forceActiveFocus()

    OmniSurface {
        id: card
        width: Math.min(428, parent.width - Theme.s6)
        height: col.implicitHeight + Theme.s4 * 2
        anchors.right: parent.right; anchors.rightMargin: Theme.s3
        y: 56 + (root.open ? 0 : -12)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.97
        transformOrigin: Item.TopRight
        radius: Theme.radiusXL - 4
        strong: true
        Behavior on y { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
        Behavior on scale { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        Keys.onEscapePressed: root.closeRequested()
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.s4
            spacing: Theme.s3

            // intestazione: utente reale della sessione, azioni di sistema (prototipo)
            Reveal {
                shown: root.open; delay: 0; Layout.fillWidth: true; Layout.preferredHeight: 44
                RowLayout {
                    anchors.fill: parent; spacing: Theme.s3
                    Rectangle {
                        Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
                        gradient: Gradient { GradientStop { position: 0; color: Theme.glow } GradientStop { position: 1; color: Theme.glowPair } }
                        Text { visible: root.userName.length > 0; anchors.centerIn: parent; text: root.userName.charAt(0).toUpperCase(); color: "#FFFFFF"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.Bold }
                        OmniIcon { visible: root.userName.length === 0; anchors.centerIn: parent; width: 20; height: 20; name: "user"; color: "#FFFFFF" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: root.userName || qsTr("Utente"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: qsTr("Sessione del prototipo"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                    }
                    OmniIconButton { icon: "lock"; label: qsTr("Blocca (prototipo)"); round: true; enabled: false; opacity: 0.55 }
                    OmniIconButton { icon: "power"; label: qsTr("Spegni (prototipo)"); round: true; enabled: false; opacity: 0.55 }
                }
            }

            // connettività (prototipo)
            Reveal {
                shown: root.open; delay: Theme.staggerStep * 1; Layout.fillWidth: true; Layout.preferredHeight: 76
                RowLayout {
                    anchors.fill: parent; spacing: Theme.s2
                    OmniToggleTile { Layout.fillWidth: true; large: true; icon: "wifi"; title: qsTr("Wi-Fi"); checked: true; prototype: true }
                    OmniToggleTile { Layout.fillWidth: true; large: true; icon: "bluetooth"; title: qsTr("Bluetooth"); prototype: true }
                }
            }

            // funzioni operative nel prototipo
            Reveal {
                shown: root.open; delay: Theme.staggerStep * 2; Layout.fillWidth: true; Layout.preferredHeight: grid.implicitHeight
                GridLayout {
                    id: grid; anchors.left: parent.left; anchors.right: parent.right
                    columns: 2; columnSpacing: Theme.s2; rowSpacing: Theme.s2
                    OmniToggleTile { objectName: "qs:dark"; Layout.fillWidth: true; icon: Theme.dark ? "moon" : "sun"; title: qsTr("Tema scuro"); subtitle: Theme.dark ? qsTr("Attivo") : qsTr("Disattivo"); checked: Theme.dark; onToggled: (c) => Theme.dark = c }
                    OmniToggleTile { objectName: "qs:dnd"; Layout.fillWidth: true; icon: "bell-off"; title: qsTr("Non disturbare"); subtitle: root.store && root.store.doNotDisturb ? qsTr("Avvisi silenziati") : qsTr("Disattivo"); checked: root.store ? root.store.doNotDisturb : false; onToggled: (c) => root.store.doNotDisturb = c }
                    OmniToggleTile { objectName: "qs:motion"; Layout.fillWidth: true; icon: "motion"; title: qsTr("Movimento ridotto"); subtitle: qsTr("Accessibilità"); checked: Theme.reducedMotion; onToggled: (c) => Theme.reducedMotion = c }
                    OmniToggleTile { Layout.fillWidth: true; icon: "leaf"; title: qsTr("Risparmio risorse"); subtitle: qsTr("Sfondo statico"); checked: Theme.lowPower; onToggled: (c) => Theme.lowPower = c }
                }
            }

            // cursori (prototipo)
            Reveal {
                shown: root.open; delay: Theme.staggerStep * 3; Layout.fillWidth: true; Layout.preferredHeight: 44 * 2 + Theme.s2
                ColumnLayout {
                    anchors.fill: parent; spacing: Theme.s2
                    OmniSlider { objectName: "qs:volume"; Layout.fillWidth: true; Layout.preferredHeight: 44; icon: "volume"; label: qsTr("Volume"); value: 0.62; prototype: true }
                    OmniSlider { Layout.fillWidth: true; Layout.preferredHeight: 44; icon: "sun"; label: qsTr("Luminosità"); value: 0.8; prototype: true }
                }
            }

            // colore d'accento (operativo nel prototipo)
            Reveal {
                shown: root.open; delay: Theme.staggerStep * 4; Layout.fillWidth: true; Layout.preferredHeight: 40
                RowLayout {
                    anchors.fill: parent; spacing: Theme.s2
                    OmniIcon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: "palette"; color: Theme.textSecondary }
                    Text { text: qsTr("Accento"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; Layout.fillWidth: true }
                    Repeater {
                        model: Theme.accents
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool sel: Theme.accentIndex === index
                            objectName: "qs:accent" + index
                            width: 30; height: 30; radius: 15
                            color: Theme.dark ? modelData.dark : modelData.light
                            border.color: sel || activeFocus ? Theme.textPrimary : "transparent"; border.width: 2
                            activeFocusOnTab: true
                            Accessible.role: Accessible.RadioButton; Accessible.name: qsTr("Accento %1").arg(modelData.name); Accessible.checked: sel
                            Keys.onSpacePressed: Theme.accentIndex = index; Keys.onReturnPressed: Theme.accentIndex = index
                            OmniIcon { anchors.centerIn: parent; width: 16; height: 16; name: "check"; color: Theme.dark ? "#06121A" : "#FFFFFF"; visible: parent.sel; strokeWidth: 2.4 }
                            MouseArea { anchors.fill: parent; onClicked: Theme.accentIndex = index }
                        }
                    }
                }
            }

            // Assistente AI (prototipo)
            Reveal {
                shown: root.open; delay: Theme.staggerStep * 5; Layout.fillWidth: true; Layout.preferredHeight: 64
                OmniToggleTile { anchors.fill: parent; icon: "sparkle"; title: qsTr("Assistente AI"); prototype: true }
            }
        }
    }
}
