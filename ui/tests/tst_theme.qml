import QtQuick
import QtTest
import OmniDesign

// Accessibilità del sistema di design (decisione 39, RF-10): contrasto WCAG AA e movimento ridotto.
TestCase {
    name: "Theme"
    function check(darkMode) {
        Theme.dark = darkMode
        const which = darkMode ? "scuro" : "chiaro"
        verify(Theme.contrast(Theme.textPrimary, Theme.background) >= 7, "testo principale su sfondo (" + which + ")")
        verify(Theme.contrast(Theme.textPrimary, Theme.surface) >= 7, "testo principale su superficie (" + which + ")")
        verify(Theme.contrast(Theme.textSecondary, Theme.surface) >= 4.5, "testo secondario su superficie (" + which + ")")
        verify(Theme.contrast(Theme.textSecondary, Theme.background) >= 4.5, "testo secondario su sfondo (" + which + ")")
        verify(Theme.contrast(Theme.onAccent, Theme.accent) >= 4.5, "testo su accento (" + which + ")")
        verify(Theme.contrast(Theme.prototype, Theme.surface) >= 4.5, "etichetta Prototipo (" + which + ")")
    }
    function test_contrastDark() { check(true) }
    function test_contrastLight() { check(false) }
    function test_contrastFormula() {
        compare(Math.round(Theme.contrast("#000000", "#FFFFFF") * 10) / 10, 21)
        compare(Theme.contrast("#777777", "#777777"), 1)
    }
    function test_reducedMotion() {
        Theme.reducedMotion = false
        verify(Theme.durationNormal > 0)
        Theme.reducedMotion = true
        compare(Theme.durationFast, 0); compare(Theme.durationNormal, 0); compare(Theme.durationSlow, 0)
        Theme.reducedMotion = false
    }
    function cleanupTestCase() { Theme.dark = true }
}
