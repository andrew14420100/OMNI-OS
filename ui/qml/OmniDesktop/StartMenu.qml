import QtQuick
import OmniDesign

// Menu Start OMNI (unico menu delle applicazioni del desktop): ricerca istantanea fra le app
// installate, app aggiunte a Start, elenco completo, utente ed energia.
// Ogni avvio è reale (gio launch del file .desktop). Il menu di Plasma non è attivo.
PanelFrame {
    id: start
    property var session: null
    property var appIndex: session ? session.appIndex : null
    property string query: search.text
    property bool allApps: false
    property bool powerOpen: false
    width: 640
    height: 680

    function reset() { search.text = ""; allApps = false; powerOpen = false; list.positionViewAtBeginning() }
    function focusSearch() { search.focusInput() }
    function launch(e) { if (e && session) session.launchEntry(e) }
    readonly property var results: appIndex ? appIndex.search(query, 9) : []
    readonly property var pinnedEntries: {
        const out = []
        if (!appIndex || !session) return out
        for (const id of session.startPins) { const e = appIndex.find(id); if (e) out.push(e) }
        return out
    }

    Keys.onEscapePressed: session.close()

    Column {
        anchors.fill: parent
        anchors.margins: 24
        anchors.bottomMargin: 0
        spacing: 18

        OmniSearchField {
            id: search
            objectName: "start:search"
            width: parent.width
            placeholder: qsTr("Cerca app, impostazioni e file")
            onAccepted: {
                if (start.results.length > 0) start.launch(start.results[0])
                else if (text.trim() !== "") { kwinActions.krunnerQuery(text); start.session.close() }
            }
            Keys.onEscapePressed: start.session.close()
        }

        // --- risultati della ricerca ---
        Column {
            visible: start.query.trim() !== ""
            width: parent.width
            spacing: 2
            Text { text: start.results.length ? qsTr("Applicazioni") : qsTr("Nessuna app trovata"); color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily; font.weight: Font.DemiBold }
            Repeater {
                model: start.results
                delegate: AppRow {
                    required property var modelData
                    required property int index
                    entry: modelData
                    highlighted: index === 0
                    objectName: "start:result:" + modelData.desktopId
                    onActivated: start.launch(modelData)
                }
            }
            AppRow {
                objectName: "start:krunner"
                entry: ({ name: qsTr("Cerca nel sistema: \"%1\"").arg(start.query.trim()), comment: qsTr("File, impostazioni e calcoli con KRunner"), iconName: "", desktopId: "", categories: [] })
                glyphName: "search"
                onActivated: { kwinActions.krunnerQuery(start.query.trim()); start.session.close() }
            }
        }

        // --- app aggiunte a Start ---
        Column {
            visible: start.query.trim() === "" && !start.allApps
            width: parent.width
            spacing: 12
            Item {
                width: parent.width; height: 28
                Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Aggiunte"); color: Theme.textPrimary; font.pixelSize: 14; font.family: Theme.fontFamily; font.weight: Font.DemiBold }
                OmniButton {
                    objectName: "start:allapps"
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Tutte le app  ›"); ghost: true
                    onClicked: start.allApps = true
                }
            }
            Grid {
                columns: 6
                columnSpacing: 4
                rowSpacing: 6
                Repeater {
                    model: start.pinnedEntries
                    delegate: Tile {
                        required property var modelData
                        entry: modelData
                        objectName: "start:pin:" + modelData.desktopId
                        onActivated: start.launch(modelData)
                        onMenu: start.session.openAppMenu(modelData, this)
                    }
                }
            }
            Text {
                visible: start.pinnedEntries.length === 0
                text: qsTr("Nessuna app aggiunta. Apri \"Tutte le app\" e usa il clic destro per aggiungerle.")
                color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily
                width: parent.width; wrapMode: Text.WordWrap
            }
        }

        // --- tutte le app (ordine alfabetico) ---
        Item {
            visible: start.query.trim() === "" && start.allApps
            width: parent.width
            height: start.height - 24 - search.height - 18 - footer.height - 8
            Item {
                id: allHeader
                width: parent.width; height: 28
                Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Tutte le app"); color: Theme.textPrimary; font.pixelSize: 14; font.family: Theme.fontFamily; font.weight: Font.DemiBold }
                OmniButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: qsTr("‹  Indietro"); ghost: true; onClicked: start.allApps = false }
            }
            ListView {
                id: list
                anchors { top: allHeader.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }
                clip: true
                model: start.appIndex ? start.appIndex.all : []
                reuseItems: true
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds
                delegate: AppRow {
                    required property var modelData
                    width: ListView.view.width
                    entry: modelData
                    objectName: "start:app:" + modelData.desktopId
                    onActivated: start.launch(modelData)
                    onMenu: start.session.openAppMenu(modelData, this)
                }
            }
        }
    }

    // --- piede: utente ed energia ---
    Rectangle {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 64
        radius: start.radius
        color: Theme.dark ? "#10162A" : "#F0F2F8"
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.outline }
        Row {
            anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
            spacing: 12
            Rectangle {
                width: 32; height: 32; radius: 16; color: Theme.accentSoft
                Text { anchors.centerIn: parent; text: (currentUser || "?").charAt(0).toUpperCase(); color: Theme.accent; font.pixelSize: 15; font.weight: Font.Bold; font.family: Theme.fontFamily }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: currentUser; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
        }
        OmniIconButton {
            objectName: "start:power"
            anchors { right: parent.right; rightMargin: 36; verticalCenter: parent.verticalCenter }
            icon: "power"; label: qsTr("Energia"); round: true
            checked: start.powerOpen
            onClicked: { start.powerOpen = !start.powerOpen; if (start.powerOpen) sessionActions.refresh() }
        }
    }

    // --- menu energia ---
    PowerMenu {
        id: power
        visible: start.powerOpen
        anchors { right: parent.right; rightMargin: 24; bottom: footer.top; bottomMargin: 6 }
        onDone: start.powerOpen = false
        onBeforeAction: start.session.close()
    }

    component AppRow: Item {
        id: row
        property var entry: null
        property bool highlighted: false
        property string glyphName: ""
        signal activated()
        signal menu()
        height: 52
        width: parent ? parent.width : 300
        Accessible.role: Accessible.Button
        Accessible.name: entry ? entry.name : ""
        Accessible.onPressAction: row.activated()
        Rectangle { anchors.fill: parent; radius: 8; color: rowMa.pressed ? Theme.pressed : (rowMa.containsMouse || row.highlighted ? Theme.hover : "transparent") }
        Item {
            id: ic
            x: 10; width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
            AppIcon {
                visible: row.glyphName === ""
                anchors.fill: parent; size: 32
                appName: row.entry ? row.entry.name : ""; desktopId: row.entry ? row.entry.desktopId : ""
                iconName: row.entry ? row.entry.iconName : ""; categories: row.entry ? row.entry.categories : []
            }
            OmniIcon { visible: row.glyphName !== ""; anchors.centerIn: parent; width: 22; height: 22; name: row.glyphName || "search"; color: Theme.textSecondary }
        }
        Column {
            anchors { left: ic.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            Text { width: parent.width; text: row.entry ? row.entry.name : ""; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily; elide: Text.ElideRight }
            Text { width: parent.width; visible: text !== ""; text: row.entry && row.entry.comment ? row.entry.comment : ""; color: Theme.textSecondary; font.pixelSize: 11; font.family: Theme.fontFamily; elide: Text.ElideRight }
        }
        MouseArea {
            id: rowMa; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? row.menu() : row.activated()
        }
    }

    component Tile: Item {
        id: tile
        property var entry: null
        signal activated()
        signal menu()
        width: 96; height: 84
        Accessible.role: Accessible.Button
        Accessible.name: entry ? entry.name : ""
        Accessible.onPressAction: tile.activated()
        Rectangle { anchors.fill: parent; radius: 8; color: tileMa.pressed ? Theme.pressed : (tileMa.containsMouse ? Theme.hover : "transparent") }
        AppIcon {
            id: tileIcon
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 10 }
            size: 36
            appName: tile.entry ? tile.entry.name : ""; desktopId: tile.entry ? tile.entry.desktopId : ""
            iconName: tile.entry ? tile.entry.iconName : ""; categories: tile.entry ? tile.entry.categories : []
        }
        Text {
            anchors { top: tileIcon.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 4; rightMargin: 4 }
            horizontalAlignment: Text.AlignHCenter
            text: tile.entry ? tile.entry.name : ""
            color: Theme.textPrimary; font.pixelSize: 12; font.family: Theme.fontFamily; elide: Text.ElideRight
        }
        MouseArea {
            id: tileMa; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? tile.menu() : tile.activated()
        }
    }
}
