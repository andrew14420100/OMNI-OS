import QtQuick
import QtTest
import OmniShell

// Stato della sessione del prototipo (solo in memoria).
TestCase {
    name: "SessionState"
    SessionState { id: s }
    function init() { s.favorites = []; s.recents = []; s.opened = [] }
    function test_toggleFavorite() { verify(s.toggleFavorite("a")); verify(s.isFavorite("a")); verify(!s.toggleFavorite("a")); verify(!s.isFavorite("a")) }
    function test_recentsOrderAndLimit() {
        for (let i = 0; i < 12; ++i) s.noteLaunch("app" + i)
        compare(s.recents.length, s.maxRecents); compare(s.recents[0], "app11")
        s.noteLaunch("app5"); compare(s.recents[0], "app5"); compare(s.recents.filter(x => x === "app5").length, 1)
    }
    function test_openedAndClose() { s.noteLaunch("x"); verify(s.isOpen("x")); s.close("x"); verify(!s.isOpen("x")); verify(s.recents.indexOf("x") >= 0) }
}
