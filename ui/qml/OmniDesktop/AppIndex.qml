import QtQuick

// Indice delle applicazioni installate (dal modello C++ dei file .desktop): ricerca per id,
// per AppId delle finestre (es. "org.kde.dolphin") e per testo. Ricostruito solo quando
// cambia il modello: nessun ciclo sull'elenco a ogni fotogramma.
QtObject {
    id: root
    property var model: null
    property var byId: ({})
    property var all: []
    // elenco di Start: senza i doppioni KDE delle app OMNI installate (le app KDE restano
    // installate e si trovano con la ricerca, dopo quelle OMNI)
    property var listed: []
    readonly property var replacedBy: ({
        "systemsettings.desktop": "org.omnios.Settings.desktop", "org.kde.systemsettings.desktop": "org.omnios.Settings.desktop",
        "org.kde.discover.desktop": "org.omnios.Store.desktop", "org.kde.plasma-systemmonitor.desktop": "org.omnios.TaskManager.desktop" })
    function isReplaced(e) { const r = replacedBy[e.desktopId]; return !!r && !!byId[r] }
    function rebuild() {
        const m = {}, list = []
        if (model) for (let i = 0; i < model.count; ++i) {
            const e = model.get(i)
            m[e.desktopId] = e
            m[e.desktopId.replace(/\.desktop$/, "").toLowerCase()] = e
            list.push(e)
        }
        list.sort((a, b) => a.name.localeCompare(b.name, Qt.locale().name))
        byId = m
        all = list
        listed = list.filter(e => !isReplaced(e))
    }
    // AppId di una finestra o URL di launcher ("applications:org.kde.dolphin.desktop")
    function find(appIdOrUrl) {
        if (!appIdOrUrl) return null
        let k = String(appIdOrUrl).replace(/^applications:/, "").replace(/^file:\/\/.*\//, "")
        return byId[k] || byId[k.replace(/\.desktop$/, "").toLowerCase()] || null
    }
    function search(text, limit) {
        const q = String(text || "").trim().toLowerCase()
        if (!q) return []
        const starts = [], contains = []
        for (const e of all) {
            const n = e.name.toLowerCase()
            const hay = n + " " + (e.comment || "").toLowerCase() + " " + e.desktopId.toLowerCase()
            if (n.startsWith(q) || n.split(" ").some(w => w.startsWith(q))) starts.push(e)
            else if (hay.indexOf(q) >= 0) contains.push(e)
        }
        const rank = l => l.filter(e => !isReplaced(e)).concat(l.filter(e => isReplaced(e)))
        return rank(starts).concat(rank(contains)).slice(0, limit || 8)
    }
    property Connections _c: Connections { target: root.model; ignoreUnknownSignals: true; function onCountChanged() { root.rebuild() } }
    Component.onCompleted: rebuild()
    onModelChanged: rebuild()
}
