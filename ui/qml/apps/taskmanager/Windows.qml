import QtQuick
import OmniDesign
import OmniApps
import OmniDesktop

SettingsPage {
    id: page
    property var mon: null
    property var services: null
    property var frame: null
    readonly property var tasks: services ? services.tasks : null
    title: qsTr("App aperte")
    subtitle: qsTr("Finestre reali di KWin con il consumo del loro processo.")
    StatusNote { visible: !page.tasks; text: qsTr("Elenco delle finestre non disponibile"); kind: 2 }
    Repeater {
        model: page.tasks ? page.tasks.model : null
        delegate: SettingCard {
            id: w
            required property var model
            required property int index
            readonly property var d: page.mon && model.AppPid ? page.mon.processDetails(model.AppPid) : ({})
            visible: model.IsWindow === true || model.IsGroupParent === true
            height: visible ? 64 : 0
            icon: "apps"; title: model.display || model.AppName || ""
            subtitle: (model.AppName || "") + (w.d.pid ? qsTr(" · PID %1 · CPU %2% · %3 MB").arg(w.d.pid).arg(Number(w.d.cpu).toFixed(1)).arg(Number(w.d.memMb).toFixed(0)) : "") + (model.IsMinimized ? qsTr(" · ridotta a icona") : "")
            Row { spacing: 6
                OmniButton { text: qsTr("Passa a"); onClicked: page.tasks.activate(w.index) }
                OmniButton { text: qsTr("Chiudi"); onClicked: page.tasks.close(w.index) } }
        }
    }
}
