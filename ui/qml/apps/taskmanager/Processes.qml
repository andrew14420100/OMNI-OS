import QtQuick
import OmniDesign
import OmniApps

Item {
    id: page
    property var mon: null
    property var services: null
    property var frame: null
    property int selected: -1
    property string message: ""
    property bool confirmKill: false
    Column {
        id: head
        x: 32; y: 24; width: parent.width - 64; spacing: 10
        Row {
            width: parent.width; spacing: 12
            Text { text: qsTr("Processi"); color: Theme.textPrimary; font.pixelSize: 26; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
            Text { anchors.baseline: parent.children[0].baseline; text: page.mon ? qsTr("%1 processi · CPU %2% · memoria %3 di %4 GB").arg(page.mon.processCount).arg(page.mon.cpu.toFixed(0)).arg((page.mon.memUsedMb / 1024).toFixed(1)).arg((page.mon.memTotalMb / 1024).toFixed(1)) : ""
                color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily }
        }
        Row {
            spacing: 8
            OmniSearchField { width: 280; placeholder: qsTr("Filtra per nome o PID"); onTextChanged: page.mon.filter = text }
            OmniChip { text: qsTr("Solo i miei"); checked: page.mon && page.mon.onlyMine; onClicked: page.mon.onlyMine = !page.mon.onlyMine }
            OmniChip { text: qsTr("Processi del kernel"); checked: page.mon && page.mon.showKernel; onClicked: page.mon.showKernel = !page.mon.showKernel }
            OmniButton { objectName: "proc:termina"; text: qsTr("Termina attività"); enabled: page.selected > 0; onClicked: page.confirmKill = true }
        }
        Row {
            visible: page.confirmKill; spacing: 8
            StatusNote { width: 420; kind: 2; text: { const d = page.mon ? page.mon.processDetails(page.selected) : {}; return qsTr("Terminare \"%1\" (PID %2)? Il lavoro non salvato potrebbe andare perso.").arg(d.name || "").arg(page.selected) } }
            OmniButton { objectName: "proc:conferma"; text: qsTr("Termina"); primary: true; onClicked: { page.message = page.mon.terminate(page.selected, false) || qsTr("Richiesta di chiusura inviata"); page.confirmKill = false } }
            OmniButton { text: qsTr("Forza"); onClicked: { page.message = page.mon.terminate(page.selected, true) || qsTr("Processo terminato"); page.confirmKill = false } }
            OmniButton { text: qsTr("Annulla"); ghost: true; onClicked: page.confirmKill = false }
        }
        StatusNote { text: page.message }
        Row {
            width: parent.width; height: 32
            component Col: Item { property string label; property string key; property real w; width: w; height: 32
                Text { anchors.verticalCenter: parent.verticalCenter; text: label + (page.mon && page.mon.sortKey === key ? "  ▾" : ""); color: Theme.textSecondary; font.pixelSize: 12; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
                MouseArea { anchors.fill: parent; onClicked: page.mon.sortKey = parent.key } }
            Col { label: qsTr("Nome"); key: "name"; w: parent.width * 0.40 }
            Col { label: qsTr("PID"); key: "pid"; w: parent.width * 0.10 }
            Col { label: qsTr("Utente"); key: "name"; w: parent.width * 0.16 }
            Col { label: qsTr("CPU"); key: "cpu"; w: parent.width * 0.14 }
            Col { label: qsTr("Memoria"); key: "mem"; w: parent.width * 0.20 }
        }
    }
    ListView {
        id: list
        objectName: "proc:elenco"
        anchors { top: head.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 32; rightMargin: 32 }
        clip: true; model: page.mon; reuseItems: true; boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            required property int pid
            required property string name
            required property string user
            required property real cpu
            required property real memMb
            required property bool mine
            width: list.width; height: 30; radius: 4
            color: page.selected === pid ? Theme.accentSoft : (rm.containsMouse ? Theme.hover : "transparent")
            Row {
                anchors.verticalCenter: parent.verticalCenter
                Text { width: list.width * 0.40; text: name; elide: Text.ElideRight; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Text { width: list.width * 0.10; text: pid; color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Text { width: list.width * 0.16; text: user; elide: Text.ElideRight; color: mine ? Theme.textPrimary : Theme.textTertiary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Text { width: list.width * 0.14; text: cpu.toFixed(1) + " %"; color: cpu > 50 ? Theme.danger : Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Text { width: list.width * 0.20; text: memMb >= 1024 ? (memMb / 1024).toFixed(2) + " GB" : memMb.toFixed(1) + " MB"; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
            }
            MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; onClicked: { page.selected = pid; page.message = ""; page.confirmKill = false } }
        }
    }
}
