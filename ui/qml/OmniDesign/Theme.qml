pragma Singleton
import QtQuick

// Sistema di design OMNI v2 (prototipo anticipato, non M4).
// Unica fonte per palette, superfici, ombre, tipografia, spaziature e movimento.
// Decisioni approvate di riferimento: 5 (identità grafica), 21 (personalizzazione:
// temi chiaro/scuro, colore d'accento), 39 (accessibilità: contrasto, movimento ridotto).
QtObject {
    id: theme

    // --- Stato modificabile dall'utente (Impostazioni rapide) ---
    property bool dark: true
    property bool reducedMotion: false
    // Risparmio risorse: ferma le animazioni continue dello sfondo (hardware meno potente).
    property bool lowPower: false
    // Colore d'accento scelto (0 Aurora, 1 Iris, 2 Corallo, 3 Giada)
    property int accentIndex: 0

    // --- Palette d'accento: coppie pensate per entrambi i temi (contrasto verificato nei test) ---
    readonly property var accents: [
        { name: qsTr("Aurora"),  dark: "#5FE1F7", light: "#0B6F90", glow: "#38D3F2", pair: "#8B7CFF" },
        { name: qsTr("Iris"),    dark: "#AFA2FF", light: "#5B3FD6", glow: "#8B7CFF", pair: "#E06CFF" },
        { name: qsTr("Corallo"), dark: "#FF9E8A", light: "#B0391F", glow: "#FF7A66", pair: "#FFC15E" },
        { name: qsTr("Giada"),   dark: "#6EE7B7", light: "#0B7253", glow: "#34D399", pair: "#38D3F2" }
    ]
    readonly property var currentAccent: accents[Math.max(0, Math.min(accents.length - 1, accentIndex))]

    // --- Colori di marca (aurora) ---
    readonly property color auroraCyan: "#38D3F2"
    readonly property color auroraViolet: "#8B7CFF"
    readonly property color auroraMagenta: "#E255C9"
    readonly property color glow: currentAccent.glow
    readonly property color glowPair: currentAccent.pair

    // --- Colori semantici ---
    readonly property color background:    dark ? "#070A14" : "#EDF0F7"
    readonly property color backgroundAlt: dark ? "#0D1124" : "#E4E8F3"
    readonly property color surface:       dark ? "#121829" : "#FFFFFF"
    readonly property color surfaceRaised: dark ? "#1A2136" : "#F5F7FC"
    readonly property color surfaceSunken: dark ? "#0C1120" : "#E9EDF6"
    readonly property color surfaceGlass:  dark ? Qt.rgba(0.07, 0.09, 0.16, 0.80) : Qt.rgba(1, 1, 1, 0.82)
    readonly property color surfaceGlassStrong: dark ? Qt.rgba(0.065, 0.083, 0.145, 0.965) : Qt.rgba(0.985, 0.99, 1, 0.97)
    readonly property color hover:         dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0.05, 0.08, 0.20, 0.06)
    readonly property color pressed:       dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.05, 0.08, 0.20, 0.11)
    readonly property color outline:       dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0.06, 0.09, 0.19, 0.10)
    readonly property color outlineStrong: dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0.06, 0.09, 0.19, 0.20)
    readonly property color highlightEdge: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.95)
    readonly property color textPrimary:   dark ? "#F3F6FD" : "#0C1222"
    readonly property color textSecondary: dark ? "#A7B1C8" : "#475069"
    readonly property color textTertiary:  dark ? "#7E89A3" : "#5F6884"
    readonly property color accent:        dark ? currentAccent.dark : currentAccent.light
    readonly property color textOnAccent:      dark ? "#06121A" : "#FFFFFF"
    readonly property color accentSoft:    Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.16 : 0.11)
    readonly property color accentStrong:  Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.30 : 0.22)
    readonly property color danger:        dark ? "#FF7A8A" : "#BE2337"
    readonly property color success:       dark ? "#6EE7B7" : "#0B7253"
    readonly property color prototype:     dark ? "#FFB547" : "#8A5300"
    readonly property color prototypeSoft: dark ? Qt.rgba(1, 0.71, 0.28, 0.14) : Qt.rgba(0.54, 0.33, 0, 0.09)
    readonly property color scrim:         Qt.rgba(0.02, 0.03, 0.07, dark ? 0.55 : 0.28)
    readonly property color shadow:        dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0.10, 0.14, 0.30, 0.20)

    // --- Spaziature (griglia di 4 px) e raggi ---
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32
    readonly property int s7: 48
    readonly property int radiusSmall: 10
    readonly property int radius: 16
    readonly property int radiusLarge: 24
    readonly property int radiusXL: 32

    // --- Tipografia (scala modulare, Inter) ---
    readonly property string fontFamily: "Inter"
    readonly property string fontDisplayFamily: "Inter Display"
    readonly property int fontMicro: 11
    readonly property int fontCaption: 12
    readonly property int fontBody: 14
    readonly property int fontTitle: 16
    readonly property int fontHeading: 20
    readonly property int fontH1: 28
    readonly property int fontDisplay: 64

    // --- Movimento (azzerato con "movimento ridotto") ---
    readonly property int durationFast: reducedMotion ? 0 : 130
    readonly property int durationNormal: reducedMotion ? 0 : 220
    readonly property int durationSlow: reducedMotion ? 0 : 380
    readonly property int durationEmphasis: reducedMotion ? 0 : 520
    readonly property int staggerStep: reducedMotion ? 0 : 18
    readonly property bool ambientMotion: !reducedMotion && !lowPower
    readonly property int easing: Easing.OutCubic
    readonly property int easingEmphasized: Easing.OutBack
    readonly property int easingStandard: Easing.InOutCubic

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
    function alpha(c, a) { const q = Qt.lighter(c, 1.0); return Qt.rgba(q.r, q.g, q.b, a) }
}
