import QtQuick

// Tessera di un'applicazione: monogramma dalle parole significative del nome
// (si ignora il prefisso "OMNI") e gradiente derivato dall'intero nome.
Rectangle {
    id: root
    property string appName: ""
    property int size: 60
    width: size; height: size
    radius: Math.round(size * 0.3)

    function words(n) { return String(n).split(/\s+/).filter(w => w.length > 0 && w.toUpperCase() !== "OMNI") }
    function monogram(n) {
        const w = words(n)
        if (w.length === 0) return String(n).charAt(0).toUpperCase()
        return (w.length === 1 ? w[0].substring(0, 2) : w[0].charAt(0) + w[1].charAt(0)).toUpperCase()
    }
    function hue(n, shift) {
        let h = 0
        for (let i = 0; i < n.length; ++i) h = (h * 31 + n.charCodeAt(i)) % 360
        return ((h + shift) % 360) / 360
    }
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.hsla(root.hue(root.appName, 0), 0.62, Theme.dark ? 0.50 : 0.52, 1) }
        GradientStop { position: 1; color: Qt.hsla(root.hue(root.appName, 40), 0.66, Theme.dark ? 0.34 : 0.40, 1) }
    }
    border.color: Qt.rgba(1, 1, 1, 0.16)
    border.width: 1
    Text {
        anchors.centerIn: parent
        text: root.monogram(root.appName)
        color: "white"
        font.family: Theme.fontFamily; font.pixelSize: Math.round(root.size * 0.36); font.weight: Font.Bold
    }
}
