import QtQuick
import QtQuick.Layouts
import OmniDesign

// Launcher OMNI: ricerca istantanea fra le applicazioni installate.
// L'elenco proviene dai file .desktop XDG letti in sola lettura (modello C++), oppure
// da un modello dimostrativo. L'AVVIO delle applicazioni è disattivato nel prototipo:
// il prototipo non deve agire sulla sessione reale.
Item {
    id: root
    property var apps: null
    property bool open: false
    property string query: ""
    property var filtered: []
    signal activated(string name)
    signal closeRequested()

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
    onOpenChanged: if (open) { search.text = ""; search.focusInput() }
    onQueryChanged: refilter()
    onAppsChanged: refilter()
    Connections { target: root.apps; ignoreUnknownSignals: true; function onCountChanged() { root.refilter() } }

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
    function refilter() {
        const out = []
        if (apps) for (let i = 0; i < apps.count; ++i) {
            const a = apps.get(i)
            if (matches(a.name, a.comment, query)) out.push({ name: a.name, comment: a.comment || "" })
        }
        filtered = out
    }

    Rectangle { anchors.fill: parent; color: Theme.scrim; MouseArea { anchors.fill: parent; onClicked: root.closeRequested() } }

    OmniSurface {
        id: card
        width: Math.min(parent.width - Theme.s6 * 2, 880)
        height: Math.min(parent.height - 160, 600)
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 - 30 + (root.open ? 0 : 24)
        scale: root.open ? 1 : 0.97
        radius: Theme.radiusLarge
        Behavior on y { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
        MouseArea { anchors.fill: parent }   // i clic dentro la scheda non chiudono il launcher

        ColumnLayout {
            anchors.fill: parent; anchors.margins: Theme.s5; spacing: Theme.s4
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Applicazioni"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle + 4; font.weight: Font.Bold; Layout.fillWidth: true }
                PrototypeBadge { text: qsTr("Prototipo · avvio disattivato") }
            }
            OmniSearchField {
                id: search; Layout.fillWidth: true
                placeholder: qsTr("Cerca applicazioni")
                onTextChanged: root.query = text
                onAccepted: if (root.filtered.length > 0) root.activated(root.filtered[0].name)
                Keys.onEscapePressed: root.closeRequested()
            }
            Text {
                text: qsTr("%n applicazioni", "", root.filtered.length)
                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption
            }
            GridView {
                id: grid
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128))); cellHeight: 120
                model: root.filtered
                add: Transition { NumberAnimation { properties: "opacity,scale"; from: 0.6; to: 1; duration: Theme.durationNormal } }
                displaced: Transition { NumberAnimation { properties: "x,y"; duration: Theme.durationNormal; easing.type: Theme.easing } }
                delegate: Item {
                    required property var modelData
                    width: grid.cellWidth; height: grid.cellHeight
                    Column {
                        anchors.centerIn: parent; spacing: Theme.s2
                        OmniAppTile {
                            anchors.horizontalCenter: parent.horizontalCenter
                            appName: modelData.name; size: 60
                            scale: m.containsMouse ? 1.08 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingEmphasized } }
                        }
                        Text {
                            width: grid.cellWidth - Theme.s3; horizontalAlignment: Text.AlignHCenter
                            text: modelData.name; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                            color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1
                        }
                    }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: root.activated(modelData.name) }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                }
            }
        }
    }
}
