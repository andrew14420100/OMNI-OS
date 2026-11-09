import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

// Rete REALE tramite NetworkManager (componenti di plasma-nm): stato, connessioni
// disponibili, connessione/disconnessione, Wi-Fi. Le password restano gestite da
// NetworkManager e dall'agente dei segreti di KDE (portachiavi), mai da OMNI Shell.
QtObject {
    id: root
    readonly property bool available: true
    readonly property string status: status_.networkStatus
    readonly property string activeConnections: status_.activeConnections
    readonly property bool wirelessAvailable: devices.wirelessDeviceAvailable
    readonly property bool wiredAvailable: devices.wiredDeviceAvailable
    readonly property bool wirelessEnabled: enabled.wirelessEnabled
    readonly property bool wirelessHwEnabled: enabled.wirelessHwEnabled
    readonly property bool networkingEnabled: enabled.networkingEnabled
    readonly property var connections: proxy

    property PlasmaNM.NetworkStatus status_: PlasmaNM.NetworkStatus {}
    property PlasmaNM.AvailableDevices devices: PlasmaNM.AvailableDevices {}
    property PlasmaNM.EnabledConnections enabled: PlasmaNM.EnabledConnections {}
    property PlasmaNM.Handler handler: PlasmaNM.Handler {}
    property PlasmaNM.NetworkModel source: PlasmaNM.NetworkModel {}
    property PlasmaNM.AppletProxyModel proxy: PlasmaNM.AppletProxyModel { sourceModel: root.source }

    function connectTo(connectionPath, devicePath, specificPath) { handler.activateConnection(connectionPath, devicePath, specificPath) }
    function connectNew(devicePath, specificPath, password) {
        if (password) handler.addAndActivateConnection(devicePath, specificPath, password)
        else handler.addAndActivateConnection(devicePath, specificPath)
    }
    function disconnectFrom(connectionPath, devicePath) { handler.deactivateConnection(connectionPath, devicePath) }
    function setWireless(on) { handler.enableWireless(on) }
    function scan() { handler.requestScan() }
    function isActivated(state) { return state === PlasmaNM.Enums.Activated }
    function isActivating(state) { return state === PlasmaNM.Enums.Activating }
    function isWireless(type) { return type === PlasmaNM.Enums.Wireless }
    function needsPassword(security) { return security !== PlasmaNM.Enums.NoneSecurity && security !== undefined && security !== PlasmaNM.Enums.UnknownSecurity }
}
