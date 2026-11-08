import QtQuick
import QtTest
import OmniShell

// Archivio delle notifiche del prototipo.
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
        compare(posted.count, 1)
    }
}
