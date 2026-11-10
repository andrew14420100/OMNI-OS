import QtQuick
import OmniDesign
import OmniApps
import OmniDesktop
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("App")
    subtitle: qsTr("App installate, app predefinite per tipo di file e avvio automatico.")
    property AppIndex index: AppIndex { model: appModel }
    property var defaults: ({})
    property var autostart: []
    property string note: ""
    readonly property var kinds: [
        { mime: "x-scheme-handler/https", label: qsTr("Browser web"), icon: "globe" },
        { mime: "x-scheme-handler/mailto", label: qsTr("Posta elettronica"), icon: "bell" },
        { mime: "inode/directory", label: qsTr("Gestore dei file"), icon: "folder" },
        { mime: "text/plain", label: qsTr("Testo"), icon: "code" },
        { mime: "image/png", label: qsTr("Immagini"), icon: "image" },
        { mime: "application/pdf", label: qsTr("Documenti PDF"), icon: "briefcase" },
        { mime: "video/mp4", label: qsTr("Video"), icon: "display" },
        { mime: "audio/mpeg", label: qsTr("Musica"), icon: "music" }
    ]
    function reload() {
        for (const k of kinds) Sys.run("xdg-mime", ["query", "default", k.mime], (c, o) => { const d = Object.assign({}, page.defaults); d[k.mime] = o.trim(); page.defaults = d })
        autostart = omniSystem.autostartEntries()
    }
    function candidates(mime) {
        const base = mime.split("/")[0] + "/*"
        return index.all.filter(e => (e.mimeTypes || []).some(m => m === mime || (mime.indexOf("x-scheme-handler/http") === 0 && m === "x-scheme-handler/http")))
    }
    Component.onCompleted: reload()
    SectionTitle { text: qsTr("App predefinite") }
    Repeater {
        model: page.kinds
        delegate: SettingCard {
            id: k
            required property var modelData
            readonly property var cur: page.index.find(page.defaults[modelData.mime] || "")
            objectName: "predefinita:" + modelData.mime
            icon: modelData.icon; title: modelData.label; subtitle: k.cur ? k.cur.name : (page.defaults[modelData.mime] ? page.defaults[modelData.mime] : qsTr("nessuna"))
            Flow { width: 380; spacing: 6
                Repeater { model: page.candidates(k.modelData.mime).slice(0, 5)
                    delegate: OmniChip { required property var modelData; text: modelData.name; checked: k.cur && k.cur.desktopId === modelData.desktopId
                        onClicked: Sys.run("xdg-mime", ["default", modelData.desktopId, k.modelData.mime].concat(k.modelData.mime === "x-scheme-handler/https" ? [] : []), (c, o, e) => {
                            if (k.modelData.mime === "x-scheme-handler/https") Sys.run("xdg-mime", ["default", modelData.desktopId, "x-scheme-handler/http", "text/html"])
                            page.note = c === 0 ? "" : e; page.reload() }) } } }
        }
    }
    SectionTitle { text: qsTr("Avvio automatico") }
    Repeater {
        model: page.autostart
        delegate: SettingCard { required property var modelData; icon: "restart"; title: modelData.name || modelData.id; subtitle: modelData.comment || modelData.id
            OmniSwitch { checked: modelData.enabled; onToggled: { if (!omniSystem.setAutostart(modelData.id, checked)) page.note = qsTr("Impossibile modificare %1").arg(modelData.id); page.reload() } } }
    }
    SectionTitle { text: qsTr("App installate") + " (" + page.index.all.length + ")" }
    Repeater {
        model: page.index.all
        delegate: SettingCard {
            required property var modelData
            title: modelData.name; subtitle: modelData.flatpakId ? qsTr("Flatpak · %1").arg(modelData.flatpakId) : qsTr("Sistema (immagine OMNI OS, aggiornata con il sistema)")
            Row { spacing: 6
                AppIcon { size: 24; appName: modelData.name; desktopId: modelData.desktopId; iconName: modelData.iconName; categories: modelData.categories }
                OmniButton { text: qsTr("Apri"); ghost: true; onClicked: omniLauncher.launch(modelData.filePath) }
                OmniButton { visible: !!modelData.flatpakId; text: qsTr("Gestisci nello Store"); onClicked: Sys.run("gio", ["launch", "/usr/share/applications/org.omnios.Store.desktop"]) } }
        }
    }
    StatusNote { text: page.note; kind: 2 }
}
