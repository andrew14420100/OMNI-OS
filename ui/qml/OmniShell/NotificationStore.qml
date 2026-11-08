import QtQuick

// Archivio delle notifiche del prototipo.
// NON è collegato al servizio di notifiche della sessione reale (org.freedesktop.Notifications):
// riceve solo notifiche interne al prototipo. "Non disturbare" non elimina le notifiche,
// sopprime solo l'avviso temporaneo a comparsa.
QtObject {
    id: store
    property bool doNotDisturb: false
    property int nextId: 1
    property int revision: 0                    // cambia a ogni modifica (per i raggruppamenti)
    readonly property ListModel model: ListModel {}
    readonly property int count: model.count
    signal posted(int nid, string app, string title, string body)

    // silent: true = aggiunta senza avviso a comparsa (es. notifiche dimostrative all'avvio)
    // minutesAgo: età simulata della notifica dimostrativa (0 = adesso)
    function add(app, title, body, icon, silent, minutesAgo) {
        const id = nextId++
        const t = Date.now() - (minutesAgo || 0) * 60000
        model.insert(0, { nid: id, app: app, title: title, body: body, icon: icon || "bell", stamp: t,
                          time: Qt.formatTime(new Date(t), "hh:mm") })
        revision++
        if (!doNotDisturb && !silent) posted(id, app, title, body)
        return id
    }
    function indexOf(id) {
        for (let i = 0; i < model.count; ++i) if (model.get(i).nid === id) return i
        return -1
    }
    function dismiss(id) { const i = indexOf(id); if (i >= 0) { model.remove(i); revision++ } return i >= 0 }
    function dismissApp(app) {
        for (let i = model.count - 1; i >= 0; --i) if (model.get(i).app === app) model.remove(i)
        revision++
    }
    function clear() { model.clear(); revision++ }

    // Raggruppamento per applicazione, gruppi ordinati per notifica più recente.
    function groups() {
        const order = [], byApp = {}
        for (let i = 0; i < model.count; ++i) {
            const n = model.get(i)
            if (!byApp[n.app]) { byApp[n.app] = []; order.push(n.app) }
            byApp[n.app].push({ nid: n.nid, app: n.app, title: n.title, body: n.body, icon: n.icon, stamp: n.stamp, time: n.time })
        }
        return order.map(a => ({ app: a, items: byApp[a] }))
    }
    // Tempo relativo in italiano ("adesso", "5 min fa", "2 h fa").
    function relative(stamp, now) {
        const m = Math.max(0, Math.floor(((now || Date.now()) - stamp) / 60000))
        if (m < 1) return qsTr("adesso")
        if (m < 60) return qsTr("%1 min fa").arg(m)
        return qsTr("%1 h fa").arg(Math.floor(m / 60))
    }
}
