import QtQuick
import QtQuick.Layouts
import OmniDesign

// Barra superiore flottante: marchio e spazi di lavoro (prototipo, non collegati a KWin),
// data e ora reali al centro, area di stato a destra che apre Impostazioni rapide e Notifiche.
Item {
    id: root
    property int notificationCount: 0
    property bool doNotDisturb: false
    property bool quickSettingsOpen: false
    property bool notificationsOpen: false
    property int currentWorkspace: 0
    signal quickSettingsRequested()
    signal notificationsRequested()
    signal launcherRequested()
    height: 40

    OmniSurface {
        anchors.fill: parent
        radius: Theme.radius
        elevated: false
    }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: Theme.s2; anchors.rightMargin: Theme.s2; spacing: Theme.s2

        // marchio: anello aurora + nome di lavoro
        Rectangle {
            Layout.preferredWidth: brand.implicitWidth + Theme.s4; Layout.preferredHeight: 30; radius: Theme.radiusSmall
            color: brandMouse.containsMouse || activeFocus ? Theme.hover : "transparent"
            border.color: activeFocus ? Theme.accent : "transparent"; border.width: 2
            activeFocusOnTab: true
            Accessible.role: Accessible.Button; Accessible.name: qsTr("Applicazioni")
            Keys.onReturnPressed: root.launcherRequested(); Keys.onSpacePressed: root.launcherRequested()
            Row {
                id: brand; anchors.centerIn: parent; spacing: 8
                Rectangle {
                    width: 18; height: 18; radius: 9; anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient { orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.glow } GradientStop { position: 1; color: Theme.glowPair } }
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.background }
                }
                Text { text: "OMNI"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.Bold; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: brandMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.launcherRequested() }
        }

        // spazi di lavoro (indicatore del prototipo)
        Row {
            spacing: 6; Layout.leftMargin: Theme.s1
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    readonly property bool active: index === root.currentWorkspace
                    width: active ? 30 : 22; height: 22; radius: 7
                    color: active ? Theme.accentSoft : (wsMouse.containsMouse ? Theme.hover : "transparent")
                    border.color: active ? Theme.accentStrong : Theme.outline
                    Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingEmphasized } }
                    Text { anchors.centerIn: parent; text: index + 1; color: parent.active ? Theme.accent : Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontMicro; font.weight: Font.DemiBold }
                    MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.currentWorkspace = index }
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Spazio di lavoro %1 (prototipo)").arg(index + 1)
                }
            }
        }
        PrototypeBadge { text: qsTr("Spazi di lavoro: prototipo") }

        Item { Layout.fillWidth: true }

        // data e ora reali (clic: centro notifiche)
        Rectangle {
            Layout.preferredWidth: clockRow.implicitWidth + Theme.s4; Layout.preferredHeight: 30; radius: Theme.radiusSmall
            color: root.notificationsOpen ? Theme.accentSoft : (clockMouse.containsMouse || activeFocus ? Theme.hover : "transparent")
            border.color: activeFocus ? Theme.accent : "transparent"; border.width: 2
            activeFocusOnTab: true
            Accessible.role: Accessible.Button; Accessible.name: qsTr("Data, ora e notifiche")
            Keys.onReturnPressed: root.notificationsRequested(); Keys.onSpacePressed: root.notificationsRequested()
            Row {
                id: clockRow; anchors.centerIn: parent; spacing: 8
                Text { id: dateText; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                Text { id: timeText; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: { const d = new Date(); timeText.text = d.toLocaleTimeString(Qt.locale(), "HH:mm"); dateText.text = d.toLocaleDateString(Qt.locale(), "ddd d MMM") }
            }
            MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.notificationsRequested() }
        }

        Item { Layout.fillWidth: true }

        // area di stato
        Rectangle {
            objectName: "topbar:tray"
            Layout.preferredWidth: tray.implicitWidth + Theme.s4; Layout.preferredHeight: 30; radius: Theme.radiusSmall
            color: root.quickSettingsOpen ? Theme.accentSoft : (trayMouse.containsMouse || activeFocus ? Theme.hover : "transparent")
            border.color: activeFocus ? Theme.accent : "transparent"; border.width: 2
            activeFocusOnTab: true
            Accessible.role: Accessible.Button; Accessible.name: qsTr("Impostazioni rapide")
            Keys.onReturnPressed: root.quickSettingsRequested(); Keys.onSpacePressed: root.quickSettingsRequested()
            Row {
                id: tray; anchors.centerIn: parent; spacing: 10
                OmniIcon { width: 17; height: 17; name: "wifi"; color: Theme.textPrimary }
                OmniIcon { width: 17; height: 17; name: "volume"; color: Theme.textPrimary }
                OmniIcon { width: 17; height: 17; name: Theme.dark ? "moon" : "sun"; color: Theme.textPrimary }
            }
            MouseArea { id: trayMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.quickSettingsRequested() }
        }
        OmniIconButton {
            objectName: "topbar:bell"
            implicitWidth: 34; implicitHeight: 30; iconSize: 18
            icon: root.doNotDisturb ? "bell-off" : "bell"; label: qsTr("Notifiche")
            badge: root.doNotDisturb ? 0 : root.notificationCount; checked: root.notificationsOpen
            onClicked: root.notificationsRequested()
        }
    }
}
