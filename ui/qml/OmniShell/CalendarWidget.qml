import QtQuick
import QtQuick.Layouts
import OmniDesign

// Calendario mensile (data reale). Navigazione tra i mesi con i pulsanti o le frecce.
OmniSurface {
    id: root
    property date today: new Date()
    property int monthOffset: 0
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    radius: Theme.radiusLarge
    implicitWidth: 320; implicitHeight: col.implicitHeight + Theme.s4 * 2
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.today = new Date() }

    function days() {
        const y = shown.getFullYear(), m = shown.getMonth()
        const first = (new Date(y, m, 1).getDay() + 6) % 7          // lunedì = 0
        const n = new Date(y, m + 1, 0).getDate(), prevN = new Date(y, m, 0).getDate()
        const out = []
        for (let i = 0; i < 42; ++i) {
            const d = i - first + 1
            out.push({ day: d < 1 ? prevN + d : (d > n ? d - n : d), inMonth: d >= 1 && d <= n,
                       today: d === today.getDate() && m === today.getMonth() && y === today.getFullYear() })
        }
        return out
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.s4
        spacing: Theme.s2
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.shown.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
            }
            OmniIconButton { implicitWidth: 30; implicitHeight: 30; iconSize: 16; icon: "chevron-right"; rotation: 180; label: qsTr("Mese precedente"); onClicked: root.monthOffset-- }
            OmniIconButton { implicitWidth: 30; implicitHeight: 30; iconSize: 16; icon: "chevron-right"; label: qsTr("Mese successivo"); onClicked: root.monthOffset++ }
        }
        Grid {
            id: days
            columns: 7; Layout.fillWidth: true
            readonly property real cell: Math.floor((col.width) / 7)
            Repeater {
                model: [qsTr("L"), qsTr("M"), qsTr("M"), qsTr("G"), qsTr("V"), qsTr("S"), qsTr("D")]
                Text { required property string modelData; width: days.cell; height: 22; horizontalAlignment: Text.AlignHCenter; text: modelData; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontMicro; font.weight: Font.DemiBold }
            }
            Repeater {
                model: root.days()
                Item {
                    required property var modelData
                    width: days.cell; height: 34
                    Rectangle {
                        anchors.centerIn: parent; width: 30; height: 30; radius: 15
                        color: modelData.today ? Theme.accent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent; text: modelData.day
                        color: modelData.today ? Theme.textOnAccent : (modelData.inMonth ? Theme.textPrimary : Theme.textTertiary)
                        opacity: modelData.inMonth ? 1 : 0.55
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: modelData.today ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
