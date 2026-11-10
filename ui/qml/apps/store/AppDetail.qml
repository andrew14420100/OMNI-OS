import QtQuick
import OmniDesign
import OmniApps

// Scheda di un'app: descrizione, informazioni e PERMESSI letti da Flatpak (metadati della
// sorgente prima dell'installazione, permessi effettivi dopo). Installazione e rimozione
// solo con il clic dell'utente; la rimozione chiede conferma.
Rectangle {
    id: d
    property var info: ({})
    property var store: null
    property var catalog: null
    property var perms: []
    property string permsState: ""      // "", "loading", "ok", "error"
    property int permsJob: -1
    property bool confirmRemove: false
    signal closed()
    color: Theme.dark ? "#0F1424" : "#F3F5FA"
    readonly property var busy: info.appId && store ? store.busy[info.appId] : null
    onInfoChanged: if (visible && info.appId && info.appId !== permsFor) loadPerms()
    onVisibleChanged: if (!visible) { permsFor = ""; confirmRemove = false }
    property string permsFor: ""
    MouseArea { anchors.fill: parent }   // blocca i clic verso la pagina sottostante

    function loadPerms() {
        permsFor = info.appId; perms = []; permsState = "loading"
        if (info.installed) permsJob = omniSystem.run("flatpak", ["info", "--show-permissions", info.appId], 30000)
        else if (info.remote && info.ref) permsJob = omniSystem.run("flatpak", ["remote-info", "--show-metadata", info.remote, info.ref], 60000)
        else permsState = "error"
    }
    Connections {
        target: omniSystem
        function onFinished(id, code, out, err) { if (id !== d.permsJob) return; d.permsJob = -1
            if (code !== 0) { d.permsState = "error"; return } d.perms = d.parsePerms(out); d.permsState = "ok" }
    }
    function parsePerms(text) {
        const out = [], seen = {}
        let section = ""
        const add = (t, risk) => { if (!seen[t]) { seen[t] = 1; out.push({ text: t, risk: !!risk }) } }
        const fs = { "host": [qsTr("Tutti i file del computer"), true], "host-os": [qsTr("File di sistema"), true], "host-etc": [qsTr("Configurazione di sistema"), true],
                     "home": [qsTr("Tutta la tua cartella personale"), true], "xdg-download": [qsTr("Cartella Download"), false], "xdg-documents": [qsTr("Cartella Documenti"), false],
                     "xdg-pictures": [qsTr("Cartella Immagini"), false], "xdg-music": [qsTr("Cartella Musica"), false], "xdg-videos": [qsTr("Cartella Video"), false], "xdg-desktop": [qsTr("Cartella Desktop"), false] }
        text.split("\n").forEach(line => {
            line = line.trim()
            const sec = /^\[(.+)\]$/.exec(line); if (sec) { section = sec[1]; return }
            const kv = /^([^=]+)=(.*)$/.exec(line); if (!kv) return
            const key = kv[1], vals = kv[2].split(";").filter(x => x)
            if (section === "Context") vals.forEach(v => {
                const neg = v.startsWith("!"); if (neg) return
                if (key === "shared" && v === "network") add(qsTr("Accesso a Internet"))
                else if (key === "sockets") {
                    if (v === "x11") add(qsTr("Finestre X11 (isolamento ridotto)"), true)
                    else if (v === "pulseaudio") add(qsTr("Audio e microfono"))
                    else if (v === "cups") add(qsTr("Stampanti"))
                    else if (v === "ssh-auth") add(qsTr("Chiavi SSH"), true)
                    else if (v === "pcsc") add(qsTr("Lettori di smart card"))
                    else if (v === "session-bus" || v === "system-bus") add(qsTr("Accesso completo ai servizi del sistema (D-Bus)"), true)
                } else if (key === "devices") {
                    if (v === "dri") add(qsTr("Accelerazione grafica"))
                    else if (v === "all") add(qsTr("Tutti i dispositivi (webcam, USB, controller…)"), true)
                    else if (v === "input") add(qsTr("Dispositivi di input"))
                    else if (v === "kvm") add(qsTr("Virtualizzazione"))
                } else if (key === "features" && v === "bluetooth") add(qsTr("Bluetooth"))
                else if (key === "filesystems") {
                    const ro = v.endsWith(":ro"), base = v.replace(/:(ro|rw|create)$/, "")
                    const m = fs[base.split("/")[0]]
                    const label = m ? m[0] + (base.indexOf("/") > 0 ? " (" + base.slice(base.indexOf("/") + 1) + ")" : "") : qsTr("Cartella %1").arg(base)
                    add(label + (ro ? qsTr(" — sola lettura") : ""), m ? m[1] && !ro : !ro && !base.startsWith("xdg-"))
                }
            })
            else if (section === "Session Bus Policy" && kv[2] === "talk") {
                if (key === "org.freedesktop.Notifications") add(qsTr("Notifiche"))
                else if (key === "org.freedesktop.secrets") add(qsTr("Portachiavi delle password"), true)
                else if (key === "org.freedesktop.Flatpak") add(qsTr("Avvio di comandi fuori dall'isolamento"), true)
            }
        })
        if (!out.length) add(qsTr("Nessun permesso speciale: l'app funziona isolata e chiede l'accesso ai file quando serve"))
        return out
    }

    Flickable {
        anchors.fill: parent; contentHeight: col.height + 48; clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            x: 32; y: 24; width: d.width - 64; spacing: 16
            OmniButton { objectName: "store:indietro"; text: qsTr("‹ Indietro"); ghost: true; onClicked: d.closed() }
            Row {
                spacing: 20; width: parent.width
                Item { width: 96; height: 96
                    Image { id: big; anchors.fill: parent; sourceSize: Qt.size(192, 192); source: d.info.icon ? "file://" + d.info.icon : ""; fillMode: Image.PreserveAspectFit }
                    Rectangle { visible: big.status !== Image.Ready; anchors.fill: parent; radius: 22; color: Theme.accentSoft
                        Text { anchors.centerIn: parent; text: (d.info.name || "?").charAt(0).toUpperCase(); color: Theme.accent; font.pixelSize: 40; font.family: Theme.fontFamily } } }
                Column {
                    width: parent.width - 116 - actions.width; spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; text: d.info.name || ""; elide: Text.ElideRight; color: Theme.textPrimary; font.pixelSize: 26; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
                    Text { width: parent.width; text: d.info.summary || ""; wrapMode: Text.Wrap; color: Theme.textSecondary; font.pixelSize: 14; font.family: Theme.fontFamily }
                    Text { width: parent.width; text: [d.info.developer, d.info.remote ? qsTr("da %1").arg(d.info.remote) : ""].filter(x => x).join(" · "); color: Theme.textTertiary; font.pixelSize: 12; font.family: Theme.fontFamily }
                }
                Column {
                    id: actions
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                    OmniButton { objectName: "store:installa"; visible: !d.info.installed && !d.busy && !!d.info.inCatalog; primary: true; text: qsTr("Installa"); enabled: d.permsState === "ok"
                        onClicked: d.store.install(d.info) }
                    OmniButton { visible: !!d.info.installed && !d.busy; primary: true; text: qsTr("Apri"); onClicked: d.store.launch(d.info) }
                    OmniButton { visible: !!d.info.installed && !!d.info.updateAvailable && !d.busy; text: qsTr("Aggiorna"); onClicked: d.store.update(d.info) }
                    OmniButton { objectName: "store:rimuovi"; visible: !!d.info.installed && !d.busy && !d.confirmRemove; text: qsTr("Rimuovi"); onClicked: d.confirmRemove = true }
                    OmniButton { visible: !!d.busy; text: qsTr("Annulla"); ghost: true; onClicked: d.store.cancel(d.info.appId) }
                }
            }
            Row {
                visible: d.confirmRemove; spacing: 8
                StatusNote { width: 460; kind: 2; text: qsTr("Rimuovere %1? I documenti salvati nelle tue cartelle restano; le impostazioni dell'app restano in ~/.var/app.").arg(d.info.name || "") }
                OmniButton { objectName: "store:conferma-rimozione"; primary: true; text: qsTr("Rimuovi"); onClicked: { d.confirmRemove = false; d.store.uninstall(d.info) } }
                OmniButton { text: qsTr("Annulla"); ghost: true; onClicked: d.confirmRemove = false }
            }
            Column {
                visible: !!d.busy; width: parent.width; spacing: 6
                Text { text: d.busy ? d.busy.action + (d.busy.progress >= 0 ? " — " + Math.round(d.busy.progress * 100) + "%" : "…") : ""; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Rectangle { width: parent.width; height: 6; radius: 3; color: Theme.surfaceSunken
                    Rectangle { width: d.busy && d.busy.progress >= 0 ? parent.width * d.busy.progress : parent.width * 0.25; height: parent.height; radius: 3; color: Theme.accent
                        SequentialAnimation on x { running: !!d.busy && d.busy.progress < 0 && !Theme.reducedMotion; loops: Animation.Infinite
                            NumberAnimation { from: 0; to: col.width * 0.75; duration: 1200 } NumberAnimation { to: 0; duration: 1200 } } } }
                Text { width: parent.width; text: d.busy ? d.busy.text : ""; elide: Text.ElideRight; color: Theme.textTertiary; font.pixelSize: 11; font.family: Theme.fontFamily }
            }
            StatusNote { width: parent.width; text: d.store ? d.store.message : ""; kind: d.store ? d.store.messageKind : 0 }
            Rectangle {
                width: parent.width; height: permCol.height + 28; radius: 12; color: Theme.dark ? "#161D31" : "#FFFFFF"; border.color: Theme.outline
                Column {
                    id: permCol
                    x: 16; y: 14; width: parent.width - 32; spacing: 6
                    Text { text: d.info.installed ? qsTr("Permessi dell'app") : qsTr("Permessi richiesti (da leggere prima di installare)"); color: Theme.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
                    Text { visible: d.permsState === "loading"; text: qsTr("Lettura dei permessi da Flatpak…"); color: Theme.textTertiary; font.pixelSize: 13; font.family: Theme.fontFamily }
                    Text { visible: d.permsState === "error"; width: parent.width; wrapMode: Text.Wrap; text: qsTr("Permessi non leggibili (sorgente non raggiungibile?): l'installazione resta disattivata finché non è possibile mostrarli."); color: Theme.danger; font.pixelSize: 13; font.family: Theme.fontFamily }
                    Repeater { model: d.perms
                        delegate: Row { required property var modelData; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: modelData.risk ? Theme.danger : Theme.success }
                            Text { text: modelData.text; color: modelData.risk ? Theme.danger : Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily } } }
                }
            }
            Text { width: parent.width; visible: !!d.info.description; text: d.info.description || ""; wrapMode: Text.Wrap; color: Theme.textPrimary; font.pixelSize: 14; lineHeight: 1.3; font.family: Theme.fontFamily }
            Image { visible: status === Image.Ready; width: Math.min(parent.width, 900); height: status === Image.Ready ? width * implicitHeight / Math.max(1, implicitWidth) : 0
                source: d.visible && d.info.screenshot ? d.info.screenshot : ""; asynchronous: true; fillMode: Image.PreserveAspectFit; sourceSize.width: 1200 }
            Column {
                spacing: 4
                component Info: Text { color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily }
                Info { visible: !!d.info.version; text: qsTr("Versione: %1").arg(d.info.version) + (d.info.released ? " (" + Qt.formatDate(d.info.released, "dd/MM/yyyy") + ")" : "") }
                Info { visible: !!d.info.installedVersion; text: qsTr("Versione installata: %1").arg(d.info.installedVersion) + (d.info.installation ? " · " + (d.info.installation === "system" ? qsTr("per tutti gli utenti") : qsTr("solo per te")) : "") }
                Info { visible: !!d.info.license; text: qsTr("Licenza: %1").arg(d.info.license) }
                Info { visible: !!d.info.homepage; text: qsTr("Sito: %1").arg(d.info.homepage) }
                Info { text: qsTr("Identificativo: %1").arg(d.info.appId || "") }
            }
        }
    }
}
