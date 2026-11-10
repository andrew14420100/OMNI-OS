import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    property var services: null
    property var frame: null
    title: qsTr("Notifiche")
    subtitle: qsTr("Le notifiche delle app arrivano al centro notifiche di OMNI. \"Non disturbare\" è lo stesso interruttore delle impostazioni rapide.")
    SettingCard {
        objectName: "notif:dnd"
        icon: shellSettings.doNotDisturb ? "bell-off" : "bell"; title: qsTr("Non disturbare")
        subtitle: qsTr("Le notifiche restano nel centro notifiche senza comparire; quelle urgenti compaiono comunque")
        OmniSwitch { objectName: "notif:dnd:switch"; checked: shellSettings.doNotDisturb; onToggled: shellSettings.doNotDisturb = checked }
    }
    SettingCard { icon: "settings"; title: qsTr("Suoni e comportamento per singola app"); subtitle: qsTr("Configurazione degli eventi delle app KDE"); clickable: true; onClicked: systemStatus.openSettings("kcm_notifications")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
}
