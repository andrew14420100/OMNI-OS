import QtQuick
import QtTest
import OmniDesign

// Monogrammi e colori delle tessere: distinguibili anche con prefisso comune "OMNI".
TestCase {
    name: "AppTile"
    OmniAppTile { id: t }
    function test_monogramSkipsOmniPrefix() {
        compare(t.monogram("OMNI File Manager"), "FM")
        compare(t.monogram("OMNI Terminal"), "TE")
        compare(t.monogram("Firefox"), "FI")
        compare(t.monogram("OMNI"), "O")
    }
    function test_distinctHues() {
        const names = ["OMNI File Manager", "OMNI Terminal", "OMNI Store", "OMNI Browser", "OMNI Update Center"]
        const hues = names.map(n => Math.round(t.hue(n, 0) * 360))
        compare(new Set(hues).size, names.length)
    }
}
