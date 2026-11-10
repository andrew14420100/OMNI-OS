import QtQuick
import QtQuick.Window
import OmniDesign

// Finestra di un'app OMNI: barra laterale di navigazione (con ricerca) e area delle pagine.
// Bordi, titolo, spostamento, affiancamento e ridimensionamento sono quelli di KWin (uguali
// per tutte le finestre del sistema). Tema e accento seguono le preferenze condivise con la
// shell e cambiano dal vivo.
Window {
    id: win
    property var sections: []            // [{ id, title, icon, source }]
    property string current: sections.length ? sections[0].id : ""
    property alias searchText: search.text
    property string appTitle: ""
    property bool showSearch: true
    property var pageProps: ({})
    property url baseUrl: ""                // cartella dell'app: le pagine sono relative a essa
    signal pageLoaded(var item)
    width: 1180; height: 780
    minimumWidth: 760; minimumHeight: 520
    visible: true
    title: appTitle
    color: Theme.dark ? "#0F1424" : "#F3F5FA"

    function applyPrefs() {
        Theme.dark = shellSettings.dark
        Theme.accentIndex = shellSettings.accent
        Theme.reducedMotion = shellSettings.reducedMotion
    }
    Connections { target: shellSettings; function onChanged() { win.applyPrefs() } }
    Component.onCompleted: {
        applyPrefs()
        // pagina iniziale da riga di comando: --pagina <id> oppure --pagina=<id>
        const a = Qt.application.arguments
        for (let i = 0; i < a.length; ++i) {
            const v = a[i] === "--pagina" ? a[i + 1] : (a[i].startsWith("--pagina=") ? a[i].slice(9) : undefined)
            if (v && sections.some(s => s.id === v)) current = v
        }
        shellPerf.mark("finestra creata")
    }
    onFrameSwapped: shellPerf.mark("primo fotogramma")
    function open(id) { current = id }

    readonly property var filtered: {
        const q = search.text.trim().toLowerCase()
        if (!q) return sections
        return sections.filter(s => (s.title + " " + (s.keywords || "")).toLowerCase().indexOf(q) >= 0)
    }

    Rectangle {
        id: side
        width: 280; anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: Theme.dark ? "#0B1020" : "#E9EDF5"
        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 4
            Row {
                spacing: 10; bottomPadding: 10
                Rectangle { width: 28; height: 28; radius: 14
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.glow } GradientStop { position: 1; color: Theme.glowPair } }
                    Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: Theme.dark ? "#0E1322" : "#F6F7FB" } }
                Text { anchors.verticalCenter: parent.verticalCenter; text: win.appTitle; color: Theme.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
            }
            OmniSearchField { id: search; visible: win.showSearch; width: parent.width; placeholder: qsTr("Cerca"); objectName: "app:search"
                onAccepted: if (win.filtered.length) win.current = win.filtered[0].id }
            Item { width: 1; height: 8 }
            Repeater {
                model: win.filtered
                delegate: Rectangle {
                    id: nav
                    required property var modelData
                    width: parent.width; height: 40; radius: 6
                    objectName: "nav:" + modelData.id
                    color: win.current === modelData.id ? (Theme.dark ? "#1C2440" : "#FFFFFF") : (nm.containsMouse ? Theme.hover : "transparent")
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.title
                    Rectangle { visible: win.current === nav.modelData.id; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 16; radius: 1.5; color: Theme.accent }
                    Row {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 12
                        OmniIcon { width: 18; height: 18; name: nav.modelData.icon; color: Theme.textPrimary }
                        Text { text: nav.modelData.title; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                    }
                    MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; onClicked: win.current = nav.modelData.id }
                }
            }
        }
    }
    Loader {
        id: pageLoader
        objectName: "app:pagina"
        anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        asynchronous: false
        source: { for (const s of win.sections) if (s.id === win.current) return win.baseUrl + s.source; return "" }
        onLoaded: { for (const k in win.pageProps) if (k in item) item[k] = win.pageProps[k]; win.pageLoaded(item) }
        opacity: status === Loader.Ready ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: 120 } }
    }
}
