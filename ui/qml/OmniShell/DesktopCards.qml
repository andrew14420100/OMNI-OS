import QtQuick
import QtQuick.Layouts
import OmniDesign

// Schede del desktop: attività recenti del prototipo e stato onesto del prototipo
// (cosa è collegato al sistema e cosa no).
ColumnLayout {
    id: root
    property var session: null
    property var catalog: []          // voci AppCatalog.entry
    property var store: null
    property bool appsFromSystem: true
    signal activated(var entry, real gx, real gy)
    spacing: Theme.s4

    function entryById(id) { for (let i = 0; i < catalog.length; ++i) if (catalog[i].desktopId === id) return catalog[i]; return null }

    OmniSurface {
        Layout.fillWidth: true; Layout.preferredHeight: recentCol.implicitHeight + Theme.s4 * 2
        radius: Theme.radiusLarge
        ColumnLayout {
            id: recentCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.s4; spacing: Theme.s3
            RowLayout {
                OmniIcon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: "history"; color: Theme.accent }
                Text { Layout.fillWidth: true; text: qsTr("Recenti"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                Text { text: qsTr("in questa sessione"); color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
            }
            Text {
                visible: !root.session || root.session.recents.length === 0
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: qsTr("Le applicazioni aperte dal dock o dal launcher compariranno qui.")
                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1
            }
            Flow {
                Layout.fillWidth: true; spacing: Theme.s3
                Repeater {
                    model: root.session ? root.session.recents.slice(0, 6) : []
                    Column {
                        required property string modelData
                        readonly property var e: root.entryById(modelData)
                        visible: e !== null; spacing: 4; width: 64
                        OmniAppIcon {
                            anchors.horizontalCenter: parent.horizontalCenter; size: 44; shadow: false
                            appName: parent.e ? parent.e.name : ""; glyph: parent.e ? parent.e.glyph : "generic"
                            MouseArea { anchors.fill: parent; onClicked: { const p = mapToItem(null, width / 2, height / 2); root.activated(parent.parent.e, p.x, p.y) } }
                        }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: parent.e ? parent.e.name.replace(/^OMNI /, "") : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontMicro }
                    }
                }
            }
        }
    }

    OmniSurface {
        Layout.fillWidth: true; Layout.preferredHeight: statusCol.implicitHeight + Theme.s4 * 2
        radius: Theme.radiusLarge
        ColumnLayout {
            id: statusCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.s4; spacing: Theme.s2
            RowLayout {
                OmniIcon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: "eye"; color: Theme.prototype }
                Text { Layout.fillWidth: true; text: qsTr("Stato del prototipo"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                PrototypeBadge { text: qsTr("Non è M4") }
            }
            Repeater {
                model: [
                    { k: qsTr("Applicazioni"), v: root.appsFromSystem ? qsTr("file .desktop del sistema (sola lettura)") : qsTr("elenco dimostrativo"), ok: true },
                    { k: qsTr("Tema e accento"), v: (Theme.dark ? qsTr("scuro") : qsTr("chiaro")) + " · " + Theme.currentAccent.name, ok: true },
                    { k: qsTr("Movimento ridotto"), v: Theme.reducedMotion ? qsTr("attivo") : qsTr("disattivo"), ok: true },
                    { k: qsTr("Notifiche"), v: qsTr("%n interne al prototipo", "", root.store ? root.store.count : 0), ok: true },
                    { k: qsTr("Avvio app, rete, audio, spazi di lavoro"), v: qsTr("non collegati"), ok: false }
                ]
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: Theme.s2
                    Rectangle { Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 3.5; color: modelData.ok ? Theme.success : Theme.prototype }
                    Text { text: modelData.k; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1 }
                    Item { Layout.fillWidth: true }
                    Text { text: modelData.v; color: modelData.ok ? Theme.textPrimary : Theme.prototype; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption + 1; font.weight: Font.Medium; elide: Text.ElideRight; Layout.maximumWidth: 220 }
                }
            }
        }
    }
}
