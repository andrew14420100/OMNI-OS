import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Privacy e sicurezza")
    subtitle: qsTr("Stato reale delle protezioni del sistema, blocco dello schermo e autorizzazioni delle app Flatpak.")
    property string fw: ""
    property string zone: ""
    property bool autolock: true
    property bool lockResume: true
    property var perms: []
    property string note: ""
    function reload() {
        Sys.run("firewall-cmd", ["--state"], (c, o, e) => page.fw = c === 0 ? o.trim() : (o.trim() || e.trim() || qsTr("non attivo")))
        Sys.run("firewall-cmd", ["--get-default-zone"], (c, o) => page.zone = c === 0 ? o.trim() : "")
        Sys.readKde("kscreenlockerrc", "Daemon", "Autolock", "true", v => page.autolock = v === "true")
        Sys.readKde("kscreenlockerrc", "Daemon", "LockOnResume", "true", v => page.lockResume = v === "true")
        Sys.run("flatpak", ["permissions"], (c, o) => {
            const l = []
            for (const line of o.split("\n").slice(1)) { const f = line.split("\t").map(x => x.trim()); if (f.length >= 4 && f[2]) l.push({ table: f[0], object: f[1], app: f[2], perm: f[3] }) }
            page.perms = l
        })
        systemStatus.refresh()
    }
    Component.onCompleted: reload()
    SectionTitle { text: qsTr("Protezioni del sistema") }
    SettingCard { objectName: "privacy:firewall"; icon: "shield"; title: qsTr("Firewall"); subtitle: page.fw === "running" ? qsTr("Attivo (firewalld) · zona %1").arg(page.zone) : qsTr("Stato: %1").arg(page.fw || "…"); warning: page.fw !== "" && page.fw !== "running" }
    SettingCard { icon: "shield"; title: "SELinux"; subtitle: systemStatus.security.selinux || "…" }
    SettingCard { icon: "lock"; title: "Secure Boot"; subtitle: (systemStatus.security.secureBoot || "…") + qsTr(" (in una VM dipende dall'impostazione della VM)") }
    SettingCard { icon: "restart"; title: qsTr("Sistema atomico"); subtitle: qsTr("I file di sistema sono in sola lettura e ogni aggiornamento si può annullare (vedi Aggiornamenti)") }
    SectionTitle { text: qsTr("Blocco dello schermo") }
    SettingCard { title: qsTr("Blocca automaticamente quando inattivo")
        OmniSwitch { checked: page.autolock; onToggled: Sys.writeKde("kscreenlockerrc", "Daemon", "Autolock", checked, () => page.reload(), "bool") } }
    SettingCard { title: qsTr("Blocca alla ripresa dalla sospensione")
        OmniSwitch { checked: page.lockResume; onToggled: Sys.writeKde("kscreenlockerrc", "Daemon", "LockOnResume", checked, () => page.reload(), "bool") } }
    SectionTitle { text: qsTr("Autorizzazioni delle app (Flatpak)") }
    StatusNote { visible: page.perms.length === 0; text: qsTr("Nessuna autorizzazione concessa ad app Flatpak") }
    Repeater {
        model: page.perms
        delegate: SettingCard { required property var modelData; icon: "eye"; title: modelData.app; subtitle: modelData.table + " · " + modelData.object + " · " + modelData.perm
            OmniButton { text: qsTr("Revoca"); onClicked: Sys.run("flatpak", ["permission-remove", modelData.table, modelData.object, modelData.app], (c, o, e) => { page.note = c === 0 ? qsTr("Autorizzazione revocata") : e; page.reload() }) } }
    }
    SettingCard { icon: "lock"; title: qsTr("Password salvate (portachiavi)"); subtitle: qsTr("Le password di Wi-Fi e app sono nel portachiavi cifrato di KDE"); clickable: true; onClicked: Sys.run("gio", ["launch", "/usr/share/applications/org.kde.kwalletmanager.desktop"], (c, o, e) => { if (c !== 0) page.note = qsTr("Gestore del portachiavi non installato") })
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
    StatusNote { text: page.note }
}
