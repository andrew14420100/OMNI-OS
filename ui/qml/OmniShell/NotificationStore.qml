import QtQuick

// Archivio delle notifiche del prototipo.
// NON è collegato al servizio di notifiche della sessione reale (org.freedesktop.Notifications):
// riceve solo notifiche interne al prototipo. "Non disturbare" non elimina le notifiche,
// sopprime solo l'avviso temporaneo a comparsa.
QtObject {
    id: store
    property bool doNotDisturb: false
    property int nextId: 1
    readonly property ListModel model: ListModel {}
    readonly property int count: model.count
    signal posted(string title, string body)

    // silent: true = aggiunta senza avviso a comparsa (es. notifiche dimostrative all'avvio)
    function add(app, title, body, icon, silent) {
        const id = nextId++
        model.insert(0, { nid: id, app: app, title: title, body: body, icon: icon || "bell",
                          time: Qt.formatTime(new Date(), "hh:mm") })
        if (!doNotDisturb && !silent) posted(title, body)
        return id
    }
    function indexOf(id) {
        for (let i = 0; i < model.count; ++i) if (model.get(i).nid === id) return i
        return -1
    }
    function dismiss(id) { const i = indexOf(id); if (i >= 0) model.remove(i); return i >= 0 }
    function clear() { model.clear() }
}
