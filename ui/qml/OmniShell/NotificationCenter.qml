import QtQuick
import QtQuick.Layouts
import OmniDesign

// Centro notifiche OMNI (decisione 20): pannello laterale con elenco, rimozione
// animata e "Cancella tutto". Riceve solo le notifiche interne al prototipo.
Item {
    id: root
    property var store: null
    property bool open: false
    signal closeRequested()
    visible: panel.x < width
    Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: root.open ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
                MouseArea { anchors.fill: parent; enabled: root.open; onClicked: root.closeRequested() } }

    OmniSurface {
        id: panel
        width: 400; height: parent.height - Theme.s4 * 2 - 80
        y: Theme.s4
        x: root.open ? parent.width - width - Theme.s4 : parent.width + Theme.s4
        radius: Theme.radiusLarge
        Behavior on x { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: Theme.s4; spacing: Theme.s3
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Notifiche"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle + 2; font.weight: Font.Bold; Layout.fillWidth: true }
                OmniButton { text: qsTr("Cancella tutto"); visible: root.store && root.store.count > 0; onClicked: root.store.clear() }
            }
            RowLayout {
                spacing: Theme.s2
                PrototypeBadge { text: qsTr("Prototipo · non collegato alla sessione") }
                PrototypeBadge { visible: root.store && root.store.doNotDisturb; text: qsTr("Non disturbare") }
            }
            ListView {
                id: list
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: Theme.s2
                model: root.store ? root.store.model : null
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationNormal } NumberAnimation { property: "x"; from: 40; duration: Theme.durationNormal; easing.type: Theme.easing } }
                remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationNormal } NumberAnimation { property: "x"; to: 120; duration: Theme.durationNormal; easing.type: Theme.easing } }
                displaced: Transition { NumberAnimation { property: "y"; duration: Theme.durationNormal; easing.type: Theme.easing } }
                delegate: OmniSurface {
                    required property int nid
                    required property string app
                    required property string title
                    required property string body
                    required property string icon
                    required property string time
                    raised: true; width: list.width; height: content.implicitHeight + Theme.s3 * 2
                    RowLayout {
                        id: content; anchors.fill: parent; anchors.margins: Theme.s3; spacing: Theme.s3
                        Rectangle { Layout.alignment: Qt.AlignTop; width: 36; height: 36; radius: 12; color: Theme.accentSoft
                            OmniIcon { anchors.centerIn: parent; width: 20; height: 20; name: icon; color: Theme.accent } }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: app + " · " + time; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                            Text { text: title; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            Text { text: body; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }
                        OmniIconButton { Layout.alignment: Qt.AlignTop; implicitWidth: 32; implicitHeight: 32; icon: "close"; label: qsTr("Chiudi notifica"); onClicked: root.store.dismiss(nid) }
                    }
                }
            }
            Text {
                visible: !root.store || root.store.count === 0
                Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: Theme.s6
                text: qsTr("Nessuna notifica"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody
            }
        }
    }
}
