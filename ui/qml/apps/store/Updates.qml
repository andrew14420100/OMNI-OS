import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var catalog: null
    property var store: null
    property var frame: null
    readonly property var list: page.store ? (page.store.revision, page.catalog.updates()) : []
    title: qsTr("Aggiornamenti delle app")
    subtitle: qsTr("Aggiornamenti delle app Flatpak. Gli aggiornamenti del sistema sono in Impostazioni › Aggiornamenti.")
    Row {
        spacing: 8
        OmniButton { text: qsTr("Controlla ora"); onClicked: { page.store.say(qsTr("Controllo degli aggiornamenti…"), 3); page.store.refreshCatalog() } }
        OmniButton { objectName: "store:aggiorna-tutte"; primary: true; text: qsTr("Aggiorna tutte (%1)").arg(page.list.length); enabled: page.list.length > 0
            onClicked: page.list.forEach(a => page.store.update(a)) }
    }
    StatusNote { width: parent.width; text: page.store ? page.store.message : ""; kind: page.store ? page.store.messageKind : 0 }
    StatusNote { visible: page.list.length === 0; width: parent.width; kind: 1; text: qsTr("Tutte le app sono aggiornate (ultimo controllo all'apertura dello Store).") }
    Repeater {
        model: page.list
        delegate: AppCard {
            required property var modelData
            width: parent.width; appId: modelData.appId; name: modelData.name; icon: modelData.icon || ""
            summary: qsTr("%1 → %2").arg(modelData.installedVersion || "?").arg(modelData.newVersion || qsTr("nuova versione"))
            installed: true; updateAvailable: true; busy: page.store.busy[modelData.appId] || null
            onClicked: page.frame.showApp(modelData.appId)
        }
    }
}
