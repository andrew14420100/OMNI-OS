import QtQuick
import QtTest
import OmniDesign

// Accessibilità del sistema di design (decisione 39, RF-10): contrasto WCAG e movimento ridotto,
// per entrambi i temi e per ogni colore d'accento.
TestCase {
    name: "Theme"
    function check(darkMode) {
        Theme.dark = darkMode
        const which = darkMode ? "scuro" : "chiaro"
        verify(Theme.contrast(Theme.textPrimary, Theme.background) >= 7, "testo principale su sfondo (" + which + ")")
        verify(Theme.contrast(Theme.textPrimary, Theme.surface) >= 7, "testo principale su superficie (" + which + ")")
        verify(Theme.contrast(Theme.textSecondary, Theme.surface) >= 4.5, "testo secondario su superficie (" + which + ")")
        verify(Theme.contrast(Theme.textSecondary, Theme.background) >= 4.5, "testo secondario su sfondo (" + which + ")")
        verify(Theme.contrast(Theme.textTertiary, Theme.surface) >= 4.5, "testo terziario su superficie (" + which + ")")
        verify(Theme.contrast(Theme.prototype, Theme.surface) >= 4.5, "etichetta Prototipo (" + which + ")")
        for (let i = 0; i < Theme.accents.length; ++i) {
            Theme.accentIndex = i
            const n = Theme.accents[i].name
            verify(Theme.contrast(Theme.textOnAccent, Theme.accent) >= 4.5, "testo su accento " + n + " (" + which + "): " + Theme.contrast(Theme.textOnAccent, Theme.accent).toFixed(2))
            verify(Theme.contrast(Theme.accent, Theme.surface) >= 3, "accento " + n + " su superficie (" + which + ")")
        }
        Theme.accentIndex = 0
    }
    function test_contrastDark() { check(true) }
    function test_contrastLight() { check(false) }
    function test_textOnAccentIsDefined() {
        // regressione: una proprietà chiamata "onAccent" veniva interpretata come gestore di segnale
        Theme.dark = true; compare(String(Theme.textOnAccent), "#06121a")
        Theme.dark = false; compare(String(Theme.textOnAccent), "#ffffff")
        Theme.dark = true
    }
    function test_contrastFormula() {
        compare(Math.round(Theme.contrast("#000000", "#FFFFFF") * 10) / 10, 21)
        compare(Theme.contrast("#777777", "#777777"), 1)
    }
    function test_reducedMotion() {
        Theme.reducedMotion = false
        verify(Theme.durationNormal > 0); verify(Theme.ambientMotion)
        Theme.reducedMotion = true
        compare(Theme.durationFast, 0); compare(Theme.durationNormal, 0); compare(Theme.durationSlow, 0)
        compare(Theme.durationEmphasis, 0); compare(Theme.staggerStep, 0); verify(!Theme.ambientMotion)
        Theme.reducedMotion = false
    }
    function test_lowPowerStopsAmbientOnly() {
        Theme.lowPower = true
        verify(!Theme.ambientMotion); verify(Theme.durationNormal > 0)
        Theme.lowPower = false
        verify(Theme.ambientMotion)
    }
    function cleanupTestCase() { Theme.dark = true; Theme.accentIndex = 0 }
}
