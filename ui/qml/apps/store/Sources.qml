import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var catalog: null
    property var store: null
    property var frame: null
    title: qsTr("Sorgenti")
    subtitle: qsTr("Raccolte di app Flatpak da cui lo Store legge il catalogo. Le app Flatpak funzionano in un ambiente isolato con i permessi indicati.")
    StatusNote { visible: page.store && !page.store.flatpak; width: parent.width; kind: 2; text: qsTr("Flatpak non è disponibile in questo sistema.") }
    StatusNote { width: parent.width; text: page.store ? page.store.message : ""; kind: page.store ? page.store.messageKind : 0 }
    Repeater {
        model: page.store ? page.store.remotes : []
        delegate: SettingCard { required property var modelData; icon: "globe"; title: modelData.name + (modelData.disabled ? qsTr(" (disattivata)") : "")
            subtitle: modelData.url + " · " + (modelData.installation === "user" ? qsTr("solo per te") : qsTr("per tutti gli utenti")) }
    }
    SettingCard {
        visible: page.store && page.store.flatpak && !page.store.hasFlathub
        icon: "plus"; title: qsTr("Aggiungi Flathub")
        subtitle: qsTr("Sorgente gratuita gestita dalla comunità (dl.flathub.org), aggiunta solo per il tuo utente. Non installa nessuna app.")
        OmniButton { objectName: "store:aggiungi-flathub"; primary: true; text: qsTr("Aggiungi"); onClicked: page.store.addFlathub() }
    }
    SettingCard {
        icon: "restart"; title: qsTr("Catalogo")
        subtitle: page.catalog ? (page.catalog.total > 0 ? qsTr("%1 app da %2").arg(page.catalog.total).arg(page.catalog.sources.join(", ")) : page.catalog.lastError) : ""
        OmniButton { text: page.store && page.store.refreshingCatalog ? qsTr("Aggiornamento…") : qsTr("Aggiorna il catalogo"); enabled: page.store && page.store.flatpak && !page.store.refreshingCatalog; onClicked: page.store.refreshCatalog() }
    }
}
