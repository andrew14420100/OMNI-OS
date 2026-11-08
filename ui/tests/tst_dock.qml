import QtQuick
import QtTest
import OmniDesign
import OmniShell

// Dock: ingrandimento vicino al puntatore, movimento ridotto, dimensione adattiva, attivazione.
Item {
    width: 1400; height: 300
    SessionState { id: session }
    Dock {
        id: dock; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        session: session; availableWidth: 1400
        items: [ { name: "Uno", desktopId: "uno", glyph: "files" }, { name: "Due", desktopId: "due", glyph: "terminal" }, { name: "Tre", desktopId: "tre", glyph: "browser" } ]
    }
    SignalSpy { id: act; target: dock; signalName: "activated" }
    SignalSpy { id: launch; target: dock; signalName: "launcherRequested" }
    TestCase {
        name: "Dock"
        when: windowShown
        function test_magnify() {
            dock.hovering = false; compare(dock.magnify(100), 1)
            dock.hovering = true; dock.pointerX = 100
            compare(dock.magnify(100), dock.maxScale)
            verify(dock.magnify(100 + dock.baseSize * 6) < 1.01)
            verify(dock.magnify(100 + dock.baseSize) < dock.maxScale && dock.magnify(100 + dock.baseSize) > 1)
            dock.hovering = false
        }
        function test_reducedMotionDisablesMagnify() {
            Theme.reducedMotion = true; dock.hovering = true; dock.pointerX = 100
            compare(dock.magnify(100), 1); compare(dock.maxScale, 1)
            Theme.reducedMotion = false; dock.hovering = false
        }
        function test_responsiveSize() {
            dock.availableWidth = 400; compare(dock.baseSize, 36)
            dock.availableWidth = 4000; compare(dock.baseSize, 52)
            dock.availableWidth = 1400
        }
        function test_keyboardActivation() {
            act.clear(); launch.clear()
            dock.forceActiveFocus()
            keyClick(Qt.Key_Tab)              // pulsante del launcher
            keyClick(Qt.Key_Return); compare(launch.count, 1)
            keyClick(Qt.Key_Tab)              // prima app
            keyClick(Qt.Key_Space); compare(act.count, 1); compare(act.signalArguments[0][0].name, "Uno")
        }
    }
}
