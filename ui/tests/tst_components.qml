import QtQuick
import QtTest
import OmniDesign

// Componenti interattivi: mouse e tastiera.
Item {
    width: 700; height: 500
    OmniToggleTile { id: tile; x: 10; y: 10; title: "Prova" }
    OmniSlider { id: slider; x: 10; y: 100; width: 400; value: 0.5 }
    OmniSwitch { id: sw; x: 10; y: 170; label: "Interruttore" }
    OmniSegmented { id: seg; x: 10; y: 220; options: [{ text: "A" }, { text: "B" }, { text: "C" }]; onActivated: (i) => currentIndex = i }
    OmniChip { id: chip; x: 10; y: 280; text: "Categoria" }
    Reveal { id: reveal; x: 300; y: 280; width: 50; height: 50; Rectangle { width: 50; height: 50 } }
    SignalSpy { id: toggled; target: tile; signalName: "toggled" }
    SignalSpy { id: chipClicked; target: chip; signalName: "clicked" }
    TestCase {
        name: "Components"
        when: windowShown
        function init() { toggled.clear(); chipClicked.clear() }
        function test_toggleByMouse() { tile.checked = false; mouseClick(tile); verify(tile.checked); compare(toggled.count, 1) }
        function test_toggleByKeyboard() { tile.checked = false; tile.forceActiveFocus(); keyClick(Qt.Key_Space); verify(tile.checked) }
        function test_sliderKeyboardBounded() {
            slider.value = 0.98; slider.forceActiveFocus(); keyClick(Qt.Key_Right); compare(slider.value, 1)
            keyClick(Qt.Key_Right); compare(slider.value, 1)
            slider.value = 0.02; keyClick(Qt.Key_Left); compare(slider.value, 0)
        }
        function test_sliderMouse() { mouseClick(slider, 3, slider.height / 2); verify(slider.value < 0.05) }
        function test_switch() { sw.checked = false; sw.forceActiveFocus(); keyClick(Qt.Key_Space); verify(sw.checked); mouseClick(sw); verify(!sw.checked) }
        function test_segmentedKeyboard() { seg.currentIndex = 0; seg.forceActiveFocus(); keyClick(Qt.Key_Right); compare(seg.currentIndex, 1); keyClick(Qt.Key_Right); keyClick(Qt.Key_Right); compare(seg.currentIndex, 2); keyClick(Qt.Key_Left); compare(seg.currentIndex, 1) }
        function test_chip() { chip.forceActiveFocus(); keyClick(Qt.Key_Return); mouseClick(chip); compare(chipClicked.count, 2) }
        function test_revealWithReducedMotion() { Theme.reducedMotion = true; reveal.shown = false; reveal.shown = true; compare(reveal.children[0].opacity, 1); Theme.reducedMotion = false }
    }
}
