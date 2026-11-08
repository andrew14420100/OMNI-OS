pragma Singleton
import QtQuick
import OmniDesign

// Catalogo del launcher: categorie OMNI ricavate dalle categorie freedesktop dei file
// .desktop o, in mancanza, dal glifo dell'applicazione.
QtObject {
    readonly property var categories: [
        { id: "sistema",    name: qsTr("Sistema"),    icon: "settings" },
        { id: "internet",   name: qsTr("Internet"),   icon: "globe" },
        { id: "multimedia", name: qsTr("Multimedia"), icon: "music" },
        { id: "grafica",    name: qsTr("Grafica"),    icon: "image" },
        { id: "ufficio",    name: qsTr("Ufficio"),    icon: "briefcase" },
        { id: "sviluppo",   name: qsTr("Sviluppo"),   icon: "code" },
        { id: "giochi",     name: qsTr("Giochi"),     icon: "gamepad" },
        { id: "utilita",    name: qsTr("Utilità"),    icon: "tool" }
    ]
    readonly property var freedesktop: [
        ["Development", "sviluppo"], ["Game", "giochi"], ["Graphics", "grafica"], ["Office", "ufficio"],
        ["AudioVideo", "multimedia"], ["Audio", "multimedia"], ["Video", "multimedia"],
        ["Network", "internet"], ["WebBrowser", "internet"], ["Email", "internet"],
        ["Settings", "sistema"], ["System", "sistema"], ["Utility", "utilita"], ["Accessibility", "utilita"]
    ]
    readonly property var byGlyph: ({
        update: "sistema", security: "sistema", performance: "sistema", network: "sistema", storage: "sistema",
        settings: "sistema", display: "sistema", audio: "sistema", accessibility: "sistema",
        browser: "internet", mail: "internet", chat: "internet",
        media: "multimedia", music: "multimedia", video: "multimedia",
        photos: "grafica", drawing: "grafica", office: "ufficio", spreadsheet: "ufficio", presentation: "ufficio", calendar: "ufficio", texteditor: "utilita",
        developer: "sviluppo", terminal: "sviluppo", gaming: "giochi"
    })
    function categoryOf(categories, glyph) {
        const cats = categories || []
        for (let i = 0; i < freedesktop.length; ++i)
            if (cats.indexOf(freedesktop[i][0]) >= 0) return freedesktop[i][1]
        return byGlyph[glyph] || "utilita"
    }
    function categoryName(id) {
        for (let i = 0; i < categories.length; ++i) if (categories[i].id === id) return categories[i].name
        return id
    }
    // Voce normalizzata da un modello (DesktopEntryModel o ListModel di prova).
    function entry(a) {
        const cats = a.categories ? Array.prototype.slice.call(a.categories) : []
        const glyph = AppGlyphs.resolve(a.name, a.desktopId || "", a.iconName || "", cats)
        return { name: a.name, comment: a.comment || "", desktopId: a.desktopId || a.name,
                 iconName: a.iconName || "", categories: cats, glyph: glyph, category: categoryOf(cats, glyph) }
    }
}
