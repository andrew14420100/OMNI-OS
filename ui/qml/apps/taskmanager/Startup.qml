import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var mon: null
    property var services: null
    property var frame: null
    title: qsTr("App all'avvio")
    subtitle: qsTr("Programmi avviati automaticamente all'accesso. Disattivarli rende l'accesso più rapido.")
    property var entries: omniSystem.autostartEntries()
    Repeater {
        model: page.entries
        delegate: SettingCard { required property var modelData; icon: "restart"; title: modelData.name || modelData.id; subtitle: modelData.comment || modelData.id
            OmniSwitch { checked: modelData.enabled; onToggled: { omniSystem.setAutostart(modelData.id, checked); page.entries = omniSystem.autostartEntries() } } }
    }
}
