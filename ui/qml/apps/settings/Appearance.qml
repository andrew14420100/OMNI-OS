import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Personalizzazione")
    subtitle: qsTr("Tema, colori, sfondo, barra ed effetti. Il tema vale anche per le app KDE (schema di colori OMNI) e per le finestre.")
    property string note: ""
    property int noteKind: 0
    property var wallpapers: []
    function applyScheme(dark) {
        page.note = qsTr("Applicazione del tema…"); page.noteKind = 3
        Sys.run("plasma-apply-colorscheme", [dark ? "OmniScuro" : "OmniChiaro"], (code, out, err) => {
            page.note = code === 0 ? qsTr("Tema applicato a OMNI e alle app KDE") : qsTr("Tema applicato a OMNI; schema di colori KDE non applicato: %1").arg(err || out)
            page.noteKind = code === 0 ? 1 : 2
        })
    }
    function setEffects(level) {
        shellSettings.effects = level
        // KWin: sfocatura e contrasto solo con effetti completi; animazioni di riduzione a icona sempre leggere
        Sys.writeKde("kwinrc", "Plugins", "blurEnabled", level === 2 ? "true" : "false", () =>
            Sys.writeKde("kwinrc", "Plugins", "contrastEnabled", level === 2 ? "true" : "false", () =>
                Sys.writeKde("kwinrc", "Plugins", "magiclampEnabled", level === 2 ? "true" : "false", () =>
                    Sys.dbus("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", [], ok => { page.note = ok ? qsTr("Effetti aggiornati") : qsTr("KWin non ha riletto la configurazione"); page.noteKind = ok ? 1 : 2 }), "bool"), "bool"), "bool")
    }
    Component.onCompleted: wallpapers = omniSystem.listFiles("/usr/share/wallpapers", [".jpg", ".png", ".jpeg"], true, 40).filter(f => f.indexOf("/contents/images/") > 0 && f.indexOf("dark") < 0).slice(0, 12)
    SectionTitle { text: qsTr("Tema") }
    SettingCard {
        objectName: "aspetto:tema"
        icon: Theme.dark ? "moon" : "sun"; title: qsTr("Modalità"); subtitle: Theme.dark ? qsTr("Scuro") : qsTr("Chiaro")
        Row { spacing: 6
            OmniChip { objectName: "aspetto:chiaro"; text: qsTr("Chiaro"); checked: !shellSettings.dark; onClicked: { shellSettings.dark = false; page.applyScheme(false) } }
            OmniChip { objectName: "aspetto:scuro"; text: qsTr("Scuro"); checked: shellSettings.dark; onClicked: { shellSettings.dark = true; page.applyScheme(true) } } }
    }
    SettingCard {
        icon: "palette"; title: qsTr("Colore principale")
        Row { spacing: 8
            Repeater { model: Theme.accents
                delegate: Rectangle { required property var modelData; required property int index
                    width: 28; height: 28; radius: 14; color: Theme.dark ? modelData.dark : modelData.light
                    border.width: shellSettings.accent === index ? 3 : 0; border.color: Theme.textPrimary
                    Accessible.role: Accessible.RadioButton; Accessible.name: modelData.name
                    MouseArea { anchors.fill: parent; onClicked: { shellSettings.accent = index
                        Sys.run("plasma-apply-colorscheme", ["--accent-color", String(modelData.light)]) } } } } }
    }
    SectionTitle { text: qsTr("Sfondo") }
    Flow {
        width: parent.width; spacing: 10
        Rectangle {
            width: 160; height: 90; radius: 8; clip: true
            border.width: shellSettings.wallpaper === "aurora" ? 3 : 1; border.color: shellSettings.wallpaper === "aurora" ? Theme.accent : Theme.outline
            gradient: Gradient { GradientStop { position: 0; color: "#0B0C24" } GradientStop { position: 1; color: "#1F4F6B" } }
            Text { anchors.centerIn: parent; text: "OMNI Aurora"; color: "white"; font.pixelSize: 12; font.family: Theme.fontFamily }
            MouseArea { anchors.fill: parent; onClicked: shellSettings.wallpaper = "aurora" }
        }
        Repeater {
            model: page.wallpapers
            delegate: Image { required property string modelData
                width: 160; height: 90; fillMode: Image.PreserveAspectCrop; asynchronous: true
                source: "file://" + modelData; sourceSize: Qt.size(320, 180)
                Rectangle { anchors.fill: parent; color: "transparent"; radius: 8; border.width: shellSettings.wallpaper === modelData ? 3 : 0; border.color: Theme.accent }
                MouseArea { anchors.fill: parent; onClicked: shellSettings.wallpaper = modelData } }
        }
    }
    SectionTitle { text: qsTr("Barra delle applicazioni e Start") }
    SettingCard {
        objectName: "aspetto:barra"
        icon: "apps"; title: qsTr("Dimensione della barra")
        Row { spacing: 6
            Repeater { model: [[40, qsTr("Compatta")], [48, qsTr("Normale")], [56, qsTr("Grande")]]
                delegate: OmniChip { required property var modelData; objectName: "barra:" + modelData[0]; text: modelData[1]; checked: shellSettings.barSize === modelData[0]; onClicked: shellSettings.barSize = modelData[0] } } }
    }
    SettingCard { icon: "history"; title: qsTr("Mostra le app aperte di recente in Start")
        OmniSwitch { checked: shellSettings.startShowRecent; onToggled: shellSettings.startShowRecent = checked } }
    SectionTitle { text: qsTr("Effetti e animazioni") }
    SettingCard {
        objectName: "aspetto:effetti"
        icon: "layers"; title: qsTr("Effetti visivi")
        subtitle: qsTr("Completi: trasparenze sfocate e animazioni ricche (consigliati con accelerazione 3D). Essenziali: più leggeri.") + (softwareRendering ? qsTr(" Rendering software rilevato.") : "")
        Row { spacing: 6
            Repeater { model: [[0, qsTr("Essenziali")], [1, qsTr("Equilibrati")], [2, qsTr("Completi")]]
                delegate: OmniChip { required property var modelData; text: modelData[1]; checked: shellSettings.effects === modelData[0]; onClicked: page.setEffects(modelData[0]) } } }
    }
    SettingCard {
        icon: "motion"; title: qsTr("Movimento ridotto"); subtitle: qsTr("Riduce le animazioni di OMNI, di KWin e delle app KDE")
        OmniSwitch { checked: shellSettings.reducedMotion; onToggled: { shellSettings.reducedMotion = checked; kwinActions.setSystemReducedMotion(checked) } }
    }
    StatusNote { objectName: "aspetto:nota"; text: page.note; kind: page.noteKind }
}
