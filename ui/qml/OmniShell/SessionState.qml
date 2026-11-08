import QtQuick

// Stato della sessione del PROTOTIPO, solo in memoria: preferiti, recenti e applicazioni
// "aperte" nell'anteprima. Non legge né scrive la configurazione reale di Plasma e non
// avvia processi.
QtObject {
    id: s
    property var favorites: []      // desktopId fissati nel dock
    property var recents: []        // desktopId, più recente per primo
    property var opened: []         // desktopId con anteprima di apertura mostrata
    property int maxRecents: 8

    function isFavorite(id) { return favorites.indexOf(id) >= 0 }
    function toggleFavorite(id) {
        const f = favorites.slice(); const i = f.indexOf(id)
        if (i >= 0) f.splice(i, 1); else f.push(id)
        favorites = f
        return i < 0
    }
    function noteLaunch(id) {
        const r = recents.filter(x => x !== id); r.unshift(id)
        recents = r.slice(0, maxRecents)
        if (opened.indexOf(id) < 0) opened = opened.concat([id])
    }
    function close(id) { opened = opened.filter(x => x !== id) }
    function isOpen(id) { return opened.indexOf(id) >= 0 }
}
