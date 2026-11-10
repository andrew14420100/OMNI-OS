import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Schermo")
    subtitle: qsTr("Risoluzione, frequenza e scala dello schermo (KScreen). Ogni modifica viene confermata solo dopo aver riletto lo stato reale.")
    property string result: ""
    property int resultKind: 0
    Connections { target: systemStatus; function onDisplayApplied(ok, message) { page.result = message; page.resultKind = ok ? 1 : 2 } }
    StatusNote { text: systemStatus.displayStatus; kind: 2 }
    Repeater {
        model: systemStatus.outputs
        delegate: Column {
            id: o
            required property var modelData
            width: parent.width; spacing: 8
            property string mode: modelData.currentMode
            property real scale: modelData.scale
            readonly property var sizes: { const s = []; for (const m of modelData.modes) { const k = m.width + "x" + m.height; if (s.indexOf(k) < 0) s.push(k) } return s }
            readonly property var rates: { const r = []; const k = o.mode.split("@")[0]; for (const m of modelData.modes) if (m.width + "x" + m.height === k && r.indexOf(Math.round(m.refresh)) < 0) r.push(Math.round(m.refresh)); return r.sort((a, b) => b - a) }
            SectionTitle { text: o.modelData.name + (o.modelData.enabled ? "" : qsTr(" (spento)")) }
            SettingCard { icon: "display"; title: qsTr("Stato attuale"); subtitle: o.modelData.currentMode + " · " + qsTr("scala") + " " + Math.round(o.modelData.scale * 100) + "%" }
            SettingCard {
                title: qsTr("Risoluzione"); subtitle: qsTr("Solo le risoluzioni offerte da questo schermo")
                height: 64 + resFlow.height
                Flow { id: resFlow; width: 420; spacing: 6
                    Repeater { model: o.sizes.slice(0, 12); delegate: OmniChip { required property var modelData; text: modelData; objectName: "res:" + modelData; checked: o.mode.split("@")[0] === modelData; onClicked: o.mode = modelData + "@" + (o.rates.length ? o.rates[0] : 60) } } }
            }
            SettingCard {
                title: qsTr("Frequenza di aggiornamento"); subtitle: qsTr("Solo le frequenze realmente disponibili (in una VM di solito 60 Hz)")
                Flow { width: 420; spacing: 6
                    Repeater { model: o.rates; delegate: OmniChip { required property var modelData; text: modelData + " Hz"; checked: o.mode.split("@")[1] == modelData; onClicked: o.mode = o.mode.split("@")[0] + "@" + modelData } } }
            }
            SettingCard {
                title: qsTr("Scala"); subtitle: qsTr("Dimensione di testi e interfaccia (200% per un 4K da 27-32 pollici)")
                Flow { width: 420; spacing: 6
                    Repeater { model: [1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3]; delegate: OmniChip { required property var modelData; objectName: "scale:" + Math.round(modelData * 100); text: Math.round(modelData * 100) + "%"; checked: Math.abs(o.scale - modelData) < 0.01; onClicked: o.scale = modelData } } }
            }
            Row {
                spacing: 8
                OmniButton {
                    objectName: "display:apply"; text: qsTr("Applica"); primary: true
                    enabled: o.mode !== o.modelData.currentMode || Math.abs(o.scale - o.modelData.scale) > 0.01
                    onClicked: { page.result = qsTr("Applicazione in corso…"); page.resultKind = 3
                        systemStatus.applyDisplay(o.modelData.name, o.mode !== o.modelData.currentMode ? o.mode : "", Math.abs(o.scale - o.modelData.scale) > 0.01 ? o.scale : 0) }
                }
                OmniButton { text: qsTr("Annulla"); ghost: true; onClicked: { o.mode = o.modelData.currentMode; o.scale = o.modelData.scale } }
            }
        }
    }
    StatusNote { objectName: "display:result"; text: page.result; kind: page.resultKind }
    SettingCard { icon: "settings"; title: qsTr("Più schermi, orientamento, luce notturna"); subtitle: qsTr("Impostazioni avanzate dello schermo di KDE"); clickable: true; onClicked: systemStatus.openSettings("kcm_kscreen")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
}
