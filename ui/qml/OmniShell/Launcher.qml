import QtQuick
import QtQuick.Layouts
import OmniDesign

// Launcher OMNI: ricerca istantanea, categorie, preferiti e recenti.
// L'elenco proviene dai file .desktop XDG letti in sola lettura (modello C++), oppure
// da un modello dimostrativo. L'AVVIO delle applicazioni è disattivato nel prototipo:
// il prototipo non deve agire sulla sessione reale.
// Tastiera: digitare per cercare, ↓ per passare alla griglia, frecce per navigare,
// Invio per aprire, Ctrl+D per aggiungere/togliere dai preferiti, Esc per chiudere.
Item {
    id: root
    property var apps: null
    property var session: null
    property bool open: false
    property string query: ""
    property string category: "tutte"
    property var catalog: []          // tutte le voci normalizzate
    property var filtered: []         // voci mostrate nella griglia
    property var counts: ({})
    signal activated(string name)
    signal activatedEntry(var entry, real gx, real gy)
    signal closeRequested()

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
    onOpenChanged: if (open) { search.text = ""; category = "tutte"; search.focusInput() }
    onQueryChanged: refilter()
    onCategoryChanged: refilter()
    onAppsChanged: rebuild()
    Connections { target: root.apps; ignoreUnknownSignals: true; function onCountChanged() { root.rebuild() } }
    Connections { target: root.session; ignoreUnknownSignals: true
        function onFavoritesChanged() { root.refilter() }
        function onRecentsChanged() { root.refilter() } }
    Component.onCompleted: rebuild()

    // Normalizzazione per la ricerca: minuscole e senza accenti.
    function normalize(s) {
        s = String(s || "").toLowerCase()
        return s.normalize ? s.normalize("NFD").replace(/[̀-ͯ]/g, "") : s
    }
    function matches(name, comment, q) {
        const nq = normalize(q).trim()
        if (nq.length === 0) return true
        const hay = normalize(name) + " " + normalize(comment)
        return nq.split(/\s+/).every(t => hay.indexOf(t) >= 0)
    }
    // Punteggio: nome che inizia con la ricerca > parola del nome > solo descrizione.
    function score(e, q) {
        const nq = normalize(q).trim(), n = normalize(e.name)
        if (!nq) return 0
        if (n.indexOf(nq) === 0) return 3
        if (n.split(/\s+/).some(w => w.indexOf(nq) === 0)) return 2
        return n.indexOf(nq) >= 0 ? 1 : 0
    }
    function rebuild() {
        const out = [], c = { tutte: 0 }
        if (apps) for (let i = 0; i < apps.count; ++i) {
            const e = AppCatalog.entry(apps.get(i))
            out.push(e); c.tutte++; c[e.category] = (c[e.category] || 0) + 1
        }
        catalog = out; counts = c
        refilter()
    }
    // etichetta breve: il prefisso del marchio "OMNI " è omesso (il nome completo resta per l'accessibilità)
    function label(n) { return String(n).replace(/^OMNI\s+/, "") }
    function byIds(ids) { return ids.map(id => catalog.find(e => e.desktopId === id)).filter(e => !!e) }
    function refilter() {
        let base = catalog
        if (category === "preferiti") base = session ? byIds(session.favorites) : []
        else if (category === "recenti") base = session ? byIds(session.recents) : []
        else if (category !== "tutte") base = catalog.filter(e => e.category === category)
        const res = base.filter(e => matches(e.name, e.comment, query))
        if (query.trim().length > 0) res.sort((a, b) => score(b, query) - score(a, query))
        filtered = res
        grid.currentIndex = res.length > 0 ? 0 : -1
    }
    function launch(e, item) {
        if (!e) return
        const p = item ? item.mapToItem(null, item.width / 2, item.height / 2) : Qt.point(width / 2, height / 2)
        activated(e.name)
        activatedEntry(e, p.x, p.y)
    }

    Rectangle { anchors.fill: parent; color: Theme.scrim; MouseArea { anchors.fill: parent; onClicked: root.closeRequested() } }

    OmniSurface {
        id: card
        width: Math.min(parent.width - Theme.s7 * 2, 1060)
        height: Math.min(parent.height - 150, 700)
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 - 24 + (root.open ? 0 : 28)
        scale: root.open ? 1 : 0.965
        radius: Theme.radiusXL
        strong: true
        Behavior on y { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        MouseArea { anchors.fill: parent }   // i clic dentro la scheda non chiudono il launcher

        RowLayout {
            anchors.fill: parent; spacing: 0

            // --- colonna delle categorie ---
            Rectangle {
                Layout.preferredWidth: 220; Layout.fillHeight: true
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.02) : Qt.rgba(0.05, 0.08, 0.2, 0.025)
                radius: Theme.radiusXL
                Rectangle { anchors.right: parent.right; width: parent.radius; height: parent.height; color: parent.color }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.outline }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.s4; spacing: 4
                    Text { text: qsTr("Applicazioni"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontHeading + 2; font.weight: Font.Bold; Layout.bottomMargin: Theme.s3; Layout.leftMargin: 4 }
                    OmniChip { Layout.fillWidth: true; text: qsTr("Tutte"); icon: "apps"; count: root.counts.tutte || 0; checked: root.category === "tutte"; onClicked: root.category = "tutte" }
                    OmniChip { Layout.fillWidth: true; text: qsTr("Preferiti"); icon: "star"; count: root.session ? root.session.favorites.length : 0; checked: root.category === "preferiti"; onClicked: root.category = "preferiti" }
                    OmniChip { Layout.fillWidth: true; text: qsTr("Recenti"); icon: "history"; count: root.session ? root.session.recents.length : 0; checked: root.category === "recenti"; onClicked: root.category = "recenti" }
                    Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.s2; Layout.bottomMargin: Theme.s2; height: 1; color: Theme.outline }
                    Repeater {
                        model: AppCatalog.categories.filter(c => (root.counts[c.id] || 0) > 0)
                        OmniChip {
                            required property var modelData
                            objectName: "launcher:cat:" + modelData.id
                            Layout.fillWidth: true; text: modelData.name; icon: modelData.icon
                            count: root.counts[modelData.id] || 0
                            checked: root.category === modelData.id; onClicked: root.category = modelData.id
                        }
                    }
                    Item { Layout.fillHeight: true }
                    PrototypeBadge { text: qsTr("Prototipo · avvio disattivato") }
                }
            }

            // --- ricerca e risultati ---
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: Theme.s5; spacing: Theme.s4
                OmniSearchField {
                    id: search; objectName: "launcher:search"; Layout.fillWidth: true
                    placeholder: qsTr("Cerca applicazioni, categorie, descrizioni…")
                    hint: root.filtered.length + " / " + root.catalog.length
                    onTextChanged: root.query = text
                    onAccepted: if (root.filtered.length > 0) root.launch(root.filtered[0], grid.currentItem)
                    onDownPressed: grid.forceActiveFocus()
                    Keys.onEscapePressed: root.closeRequested()
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.query.trim().length > 0 ? qsTr("Risultati per «%1»").arg(root.query.trim())
                              : root.category === "tutte" ? qsTr("Tutte le applicazioni")
                              : root.category === "preferiti" ? qsTr("Preferiti") : root.category === "recenti" ? qsTr("Recenti")
                              : AppCatalog.categoryName(root.category)
                        color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold
                    }
                    Text { text: qsTr("%n applicazioni", "", root.filtered.length); color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                }
                GridView {
                    id: grid
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    readonly property int columns: Math.max(1, Math.floor(width / 132))
                    cellWidth: Math.floor(width / columns); cellHeight: 128
                    model: root.filtered
                    keyNavigationEnabled: true
                    header: Column {
                        width: grid.width
                        readonly property bool show: root.category === "tutte" && root.query.trim().length === 0 && root.session !== null
                        visible: show; height: show ? implicitHeight : 0
                        spacing: Theme.s2
                        Repeater {
                            model: [ { title: qsTr("Preferiti"), icon: "star", ids: root.session ? root.session.favorites : [] },
                                     { title: qsTr("Recenti"), icon: "history", ids: root.session ? root.session.recents : [] } ]
                            Column {
                                required property var modelData
                                readonly property var list: root.byIds(modelData.ids).slice(0, 9)
                                visible: list.length > 0; width: grid.width; spacing: Theme.s2
                                Row {
                                    spacing: 6
                                    OmniIcon { width: 15; height: 15; name: modelData.icon; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.title; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8 }
                                }
                                Rectangle {
                                    width: grid.width - Theme.s2; height: 76; radius: Theme.radius
                                    color: Theme.hover; border.color: Theme.outline
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter; x: Theme.s3; spacing: Theme.s3
                                        Repeater {
                                            model: parent.parent.parent.list
                                            Item {
                                                required property var modelData
                                                width: 64; height: 64
                                                OmniAppIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 44; shadow: false; appName: modelData.name; glyph: modelData.glyph
                                                    scale: hm.containsMouse ? 1.1 : 1; Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingEmphasized } } }
                                                Text { anchors.bottom: parent.bottom; width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: root.label(modelData.name); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontMicro }
                                                MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; onClicked: root.launch(modelData, parent) }
                                                Accessible.role: Accessible.Button; Accessible.name: modelData.name
                                            }
                                        }
                                    }
                                }
                                Item { width: 1; height: Theme.s2 }
                            }
                        }
                    }
                    highlightFollowsCurrentItem: true
                    boundsBehavior: Flickable.StopAtBounds
                    Keys.onReturnPressed: root.launch(root.filtered[currentIndex], currentItem)
                    Keys.onEnterPressed: root.launch(root.filtered[currentIndex], currentItem)
                    Keys.onEscapePressed: root.closeRequested()
                    Keys.onUpPressed: (ev) => { if (currentIndex < columns) search.focusInput(); else moveCurrentIndexUp() }
                    Keys.onPressed: (ev) => {
                        if ((ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_D && root.session && currentIndex >= 0) {
                            root.session.toggleFavorite(root.filtered[currentIndex].desktopId); ev.accepted = true
                        } else if (ev.text.length === 1 && ev.text.trim().length === 1 && !(ev.modifiers & Qt.ControlModifier)) {
                            search.text += ev.text; search.focusInput(); ev.accepted = true
                        }
                    }
                    delegate: Item {
                        id: cell
                        objectName: "launcher:" + modelData.glyph
                        required property var modelData
                        required property int index
                        readonly property bool current: GridView.isCurrentItem && grid.activeFocus
                        readonly property bool fav: root.session ? (root.session.favorites, root.session.isFavorite(modelData.desktopId)) : false
                        width: grid.cellWidth; height: grid.cellHeight
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name
                        opacity: 0; scale: 0.92
                        Component.onCompleted: appear.start()
                        SequentialAnimation {
                            id: appear
                            PauseAnimation { duration: Math.min(18, cell.index) * Theme.staggerStep }
                            ParallelAnimation {
                                NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Theme.durationNormal }
                                NumberAnimation { target: cell; property: "scale"; to: 1; duration: Theme.durationNormal; easing.type: Theme.easing }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: Theme.radius
                            color: cell.current ? Theme.accentSoft : (m.containsMouse ? Theme.hover : "transparent")
                            border.color: cell.current ? Theme.accent : "transparent"; border.width: 2
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 14; spacing: Theme.s2
                            OmniAppIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 58; appName: cell.modelData.name; glyph: cell.modelData.glyph
                                scale: m.containsMouse ? 1.07 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingEmphasized } }
                            }
                            Text {
                                width: grid.cellWidth - Theme.s4; horizontalAlignment: Text.AlignHCenter
                                text: root.label(cell.modelData.name); elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap
                                color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: Font.Medium
                            }
                        }
                        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: { grid.currentIndex = cell.index; root.launch(cell.modelData, cell) } }
                        // stella dei preferiti (visibile al passaggio, sempre se già preferito)
                        Rectangle {
                            visible: root.session !== null && (m.containsMouse || cell.current || starMouse.containsMouse || (cell.fav && root.category === "preferiti"))
                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10
                            width: 26; height: 26; radius: 13
                            color: starMouse.containsMouse ? Theme.pressed : Theme.surfaceRaised; border.color: Theme.outline
                            OmniIcon { anchors.centerIn: parent; width: 15; height: 15; name: "star"; filled: cell.fav; color: cell.fav ? Theme.prototype : Theme.textSecondary }
                            MouseArea { id: starMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.session.toggleFavorite(cell.modelData.desktopId) }
                            Accessible.role: Accessible.Button
                            Accessible.name: cell.fav ? qsTr("Togli dai preferiti") : qsTr("Aggiungi ai preferiti")
                        }
                    }
                }
                // nessun risultato
                ColumnLayout {
                    visible: root.filtered.length === 0
                    Layout.alignment: Qt.AlignHCenter; spacing: Theme.s2; Layout.bottomMargin: Theme.s7
                    OmniIcon { Layout.alignment: Qt.AlignHCenter; width: 40; height: 40; name: "search"; color: Theme.textTertiary }
                    Text { Layout.alignment: Qt.AlignHCenter; text: root.category === "preferiti" && root.query === "" ? qsTr("Nessun preferito: usa la stella o Ctrl+D") : qsTr("Nessuna applicazione trovata"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody }
                }
                // suggerimenti da tastiera
                Row {
                    spacing: Theme.s4; Layout.alignment: Qt.AlignHCenter
                    Repeater {
                        model: [["↵", qsTr("apri")], ["↑↓←→", qsTr("naviga")], ["Ctrl+D", qsTr("preferito")], ["Esc", qsTr("chiudi")]]
                        Row {
                            required property var modelData
                            spacing: 6
                            Rectangle { width: k.implicitWidth + 10; height: 20; radius: 5; color: Theme.hover; border.color: Theme.outline
                                Text { id: k; anchors.centerIn: parent; text: modelData[0]; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontMicro; font.weight: Font.DemiBold } }
                            Text { text: modelData[1]; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }
}
