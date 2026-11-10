import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    readonly property var bt: services ? services.bluetooth : null
    title: qsTr("Bluetooth e dispositivi")
    subtitle: qsTr("Adattatore e dispositivi reali (BlueZ).")
    SettingCard {
        objectName: "bt:stato"
        icon: "bluetooth"; title: "Bluetooth"
        subtitle: !page.bt ? qsTr("Componente Bluetooth non disponibile") : page.bt.available ? (page.bt.powered ? qsTr("Attivo") : qsTr("Disattivato")) : page.bt.note + qsTr(". In una macchina virtuale serve un adattatore USB assegnato alla VM.")
        warning: page.bt !== null && !page.bt.available
        OmniSwitch { visible: page.bt && page.bt.available; checked: page.bt ? page.bt.powered : false; onToggled: page.bt.setPowered(checked) }
    }
    OmniButton { visible: page.bt && page.bt.available && page.bt.powered; text: page.bt && page.bt.discovering ? qsTr("Interrompi la ricerca") : qsTr("Cerca dispositivi"); onClicked: page.bt.discovering ? page.bt.stopDiscovery() : page.bt.startDiscovery() }
    Repeater {
        model: page.bt && page.bt.available ? page.bt.devices : null
        delegate: SettingCard {
            required property var model
            icon: "bluetooth"; title: model.Name; subtitle: model.Connected ? qsTr("Connesso") : model.Paired ? qsTr("Associato") : qsTr("Disponibile")
            OmniButton { text: model.Connected ? qsTr("Disconnetti") : model.Paired ? qsTr("Connetti") : qsTr("Associa"); onClicked: page.bt.toggleDevice(model.Device) }
        }
    }
}
