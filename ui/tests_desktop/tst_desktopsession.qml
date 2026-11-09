import QtQuick
import QtTest
import OmniDesign
import OmniDesktop

// Componenti della sessione OMNI con gli oggetti C++ reali come contesto.
Item {
    id: root
    width: 1600; height: 1000

    QtObject {
        id: fakeSession
        property string popup: ""
        property date now: new Date(2026, 10, 9, 14, 30)
        property var services: QtObject { property var tasks: null; property var audio: null; property var network: null; property var bluetooth: null }
        property var appIndex: index
        property var startPins: ["org.kde.konsole.desktop", "inesistente.desktop"]
        property var menuItems: []
        property string networkIcon: "ethernet"
        property string networkLabel: "Connessione cablata"
        property bool networkConnected: true
        property int availableHeight: 950
        property var launched: []
        property int toggles: 0
        property bool darkSet: false
        function toggle(p) { popup = popup === p ? "" : p; toggles++ }
        function close() { popup = "" }
        function openStart(f) { popup = "start" }
        function launchEntry(e) { launched = launched.concat([e.desktopId]) }
        function launchById(id) {}
        function noteLaunch(id) {}
        function setDark(d) { darkSet = true }
        function setReducedMotion(r) {}
        function openAppMenu(e, it) {}
        function openTaskMenu(r, it, m) {}
    }
    AppIndex { id: index; model: appModel }

    Component { id: barC; Taskbar { width: 1600; height: 48; session: fakeSession } }
    Component { id: startC; StartMenu { session: fakeSession; shown: true } }
    Component { id: quickC; QuickPanel { session: fakeSession; shown: true } }
    Component { id: notesC; NotificationPanel { session: fakeSession; shown: true } }
    Component { id: toastC; ToastStack {} }
    Component { id: menuC; ContextMenu { session: fakeSession } }

    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        const kids = item.children || []
        for (let i = 0; i < kids.length; ++i) { const r = find(kids[i], name); if (r) return r }
        return null
    }

    TestCase {
        name: "SessioneOmni"
        when: windowShown

        function init() { fakeSession.popup = ""; fakeSession.launched = []; notificationServer.clearAll(); notificationServer.doNotDisturb = false }

        function test_appIndexTrovaPerIdFinestraELauncher() {
            verify(index.all.length >= 3)
            compare(index.find("org.kde.konsole").name, "Konsole")
            compare(index.find("applications:org.kde.dolphin.desktop").name, "Dolphin")
            compare(index.find("org.mozilla.firefox").name, "Firefox")
            compare(index.find("non.esiste"), null)
        }
        function test_ricercaPerNomeEDescrizione() {
            compare(index.search("kon")[0].desktopId, "org.kde.konsole.desktop")
            compare(index.search("termin")[0].desktopId, "org.kde.konsole.desktop")   // dal commento
            compare(index.search("").length, 0)
        }
        function test_barraStartEOrologio() {
            const bar = createTemporaryObject(barC, root)
            const start = find(bar, "bar:start")
            verify(start)
            mouseClick(start)
            compare(fakeSession.popup, "start")
            mouseClick(find(bar, "bar:clock"))
            compare(fakeSession.popup, "notifications")
            mouseClick(find(bar, "bar:status"))
            compare(fakeSession.popup, "quick")
        }
        function test_startRicercaEInvioAvviaLaPrimaApp() {
            const s = createTemporaryObject(startC, root)
            const field = find(s, "start:search")
            field.text = "dol"
            tryCompare(s.results, "length", 1)
            field.accepted()
            compare(fakeSession.launched[0], "org.kde.dolphin.desktop")
        }
        function test_startMostraSoloLeAppInstallateAggiunte() {
            const s = createTemporaryObject(startC, root)
            compare(s.pinnedEntries.length, 1)                 // "inesistente.desktop" ignorata
            verify(find(s, "start:pin:org.kde.konsole.desktop"))
        }
        function test_menuEnergiaHaTutteLeAzioni() {
            const s = createTemporaryObject(startC, root)
            mouseClick(find(s, "start:power"))
            verify(s.powerOpen)
            for (const a of ["lock", "logout", "suspend", "reboot", "shutdown"]) verify(find(s, "power:" + a), a)
        }
        function test_nonDisturbareRealeDalleImpostazioniRapide() {
            const q = createTemporaryObject(quickC, root)
            const dnd = find(q, "qs:dnd")
            dnd.toggled()
            verify(notificationServer.doNotDisturb)
            dnd.toggled()
            verify(!notificationServer.doNotDisturb)
        }
        function test_serviziMancantiSonoDichiarati() {
            const q = createTemporaryObject(quickC, root)
            verify(!find(q, "qs:bluetooth").available)
            compare(find(q, "qs:bluetooth").sub, "Non disponibile")
            verify(!find(q, "qs:volume").available)
            verify(!find(q, "qs:brightness").available)        // nessun servizio di luminosità nella prova
            verify(find(q, "qs:theme"))
            find(q, "qs:theme").toggled()
            verify(fakeSession.darkSet)
        }
        function test_notificheRealiCronologiaENonDisturbare() {
            const toast = createTemporaryObject(toastC, root)
            const id1 = notificationServer.postLocal("Prima", "testo", 1)
            compare(notificationServer.count, 1)
            compare(toast.ids.length, 1)
            notificationServer.doNotDisturb = true
            notificationServer.postLocal("Silenziosa", "", 1)
            compare(notificationServer.count, 2)
            compare(toast.ids.length, 1)                       // nessun fumetto con "Non disturbare"
            notificationServer.postLocal("Urgente", "", 2)
            compare(toast.ids.length, 2)                       // le urgenti passano
            notificationServer.dismiss(id1)
            compare(notificationServer.count, 2)
            notificationServer.clearAll()
            compare(notificationServer.count, 0)
        }
        function test_centroNotificheMostraLeNotifiche() {
            notificationServer.postLocal("Messaggio di prova", "corpo", 1)
            const p = createTemporaryObject(notesC, root)
            waitForRendering(p)
            verify(notificationServer.count === 1)
            verify(find(p, "notes:clear").enabled)
        }
        function test_menuContestualeEsegueLAzione() {
            let fatto = false
            fakeSession.menuItems = [{ label: "Prova", icon: "pin", act: () => { fatto = true } }]
            fakeSession.popup = "menu"
            const m = createTemporaryObject(menuC, root)
            mouseClick(find(m, "menu:0"))
            verify(fatto)
            compare(fakeSession.popup, "")
        }
    }
}
