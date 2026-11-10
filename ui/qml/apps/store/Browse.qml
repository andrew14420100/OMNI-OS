import QtQuick
import OmniDesign
import OmniApps

Item {
    id: page
    property var catalog: null
    property var store: null
    property var frame: null
    Column {
        id: head
        x: 32; y: 24; width: parent.width - 64; spacing: 12
        Text { text: qsTr("Esplora"); color: Theme.textPrimary; font.pixelSize: 26; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
        Row {
            spacing: 8
            OmniSearchField { objectName: "store:cerca"; width: 360; placeholder: qsTr("Cerca app, sviluppatori, parole chiave"); onTextChanged: page.catalog.search = text }
            OmniChip { text: qsTr("Nome"); checked: page.catalog && page.catalog.sortKey === "name"; onClicked: page.catalog.sortKey = "name" }
            OmniChip { text: qsTr("Aggiornate di recente"); checked: page.catalog && page.catalog.sortKey === "recent"; onClicked: page.catalog.sortKey = "recent" }
        }
        Flow {
            width: parent.width; spacing: 6
            OmniChip { text: qsTr("Tutte"); checked: page.catalog && !page.catalog.category; onClicked: page.catalog.category = "" }
            Repeater { model: page.catalog ? page.catalog.categoryIds() : []
                delegate: OmniChip { required property string modelData; text: page.catalog.categoryName(modelData); checked: page.catalog.category === modelData; onClicked: page.catalog.category = modelData } }
        }
        StatusNote { width: parent.width; text: page.store ? page.store.message : ""; kind: page.store ? page.store.messageKind : 0 }
        Text { visible: page.catalog && page.catalog.total > 0; color: Theme.textTertiary; font.pixelSize: 12; font.family: Theme.fontFamily
            text: page.catalog ? qsTr("%1 app su %2 · catalogo: %3").arg(page.catalog.count).arg(page.catalog.total).arg(page.catalog.sources.join(", ")) : "" }
    }
    // stati vuoti: spiegano cosa manca, senza mostrare app inventate
    Column {
        anchors.centerIn: grid; width: 460; spacing: 12
        visible: page.catalog && !page.catalog.loading && page.catalog.total === 0
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold; font.family: Theme.fontFamily
            text: !page.store.flatpak ? qsTr("Flatpak non è installato") : (!page.store.hasFlathub && page.store.remotes.length === 0 ? qsTr("Nessuna sorgente di applicazioni") : qsTr("Catalogo non ancora scaricato")) }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily
            text: !page.store.hasFlathub ? qsTr("Flathub è la principale raccolta di app Flatpak, gratuita. Puoi aggiungerla dalla pagina Sorgenti: nessuna app verrà installata senza la tua conferma.")
                                         : qsTr("Il catalogo contiene nomi, descrizioni e icone delle app (alcuni MB). Nessuna app verrà installata.") }
        OmniButton { anchors.horizontalCenter: parent.horizontalCenter; primary: true; visible: page.store.flatpak
            text: page.store.hasFlathub ? qsTr("Scarica il catalogo") : qsTr("Vai a Sorgenti")
            enabled: !page.store.refreshingCatalog
            onClicked: page.store.hasFlathub ? page.store.refreshCatalog() : page.frame.open("sorgenti") }
    }
    Text { anchors.centerIn: grid; visible: page.catalog && page.catalog.loading; text: qsTr("Lettura del catalogo…"); color: Theme.textTertiary; font.pixelSize: 14; font.family: Theme.fontFamily }
    Text { anchors.centerIn: grid; visible: page.catalog && !page.catalog.loading && page.catalog.total > 0 && page.catalog.count === 0; text: qsTr("Nessuna app corrisponde alla ricerca"); color: Theme.textTertiary; font.pixelSize: 14; font.family: Theme.fontFamily }
    GridView {
        id: grid
        objectName: "store:griglia"
        anchors { top: head.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 32; rightMargin: 16 }
        clip: true; boundsBehavior: Flickable.StopAtBounds; reuseItems: true
        cellWidth: Math.max(300, Math.floor(width / Math.max(1, Math.floor(width / 316)))); cellHeight: 108
        model: page.catalog
        delegate: Item {
            required property string appId
            required property string name
            required property string summary
            required property string icon
            required property bool installed
            required property bool updateAvailable
            width: grid.cellWidth; height: grid.cellHeight
            AppCard { width: parent.width - 16; appId: parent.appId; name: parent.name; summary: parent.summary; icon: parent.icon
                installed: parent.installed; updateAvailable: parent.updateAvailable; busy: page.store.busy[parent.appId] || null
                onClicked: page.frame.showApp(appId) }
        }
    }
}
