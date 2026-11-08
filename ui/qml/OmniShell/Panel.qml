import QtQuick
import QtQuick.Layouts
import OmniDesign

// Pannello OMNI: barra flottante in basso, stile dock (decisione 6: dock dinamico,
// spazi di lavoro multipli; decisione 20: accesso a notifiche e impostazioni rapide).
OmniSurface {
    id: root
    property var apps: null            // modello delle applicazioni (prime voci = fissate)
    property int notificationCount: 0
    property bool launcherOpen: false
    property bool notificationsOpen: false
    property bool quickSettingsOpen: false
    property int currentWorkspace: 0
    signal launcherRequested()
    signal notificationsRequested()
    signal quickSettingsRequested()
    signal appActivated(string name)

    radius: Theme.radiusLarge
    height: 64
    width: row.implicitWidth + Theme.s4 * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.s2

        OmniIconButton { icon: "grid"; label: qsTr("Applicazioni"); checked: root.launcherOpen; onClicked: root.launcherRequested() }

        // Spazi di lavoro: indicatore del prototipo (non collegato a KWin).
        Row {
            spacing: 6; Layout.leftMargin: Theme.s2; Layout.rightMargin: Theme.s2
            Repeater {
                model: 3
                Rectangle {
                    width: index === root.currentWorkspace ? 22 : 8; height: 8; radius: 4
                    color: index === root.currentWorkspace ? Theme.accent : Theme.outline
                    Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingEmphasized } }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.currentWorkspace = index }
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Spazio di lavoro %1").arg(index + 1)
                }
            }
        }
        Rectangle { width: 1; height: 32; color: Theme.outline }

        // Applicazioni fissate: tessere con ingrandimento al passaggio del mouse.
        Repeater {
            model: root.apps ? Math.min(5, root.apps.count) : 0
            delegate: OmniAppTile {
                id: tile
                required property int index
                appName: root.apps.get(index).name
                size: 44
                scale: tileMouse.containsMouse ? 1.18 : 1.0
                transformOrigin: Item.Bottom
                Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingEmphasized } }
                MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.appActivated(tile.appName) }
                Accessible.role: Accessible.Button
                Accessible.name: tile.appName
            }
        }
        Rectangle { width: 1; height: 32; color: Theme.outline }

        OmniIconButton { icon: "sliders"; label: qsTr("Impostazioni rapide"); checked: root.quickSettingsOpen; onClicked: root.quickSettingsRequested() }
        OmniIconButton { icon: "bell"; label: qsTr("Notifiche"); badge: root.notificationCount; checked: root.notificationsOpen; onClicked: root.notificationsRequested() }

        Column {
            Layout.leftMargin: Theme.s2; Layout.rightMargin: Theme.s2
            Text { id: clock; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; anchors.right: parent.right }
            Text { id: date; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; anchors.right: parent.right }
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: { const d = new Date(); clock.text = d.toLocaleTimeString(Qt.locale(), "hh:mm"); date.text = d.toLocaleDateString(Qt.locale(), "ddd d MMM") }
            }
        }
    }
}
