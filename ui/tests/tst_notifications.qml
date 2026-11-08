import QtQuick
import QtTest
import OmniShell

// Archivio delle notifiche del prototipo: ordine, rimozione, Non disturbare, gruppi, tempo relativo.
TestCase {
    name: "NotificationStore"
    NotificationStore { id: store }
    SignalSpy { id: posted; target: store; signalName: "posted" }
    function init() { store.clear(); store.doNotDisturb = false; posted.clear() }
    function test_addNewestFirst() {
        store.add("A", "uno", "x"); store.add("B", "due", "y")
        compare(store.count, 2); compare(store.model.get(0).title, "due")
    }
    function test_dismissById() {
        const a = store.add("A", "uno", ""); const b = store.add("B", "due", "")
        verify(store.dismiss(a)); compare(store.count, 1); compare(store.model.get(0).nid, b)
        verify(!store.dismiss(9999))
    }
    function test_clear() { store.add("A", "uno", ""); store.clear(); compare(store.count, 0) }
    function test_doNotDisturbKeepsButSilences() {
        store.doNotDisturb = true
        store.add("A", "silenziosa", "")
        compare(store.count, 1); compare(posted.count, 0)
        store.doNotDisturb = false
        store.add("B", "visibile", "")
        compare(posted.count, 1); compare(posted.signalArguments[0][1], "B")
    }
    function test_groupsByAppNewestFirst() {
        store.add("Update", "u1", "", "", true, 30); store.add("Security", "s1", "", "", true, 20); store.add("Update", "u2", "", "", true, 10)
        const g = store.groups()
        compare(g.length, 2); compare(g[0].app, "Update"); compare(g[0].items.length, 2)
        compare(g[0].items[0].title, "u2"); compare(g[1].app, "Security")
    }
    function test_dismissApp() {
        store.add("Update", "u1", ""); store.add("Security", "s1", ""); store.add("Update", "u2", "")
        store.dismissApp("Update"); compare(store.count, 1); compare(store.model.get(0).app, "Security")
    }
    function test_revisionChanges() { const r = store.revision; store.add("A", "x", ""); verify(store.revision > r) }
    function test_relativeTime() {
        const now = Date.now()
        compare(store.relative(now, now), "adesso")
        compare(store.relative(now - 5 * 60000, now), "5 min fa")
        compare(store.relative(now - 125 * 60000, now), "2 h fa")
    }
}
