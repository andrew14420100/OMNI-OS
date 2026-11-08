import QtQuick
import QtTest
import OmniDesign

// Componenti commutabili e cursore: mouse e tastiera.
Item {
    width: 600; height: 400
    OmniToggleTile { id: tile; x: 10; y: 10; title: "Prova" }
    OmniSlider { id: slider; x: 10; y: 120; width: 400; value: 0.5 }
    SignalSpy { id: toggled; target: tile; signalName: "toggled" }
    TestCase {
        name: "Components"
        when: windowShown
        function init() { toggled.clear() }
        function test_toggleByMouse() { tile.checked = false; mouseClick(tile); verify(tile.checked); compare(toggled.count, 1) }
        function test_toggleByKeyboard() { tile.checked = false; tile.forceActiveFocus(); keyClick(Qt.Key_Space); verify(tile.checked) }
        function test_sliderKeyboardBounded() {
            slider.value = 0.98; slider.forceActiveFocus(); keyClick(Qt.Key_Right); compare(slider.value, 1)
            keyClick(Qt.Key_Right); compare(slider.value, 1)
            slider.value = 0.02; keyClick(Qt.Key_Left); compare(slider.value, 0)
        }
    }
}
