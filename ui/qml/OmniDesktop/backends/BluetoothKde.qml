import QtQuick
import org.kde.bluezqt as BluezQt

// Bluetooth REALE tramite BlueZ: stato dell'adattatore, accensione, ricerca, associazione.
// Senza adattatore (tipico in una macchina virtuale) lo stato è "non disponibile".
QtObject {
    id: root
    readonly property var manager: BluezQt.Manager
    readonly property var adapter: manager.usableAdapter
    readonly property bool available: manager.operational && adapter !== null
    readonly property bool powered: adapter ? adapter.powered : false
    readonly property bool blocked: manager.bluetoothBlocked
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property string note: !manager.operational ? qsTr("Servizio Bluetooth non attivo")
                                  : (adapter === null ? qsTr("Nessun adattatore Bluetooth disponibile") : "")
    property BluezQt.DevicesModel devices: BluezQt.DevicesModel {}

    function setPowered(on) { if (adapter) { manager.bluetoothBlocked = false; adapter.powered = on } }
    function startDiscovery() { if (adapter && !adapter.discovering) adapter.startDiscovery() }
    function stopDiscovery() { if (adapter && adapter.discovering) adapter.stopDiscovery() }
    function toggleDevice(device) {
        if (!device) return
        if (device.connected) device.disconnectFromDevice()
        else if (device.paired) device.connectToDevice()
        else device.pair()
    }
}
