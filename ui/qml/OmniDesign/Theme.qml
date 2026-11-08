pragma Singleton
import QtQuick

// Sistema di design OMNI (prototipo anticipato, non M4).
// Unica fonte per colori, spaziature, raggi, tipografia e movimento.
// Decisioni approvate di riferimento: 5 (identità grafica), 21 (personalizzazione,
// temi chiaro/scuro), 39 (accessibilità indipendente dall'AI: contrasto, movimento ridotto).
QtObject {
    id: theme

    // --- Stato modificabile dall'utente (Impostazioni rapide) ---
    property bool dark: true
    property bool reducedMotion: false

    // --- Palette di base (originale OMNI) ---
    readonly property color auroraCyan: "#38D3F2"
    readonly property color auroraViolet: "#8B5CF6"
    readonly property color auroraMagenta: "#E255C9"

    // --- Colori semantici ---
    readonly property color background:   dark ? "#090D18" : "#EEF1F8"
    readonly property color surface:      dark ? "#141A2B" : "#FFFFFF"
    readonly property color surfaceRaised: dark ? "#1C2438" : "#F7F8FC"
    readonly property color surfaceGlass: dark ? Qt.rgba(0.08, 0.10, 0.17, 0.78) : Qt.rgba(1, 1, 1, 0.80)
    readonly property color outline:      dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0.06, 0.09, 0.19, 0.12)
    readonly property color textPrimary:  dark ? "#F2F5FC" : "#0E1424"
    readonly property color textSecondary: dark ? "#A9B3CA" : "#4A5470"
    readonly property color accent:       dark ? "#5EDCF7" : "#0A7EA4"
    readonly property color onAccent:     dark ? "#04151B" : "#FFFFFF"
    readonly property color accentSoft:   dark ? Qt.rgba(0.37, 0.86, 0.97, 0.16) : Qt.rgba(0.04, 0.49, 0.64, 0.12)
    readonly property color danger:       dark ? "#FF7A8A" : "#C2273B"
    readonly property color prototype:    dark ? "#FFB547" : "#8A5300"
    readonly property color prototypeSoft: dark ? Qt.rgba(1, 0.71, 0.28, 0.14) : Qt.rgba(0.54, 0.33, 0, 0.10)
    readonly property color scrim:        Qt.rgba(0.02, 0.03, 0.07, dark ? 0.55 : 0.30)

    // --- Spaziature (griglia di 4 px) e raggi ---
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32
    readonly property int radiusSmall: 10
    readonly property int radius: 16
    readonly property int radiusLarge: 24

    // --- Tipografia ---
    readonly property string fontFamily: "Inter"
    readonly property int fontCaption: 12
    readonly property int fontBody: 14
    readonly property int fontTitle: 18
    readonly property int fontDisplay: 34

    // --- Movimento (azzerato con "movimento ridotto") ---
    readonly property int durationFast: reducedMotion ? 0 : 140
    readonly property int durationNormal: reducedMotion ? 0 : 240
    readonly property int durationSlow: reducedMotion ? 0 : 420
    readonly property int easing: Easing.OutCubic
    readonly property int easingEmphasized: Easing.OutBack

    // --- Accessibilità: rapporto di contrasto WCAG 2.x fra due colori ---
    function luminance(cIn) {
        const c = Qt.lighter(cIn, 1.0)   // accetta sia colori sia stringhe "#RRGGBB"
        function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }
    function contrast(a, b) {
        const l1 = luminance(a), l2 = luminance(b)
        return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
    }
}
