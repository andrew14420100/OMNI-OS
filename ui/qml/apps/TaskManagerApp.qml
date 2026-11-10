import QtQuick
import QtQuick.Window
import OmniDesign
import OmniDesktop
import OmniApps
import OmniSystemMonitor

// OMNI Task Manager: processi, prestazioni, app aperte e avvio, con dati reali (/proc, /sys,
// KWin). Il campionamento si ferma quando la finestra è ridotta a icona o nascosta.
AppFrame {
    id: app
    appTitle: qsTr("Gestione attività")
    baseUrl: Qt.resolvedUrl(".")
    showSearch: false
    property SystemMonitor mon: SystemMonitor { active: app.visibility !== Window.Minimized && app.visibility !== Window.Hidden }
    property Services svc: Services {}
    pageProps: ({ mon: mon, services: svc, frame: app })
    sections: [
        { id: "processi", title: qsTr("Processi"), icon: "layers", source: "taskmanager/Processes.qml" },
        { id: "prestazioni", title: qsTr("Prestazioni"), icon: "cpu", source: "taskmanager/Performance.qml" },
        { id: "app", title: qsTr("App aperte"), icon: "apps", source: "taskmanager/Windows.qml" },
        { id: "avvio", title: qsTr("App all'avvio"), icon: "restart", source: "taskmanager/Startup.qml" }
    ]
    Component.onCompleted: svc.loadEarly()
}
