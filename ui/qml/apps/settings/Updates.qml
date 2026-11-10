import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

// Aggiornamenti nel rispetto del sistema atomico: rpm-ostree prepara un nuovo deployment che
// diventa attivo al riavvio; il precedente resta disponibile per tornare indietro.
SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Aggiornamenti")
    subtitle: qsTr("Sistema (rpm-ostree, atomico: si applica al riavvio e si può annullare) e app Flatpak. Nessun aggiornamento viene installato senza la tua conferma.")
    property var deployments: []
    property string sysState: ""
    property int sysKind: 0
    property bool busy: false
    property var flatUpdates: []
    property string flatState: ""
    property string log: ""
    function reload() {
        Sys.run("rpm-ostree", ["status", "--json"], (c, o, e) => {
            try { page.deployments = JSON.parse(o).deployments || [] } catch (x) { page.deployments = []; page.sysState = e || qsTr("Stato non leggibile"); page.sysKind = 2 }
        })
        Sys.run("flatpak", ["remote-ls", "--updates", "--app", "--columns=application,version"], (c, o, e) => {
            page.flatUpdates = c === 0 ? o.split("\n").filter(x => x.trim()).map(l => l.split("\t")) : []
            page.flatState = c === 0 ? (page.flatUpdates.length ? qsTr("%1 aggiornamenti disponibili").arg(page.flatUpdates.length) : qsTr("Tutte le app Flatpak sono aggiornate")) : qsTr("Controllo non riuscito: %1").arg(e.trim())
        }, { timeout: 120000 })
    }
    function rpm(args, label) {
        page.busy = true; page.sysState = label + "…"; page.sysKind = 3; page.log = ""
        Sys.run("rpm-ostree", args, (c, o, e) => {
            page.busy = false
            page.sysState = c === 0 ? label + qsTr(": completato") : label + qsTr(": non riuscito (%1)").arg((e || o).trim().split("\n").pop())
            page.sysKind = c === 0 ? 1 : 2
            page.reload()
        }, { timeout: 1800000, onLine: l => page.log = l })
    }
    readonly property var staged: deployments.filter(d => d.staged)
    readonly property bool rebootNeeded: staged.length > 0 || deployments.some(d => !d.booted && d.pending)
    Component.onCompleted: reload()
    SectionTitle { text: qsTr("Sistema") }
    Repeater {
        model: page.deployments
        delegate: SettingCard {
            required property var modelData
            icon: modelData.booted ? "check" : "history"
            title: (modelData.version || "") + (modelData.booted ? qsTr(" · in uso") : modelData.staged ? qsTr(" · pronto al riavvio") : qsTr(" · precedente"))
            subtitle: (modelData["container-image-reference"] || modelData.origin || "") + " · " + new Date((modelData.timestamp || 0) * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat) + " · " + String(modelData.checksum || "").substring(0, 12)
        }
    }
    StatusNote { objectName: "agg:riavvio"; visible: page.rebootNeeded; text: qsTr("Un aggiornamento è pronto: si attiva al prossimo riavvio."); kind: 1 }
    Row {
        spacing: 8
        OmniButton { objectName: "agg:controlla"; text: qsTr("Controlla aggiornamenti"); enabled: !page.busy; onClicked: page.rpm(["upgrade", "--check"], qsTr("Controllo degli aggiornamenti di sistema")) }
        OmniButton { text: qsTr("Scarica e prepara"); primary: true; enabled: !page.busy; onClicked: page.rpm(["upgrade"], qsTr("Preparazione dell'aggiornamento")) }
        OmniButton { visible: page.rebootNeeded; text: qsTr("Riavvia ora"); onClicked: sessionActions.reboot() }
    }
    StatusNote { objectName: "agg:stato"; text: page.sysState; kind: page.sysKind }
    StatusNote { text: page.log }
    SettingCard {
        icon: "history"; title: qsTr("Torna alla versione precedente")
        subtitle: page.deployments.length > 1 ? qsTr("Rende di nuovo attivo il deployment precedente al prossimo riavvio (i file personali non cambiano)") : qsTr("Nessuna versione precedente disponibile")
        OmniButton { text: qsTr("Ripristina…"); enabled: page.deployments.length > 1 && !page.busy; onClicked: rb.visible = true }
    }
    Row { id: rb; visible: false; spacing: 8
        StatusNote { width: 380; text: qsTr("Al prossimo riavvio partirà la versione precedente del sistema. Continuare?"); kind: 2 }
        OmniButton { text: qsTr("Ripristina"); primary: true; onClicked: { rb.visible = false; page.rpm(["rollback"], qsTr("Ripristino della versione precedente")) } }
        OmniButton { text: qsTr("Annulla"); ghost: true; onClicked: rb.visible = false } }
    SectionTitle { text: qsTr("App (Flatpak)") }
    SettingCard { icon: "apps"; title: qsTr("Aggiornamenti delle app"); subtitle: page.flatState || qsTr("controllo…")
        OmniButton { text: qsTr("Aggiorna tutto"); enabled: page.flatUpdates.length > 0 && !page.busy
            onClicked: { page.busy = true; Sys.run("flatpak", ["update", "-y", "--noninteractive"], (c, o, e) => { page.busy = false; page.flatState = c === 0 ? qsTr("App aggiornate") : e.trim(); page.reload() }, { timeout: 3600000, onLine: l => page.log = l }) } } }
    Repeater { model: page.flatUpdates; delegate: SettingCard { required property var modelData; title: modelData[0]; subtitle: modelData[1] || "" } }
}
