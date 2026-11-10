import QtQuick
import QtQuick.Window
import OmniDesign
import OmniApps
import OmniStore
import "store"

// OMNI Store: applicazioni Flatpak dal catalogo REALE delle sorgenti configurate (Flathub).
// Nessuna installazione automatica: ogni installazione, rimozione o aggiornamento parte solo
// da un clic dell'utente, dopo aver mostrato i permessi richiesti dall'app. L'esito è quello
// riportato da flatpak, mai dichiarato in anticipo.
AppFrame {
    id: app
    appTitle: qsTr("OMNI Store")
    baseUrl: Qt.resolvedUrl(".")
    showSearch: false
    AppStreamCatalog { id: catalog; objectName: "store:catalogo"; onInstalledChanged: store.revision++ }
    QtObject {
        id: store
        property var remotes: []            // [{ name, url, installation }]
        property bool flatpak: omniSystem.available("flatpak")
        property var busy: ({})             // appId -> { action, progress, text, id }
        property string message: ""
        property int messageKind: 0
        property bool refreshingCatalog: false
        readonly property bool hasFlathub: remotes.some(r => r.name === "flathub")
        property int revision: 0           // cambia dopo ogni operazione: le pagine rileggono lo stato
        function say(t, k) { message = t; messageKind = k || 0 }
        function installationFor(remote) {   // utente se la sorgente è dell'utente, altrimenti sistema
            const r = remotes.filter(x => x.name === remote)
            return r.some(x => x.installation === "user") ? "user" : (r.length ? "system" : "user")
        }
        function refreshInstalled() {
            if (!flatpak) return
            const id = omniSystem.run("flatpak", ["list", "--app", "--columns=application,name,version,origin,installation"], 30000)
            pending[id] = { kind: "list" }
        }
        function refreshUpdates() {
            if (!flatpak) return
            const id = omniSystem.run("flatpak", ["remote-ls", "--updates", "--app", "--columns=application,version"], 120000)
            pending[id] = { kind: "updates" }
        }
        function refreshRemotes() {
            if (!flatpak) return
            const id = omniSystem.run("flatpak", ["remotes", "--columns=name,url,options"], 30000)
            pending[id] = { kind: "remotes" }
        }
        function refreshCatalog() {   // scarica i metadati del catalogo (nessuna app installata)
            if (!flatpak || refreshingCatalog) return
            refreshingCatalog = true
            say(qsTr("Aggiornamento del catalogo in corso…"), 3)
            const id = omniSystem.run("flatpak", ["update", "--appstream"], 600000)
            pending[id] = { kind: "appstream" }
        }
        function addFlathub() {
            const id = omniSystem.run("flatpak", ["remote-add", "--user", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"], 120000)
            pending[id] = { kind: "remote-add" }
            say(qsTr("Aggiunta della sorgente Flathub…"), 3)
        }
        function setBusy(appId, v) { const b = Object.assign({}, busy); if (v) b[appId] = v; else delete b[appId]; busy = b }
        function install(a) {
            const inst = installationFor(a.remote)
            const id = omniSystem.run("flatpak", ["install", "--" + inst, "--noninteractive", "-y", a.remote, a.ref], 3600000, true)
            pending[id] = { kind: "install", appId: a.appId, name: a.name }
            setBusy(a.appId, { action: qsTr("Installazione"), progress: -1, text: "", id: id })
        }
        function uninstall(a) {
            const id = omniSystem.run("flatpak", ["uninstall", "--" + (a.installation || "user"), "--noninteractive", "-y", a.appId], 600000, true)
            pending[id] = { kind: "uninstall", appId: a.appId, name: a.name }
            setBusy(a.appId, { action: qsTr("Rimozione"), progress: -1, text: "", id: id })
        }
        function update(a) {
            const id = omniSystem.run("flatpak", ["update", "--" + (a.installation || "user"), "--noninteractive", "-y", a.appId], 3600000, true)
            pending[id] = { kind: "update", appId: a.appId, name: a.name }
            setBusy(a.appId, { action: qsTr("Aggiornamento"), progress: -1, text: "", id: id })
        }
        function cancel(appId) { const b = busy[appId]; if (b) omniSystem.cancel(b.id) }
        function launch(a) {
            const inst = a.installation === "system" ? "/var/lib/flatpak" : omniSystem.homePath() + "/.local/share/flatpak"
            const f = inst + "/exports/share/applications/" + a.appId + ".desktop"
            if (!omniSystem.exists(f) || !omniLauncher.launch(f)) say(qsTr("Impossibile avviare %1").arg(a.name), 2)
        }
        property var pending: ({})
    }
    Connections {
        target: omniSystem
        function onLine(id, text) {
            const p = store.pending[id]; if (!p || !p.appId) return
            const m = /(\d{1,3})\s*%/.exec(text)
            const b = Object.assign({}, store.busy[p.appId] || {})
            b.text = text.replace(/[▀-▟#=\-]{3,}/g, "").trim()
            if (m) b.progress = Math.min(100, parseInt(m[1])) / 100
            store.setBusy(p.appId, b)
        }
        function onFinished(id, code, out, err) {
            const p = store.pending[id]; if (!p) return
            delete store.pending[id]
            const ok = code === 0
            const why = (err || out || "").trim().split("\n").filter(x => x).slice(-1)[0] || qsTr("codice %1").arg(code)
            switch (p.kind) {
            case "list": if (ok) catalog.setInstalled(out); break
            case "updates": if (ok) catalog.setUpdates(out); break
            case "remotes":
                if (ok) store.remotes = out.split("\n").filter(l => l.trim()).map(l => { const f = l.split("\t"); return { name: f[0], url: f[1] || "", installation: (f[2] || "").indexOf("user") >= 0 ? "user" : "system", disabled: (f[2] || "").indexOf("disabled") >= 0 } })
                break
            case "appstream":
                store.refreshingCatalog = false
                store.say(ok ? qsTr("Catalogo aggiornato") : qsTr("Catalogo non aggiornato: %1").arg(why), ok ? 1 : 2)
                catalog.reload(); store.refreshUpdates(); break
            case "remote-add":
                store.say(ok ? qsTr("Sorgente Flathub aggiunta") : qsTr("Sorgente non aggiunta: %1").arg(why), ok ? 1 : 2)
                store.refreshRemotes(); if (ok) store.refreshCatalog(); break
            default:
                store.setBusy(p.appId, null)
                const verbs = { install: qsTr("installata"), uninstall: qsTr("rimossa"), update: qsTr("aggiornata") }
                store.say(ok ? qsTr("%1 %2").arg(p.name).arg(verbs[p.kind]) : (code === -9 || code === -3 ? qsTr("Operazione annullata: %1").arg(p.name) : qsTr("%1 non %2: %3").arg(p.name).arg(verbs[p.kind]).arg(why)), ok ? 1 : 2)
                store.refreshInstalled(); store.refreshUpdates()
            }
            store.revision++
        }
    }
    property string detailId: ""
    function showApp(appId) { detailId = appId }
    pageProps: ({ catalog: catalog, store: store, frame: app })
    sections: [
        { id: "esplora", title: qsTr("Esplora"), icon: "sparkle", source: "store/Browse.qml" },
        { id: "installate", title: qsTr("Installate"), icon: "apps", source: "store/Installed.qml" },
        { id: "aggiornamenti", title: qsTr("Aggiornamenti"), icon: "restart", source: "store/Updates.qml" },
        { id: "sorgenti", title: qsTr("Sorgenti"), icon: "globe", source: "store/Sources.qml" }
    ]
    Component.onCompleted: { catalog.reload(); store.refreshRemotes(); store.refreshInstalled(); store.refreshUpdates() }
    AppDetail {
        objectName: "store:dettaglio"
        anchors.fill: parent; z: 10
        visible: app.detailId !== ""
        info: visible ? (store.revision, catalog.total, catalog.get(app.detailId)) : ({})
        store: store
        catalog: catalog
        onClosed: app.detailId = ""
    }
}
