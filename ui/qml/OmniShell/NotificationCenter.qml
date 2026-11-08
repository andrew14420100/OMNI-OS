import QtQuick
import QtQuick.Layouts
import OmniDesign

// Centro notifiche OMNI (decisione 20): pannello laterale con schede raggruppate per
// applicazione (pila compressa, espandibile), rimozione con trascinamento laterale o
// pulsante, "Cancella tutto" e Non disturbare. Riceve solo notifiche interne al prototipo.
Item {
    id: root
    property var store: null
    property bool open: false
    property var expanded: ({})
    property var groupList: []
    property real now: Date.now()
    signal closeRequested()
    visible: panel.x < width

    function rebuild() { groupList = store ? store.groups() : [] }
    Connections { target: root.store; function onRevisionChanged() { root.rebuild() } }
    Component.onCompleted: rebuild()
    onStoreChanged: rebuild()
    Timer { interval: 30000; running: root.open; repeat: true; onTriggered: root.now = Date.now() }
    onOpenChanged: if (open) { now = Date.now(); panel.forceActiveFocus() }
    function toggleGroup(app) { const e = Object.assign({}, expanded); e[app] = !e[app]; expanded = e }

    Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: root.open ? 0.6 : 0; Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
                MouseArea { anchors.fill: parent; enabled: root.open; onClicked: root.closeRequested() } }

    OmniSurface {
        id: panel
        width: Math.min(420, parent.width - Theme.s6)
        height: parent.height - 56 - Theme.s4 - 112
        y: 56
        x: root.open ? parent.width - width - Theme.s3 : parent.width + Theme.s6
        radius: Theme.radiusLarge
        strong: true
        Behavior on x { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        Keys.onEscapePressed: root.closeRequested()
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: Theme.s4; spacing: Theme.s3
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.s2
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: qsTr("Notifiche"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontHeading; font.weight: Font.Bold }
                    Text { text: root.store && root.store.count > 0 ? qsTr("%n notifiche", "", root.store.count) + " · " + qsTr("%n app", "", root.groupList.length) : qsTr("Tutto in ordine"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                }
                OmniButton { text: qsTr("Cancella tutto"); icon: "close"; visible: root.store && root.store.count > 0; onClicked: root.store.clear() }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.s2
                OmniIcon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: root.store && root.store.doNotDisturb ? "bell-off" : "bell"; color: Theme.textSecondary }
                Text { Layout.fillWidth: true; text: qsTr("Non disturbare"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody }
                OmniSwitch { label: qsTr("Non disturbare"); checked: root.store ? root.store.doNotDisturb : false; onToggled: (c) => root.store.doNotDisturb = c }
            }
            PrototypeBadge { text: qsTr("Prototipo · non collegato a org.freedesktop.Notifications") }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline }

            ListView {
                id: list
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: Theme.s4
                model: root.groupList
                boundsBehavior: Flickable.StopAtBounds
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationNormal } }
                displaced: Transition { NumberAnimation { property: "y"; duration: Theme.durationNormal; easing.type: Theme.easing } }
                delegate: Column {
                    id: group
                    required property var modelData
                    required property int index
                    readonly property bool isOpen: root.expanded[modelData.app] === true || modelData.items.length === 1
                    width: list.width; spacing: Theme.s2
                    // intestazione del gruppo
                    RowLayout {
                        width: parent.width; spacing: Theme.s2
                        OmniAppIcon { size: 22; shadow: false; appName: group.modelData.app }
                        Text { text: group.modelData.app.replace(/^OMNI /, ""); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: Font.DemiBold }
                        Text { visible: group.modelData.items.length > 1; text: group.modelData.items.length; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                        Item { Layout.fillWidth: true }
                        OmniButton {
                            objectName: "nc:expand:" + AppGlyphs.resolve(group.modelData.app, "", "", [])
                            visible: group.modelData.items.length > 1; ghost: true
                            text: group.isOpen ? qsTr("Comprimi") : qsTr("Mostra tutte")
                            icon: "chevron-down"
                            onClicked: root.toggleGroup(group.modelData.app)
                        }
                        OmniIconButton { implicitWidth: 28; implicitHeight: 28; iconSize: 14; icon: "close"; label: qsTr("Cancella le notifiche di %1").arg(group.modelData.app); onClicked: root.store.dismissApp(group.modelData.app) }
                    }
                    // schede: aperte in elenco oppure pila compressa
                    Item {
                        width: parent.width
                        height: group.isOpen ? stack.height : (first.height + Math.min(2, group.modelData.items.length - 1) * 8)
                        Behavior on height { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
                        // carte "dietro" della pila
                        Repeater {
                            model: group.isOpen ? 0 : Math.min(2, group.modelData.items.length - 1)
                            Rectangle {
                                required property int index
                                x: (index + 1) * 10; width: parent.width - (index + 1) * 20
                                y: first.height - 20 + (index + 1) * 8; height: 24
                                radius: Theme.radius; z: -1 - index
                                color: Theme.surfaceRaised; border.color: Theme.outline
                                opacity: 0.85 - index * 0.25
                            }
                        }
                        Column {
                            id: stack
                            width: parent.width; spacing: Theme.s2
                            Repeater {
                                model: group.isOpen ? group.modelData.items : group.modelData.items.slice(0, 1)
                                NotificationCard {
                                    id: card
                                    required property var modelData
                                    required property int index
                                    width: stack.width
                                    objectName: "nc:card:" + AppGlyphs.resolve(modelData.app, "", "", []) + ":" + index
                                    note: modelData
                                    timeText: root.store ? root.store.relative(modelData.stamp, root.now) : ""
                                    Component.onCompleted: if (index === 0) first.target = card
                                    onDismissed: root.store.dismiss(modelData.nid)
                                }
                            }
                        }
                        QtObject { id: first; property Item target: null; readonly property real height: target ? target.height : 80 }
                    }
                }
            }
            ColumnLayout {
                visible: !root.store || root.store.count === 0
                Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: Theme.s7; spacing: Theme.s2
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter; width: 64; height: 64; radius: 32; color: Theme.accentSoft
                    OmniIcon { anchors.centerIn: parent; width: 28; height: 28; name: "check"; color: Theme.accent; strokeWidth: 2.2 }
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: qsTr("Nessuna notifica"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                Text { Layout.alignment: Qt.AlignHCenter; text: qsTr("Sei in pari."); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1 }
            }
        }
    }
}
