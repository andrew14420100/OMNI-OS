import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var catalog: null
    property var store: null
    property var frame: null
    readonly property var apps: page.store ? (page.store.revision, page.catalog.installed()) : []
    title: qsTr("Installate")
    subtitle: qsTr("%n app Flatpak installate. Rimuovere un'app non elimina i tuoi documenti.", "", apps.length)
    StatusNote { width: parent.width; text: page.store ? page.store.message : ""; kind: page.store ? page.store.messageKind : 0 }
    Repeater {
        model: page.apps
        delegate: AppCard {
            required property var modelData
            width: parent.width; appId: modelData.appId; name: modelData.name; summary: (modelData.summary || modelData.appId) + " · " + qsTr("versione %1").arg(modelData.installedVersion || modelData.version || "?") + " · " + (modelData.installation === "system" ? qsTr("per tutti gli utenti") : qsTr("solo per te"))
            icon: modelData.icon || ""; installed: true; updateAvailable: !!modelData.updateAvailable; busy: page.store.busy[modelData.appId] || null
            onClicked: page.frame.showApp(modelData.appId)
        }
    }
}
