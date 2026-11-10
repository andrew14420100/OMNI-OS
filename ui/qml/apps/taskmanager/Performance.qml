import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var mon: null
    property var services: null
    property var frame: null
    title: qsTr("Prestazioni")
    subtitle: page.mon ? qsTr("%1 · %2 CPU%3 · acceso da %4").arg(page.mon.hardware.cpuModel).arg(page.mon.hardware.cpuCount)
        .arg(page.mon.hardware.virtual ? qsTr(" · macchina virtuale") : "").arg(Math.floor(page.mon.uptimeSec / 3600) + " h " + Math.floor(page.mon.uptimeSec % 3600 / 60) + " min") : ""
    component Panel: Rectangle {
        id: pn
        property string label; property string value; property alias graph: gr
        width: parent ? parent.width : 600; height: 150; radius: 8; color: Theme.dark ? "#161D31" : "#FFFFFF"; border.color: Theme.outline
        Text { x: 16; y: 12; text: pn.label; color: Theme.textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
        Text { anchors { right: parent.right; rightMargin: 16 } y: 12; text: pn.value; color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily }
        LineGraph { id: gr; x: 16; y: 40; width: parent.width - 32; height: parent.height - 56 }
    }
    Panel { objectName: "perf:cpu"; label: qsTr("Processore"); value: page.mon ? page.mon.cpu.toFixed(0) + " %" : ""; graph.values: page.mon ? page.mon.cpuHistory : [] }
    Flow {
        width: parent.width; spacing: 4
        Repeater { model: page.mon ? page.mon.cpuCores : []
            delegate: Rectangle { required property real modelData; required property int index; width: 70; height: 34; radius: 4; color: Theme.surfaceSunken
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height * modelData / 100; radius: 4; color: Theme.accentSoft }
                Text { anchors.centerIn: parent; text: "CPU" + index + " " + modelData.toFixed(0) + "%"; color: Theme.textSecondary; font.pixelSize: 11; font.family: Theme.fontFamily } } }
    }
    Panel { label: qsTr("Memoria"); value: page.mon ? qsTr("%1 di %2 GB in uso").arg((page.mon.memUsedMb / 1024).toFixed(1)).arg((page.mon.memTotalMb / 1024).toFixed(1)) + (page.mon.swapTotalMb > 0 ? qsTr(" · swap %1 MB").arg(page.mon.swapUsedMb.toFixed(0)) : "") : ""
        graph.values: page.mon ? page.mon.memHistory : [] }
    Panel { label: qsTr("Disco"); value: page.mon ? qsTr("lettura %1 KB/s · scrittura %2 KB/s").arg(page.mon.diskReadKBs.toFixed(0)).arg(page.mon.diskWriteKBs.toFixed(0)) : ""
        graph.values: page.mon ? page.mon.diskHistory : []; graph.maxValue: 1024; graph.color: Theme.glowPair }
    Panel { label: qsTr("Rete"); value: page.mon ? qsTr("ricezione %1 KB/s · invio %2 KB/s").arg(page.mon.netRxKBs.toFixed(1)).arg(page.mon.netTxKBs.toFixed(1)) : ""
        graph.values: page.mon ? page.mon.netHistory : []; graph.maxValue: 64; graph.color: Theme.success }
    SettingCard {
        objectName: "perf:gpu"
        icon: "display"; title: qsTr("Grafica")
        subtitle: !page.mon || !page.mon.gpu.driver ? qsTr("Nessuna scheda grafica esposta") :
            qsTr("driver %1 (%2:%3)").arg(page.mon.gpu.driver).arg(page.mon.gpu.vendorId).arg(page.mon.gpu.deviceId)
            + (page.mon.gpu.virtual ? qsTr(" · scheda virtuale della VM: il carico della GPU fisica non è visibile da qui") : "")
            + (page.mon.gpu.busy !== undefined ? qsTr(" · utilizzo %1%").arg(page.mon.gpu.busy) : qsTr(" · utilizzo non pubblicato dal driver"))
    }
}
