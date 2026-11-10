import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Ora e lingua")
    subtitle: qsTr("Data, ora e fuso orario (systemd-timedated), lingua e formati. Le modifiche di sistema chiedono l'autorizzazione.")
    property var td: ({})
    property var zones: []
    property string filter: ""
    property string lang: ""
    property string formats: ""
    property string note: ""
    property int noteKind: 0
    readonly property string tdsvc: "org.freedesktop.timedate1"
    function reload() {
        Sys.dbus("system", tdsvc, "/org/freedesktop/timedate1", "org.freedesktop.DBus.Properties", "GetAll", ["s:" + tdsvc], (ok, p) => { if (ok) page.td = p })
        Sys.readKde("plasma-localerc", "Translations", "LANGUAGE", "", v => page.lang = v)
        Sys.readKde("plasma-localerc", "Formats", "LANG", "", v => page.formats = v)
    }
    function done(label) { return (ok, r, err) => { page.note = ok ? qsTr("%1 aggiornato").arg(label) : qsTr("%1 non aggiornato: %2").arg(label).arg(err); page.noteKind = ok ? 1 : 2; page.reload() } }
    Component.onCompleted: { reload(); Sys.run("timedatectl", ["list-timezones"], (c, o) => page.zones = o.split("\n").filter(z => z)) }
    Timer { running: true; repeat: true; interval: 1000; onTriggered: clock.text = Qt.formatDateTime(new Date(), "dddd d MMMM yyyy · HH:mm:ss") }
    SettingCard { icon: "calendar"; title: qsTr("Data e ora attuali"); Text { id: clock; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily } }
    SettingCard {
        objectName: "ora:ntp"
        icon: "globe"; title: qsTr("Imposta l'ora automaticamente"); subtitle: page.td.CanNTP === false ? qsTr("Sincronizzazione non disponibile") : (page.td.NTPSynchronized ? qsTr("Sincronizzata") : qsTr("Non sincronizzata"))
        OmniSwitch { checked: !!page.td.NTP; enabled: page.td.CanNTP !== false
            onToggled: Sys.dbus("system", page.tdsvc, "/org/freedesktop/timedate1", page.tdsvc, "SetNTP", ["b:" + checked, "b:true"], page.done(qsTr("Sincronizzazione")), true) }
    }
    SettingCard {
        objectName: "ora:fuso"
        icon: "globe"; title: qsTr("Fuso orario"); subtitle: page.td.Timezone || ""
        height: 64 + (search.text !== "" ? 210 : 40)
        Column { width: 360; spacing: 6
            Rectangle { width: 360; height: 34; radius: 6; color: Theme.surfaceSunken; border.color: Theme.outlineStrong
                TextInput { id: search; objectName: "ora:cerca"; anchors.fill: parent; anchors.margins: 8; color: Theme.textPrimary; font.pixelSize: 13; clip: true
                    Text { visible: !parent.text; text: qsTr("Cerca una città (es. Rome)"); color: Theme.textTertiary; font.pixelSize: 13 } } }
            ListView { visible: search.text !== ""; width: 360; height: 200; clip: true
                model: page.zones.filter(z => z.toLowerCase().indexOf(search.text.toLowerCase()) >= 0).slice(0, 50)
                delegate: Rectangle { required property string modelData; width: 360; height: 30; color: zm.containsMouse ? Theme.hover : "transparent"; radius: 4
                    objectName: "fuso:" + modelData
                    Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.textPrimary; font.pixelSize: 13 }
                    MouseArea { id: zm; anchors.fill: parent; hoverEnabled: true
                        onClicked: { search.text = ""; Sys.dbus("system", page.tdsvc, "/org/freedesktop/timedate1", page.tdsvc, "SetTimezone", ["s:" + modelData, "b:true"], page.done(qsTr("Fuso orario")), true) } } } } }
    }
    SectionTitle { text: qsTr("Lingua e formati") }
    SettingCard {
        icon: "globe"; title: qsTr("Lingua dell'interfaccia delle app"); subtitle: (page.lang || qsTr("quella del sistema")) + qsTr(" · vale dal prossimo accesso")
        Row { spacing: 6; Repeater { model: [["it", "Italiano"], ["en_US", "English"], ["de", "Deutsch"], ["fr", "Français"], ["es", "Español"]]
            delegate: OmniChip { required property var modelData; text: modelData[1]; checked: page.lang === modelData[0]; onClicked: Sys.writeKde("plasma-localerc", "Translations", "LANGUAGE", modelData[0], () => page.reload()) } } }
    }
    SettingCard {
        icon: "calendar"; title: qsTr("Formati di data, ora e numeri"); subtitle: (page.formats || qsTr("quelli del sistema")) + qsTr(" · vale dal prossimo accesso")
        Row { spacing: 6; Repeater { model: [["it_IT.UTF-8", "Italia"], ["en_US.UTF-8", "USA"], ["en_GB.UTF-8", "Regno Unito"], ["de_DE.UTF-8", "Germania"]]
            delegate: OmniChip { required property var modelData; text: modelData[1]; checked: page.formats === modelData[0]; onClicked: Sys.writeKde("plasma-localerc", "Formats", "LANG", modelData[0], () => page.reload()) } } }
    }
    StatusNote { objectName: "ora:nota"; text: page.note; kind: page.noteKind }
}
