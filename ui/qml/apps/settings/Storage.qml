import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Archiviazione")
    subtitle: qsTr("Spazio dei dischi e delle cartelle personali, misurato ora.")
    property var mounts: []
    property var folders: []
    property string trash: ""
    property bool measuring: false
    property string note: ""
    function reload() {
        Sys.run("df", ["-B1", "--output=target,size,used,avail,fstype"], (code, out) => {
            const l = []
            for (const line of out.split("\n").slice(1)) {
                const f = line.trim().split(/\s+/)
                if (f.length < 5 || ["tmpfs", "devtmpfs", "overlay", "squashfs", "efivarfs", "composefs"].indexOf(f[4]) >= 0) continue
                if (["/", "/var", "/boot", "/boot/efi", "/sysroot"].indexOf(f[0]) < 0 && f[0].indexOf("/run/media") !== 0 && f[0].indexOf("/var/home") !== 0) continue
                l.push({ target: f[0], size: Number(f[1]), used: Number(f[2]), avail: Number(f[3]), fs: f[4] })
            }
            page.mounts = l
        })
        page.measuring = true
        const dirs = omniSystem.userDirs()
        Sys.run("du", ["-s", "-b"].concat(dirs).concat([omniSystem.homePath() + "/.local/share/Trash"]), (code, out) => {
            const l = []
            for (const line of out.split("\n")) {
                const t = line.indexOf("\t"); if (t < 0) continue
                const p = line.substring(t + 1), b = Number(line.substring(0, t))
                if (p.endsWith("/Trash")) page.trash = Sys.humanBytes(b)
                else l.push({ path: p, bytes: b })
            }
            page.folders = l.sort((a, b) => b.bytes - a.bytes)
            page.measuring = false
        }, { timeout: 60000 })
    }
    Component.onCompleted: reload()
    SectionTitle { text: qsTr("Dischi") }
    Repeater {
        model: page.mounts
        delegate: SettingCard {
            required property var modelData
            icon: "drive"; title: modelData.target + " (" + modelData.fs + ")"
            subtitle: qsTr("%1 liberi su %2").arg(Sys.humanBytes(modelData.avail)).arg(Sys.humanBytes(modelData.size))
            Rectangle { width: 220; height: 6; radius: 3; color: Theme.outlineStrong
                Rectangle { width: parent.width * (modelData.used / Math.max(1, modelData.size)); height: 6; radius: 3; color: modelData.used / modelData.size > 0.9 ? Theme.danger : Theme.accent } }
        }
    }
    SectionTitle { text: qsTr("Cartelle personali") + (page.measuring ? qsTr(" (misura in corso…)") : "") }
    Repeater {
        model: page.folders
        delegate: SettingCard { required property var modelData; icon: "folder"; title: modelData.path.split("/").pop(); subtitle: modelData.path; clickable: true
            onClicked: Sys.run("gio", ["open", modelData.path])
            Text { text: Sys.humanBytes(modelData.bytes); color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.fontFamily } }
    }
    SettingCard {
        objectName: "storage:trash"
        icon: "close"; title: qsTr("Cestino"); subtitle: page.trash !== "" ? page.trash : qsTr("vuoto")
        OmniButton { text: qsTr("Svuota il cestino…"); enabled: page.trash !== "" && page.trash !== "0 B"; onClicked: confirm.visible = true }
    }
    Row {
        id: confirm; visible: false; spacing: 8
        StatusNote { width: 360; text: qsTr("I file nel cestino verranno eliminati definitivamente. Continuare?"); kind: 2 }
        OmniButton { text: qsTr("Svuota"); primary: true; onClicked: { confirm.visible = false; Sys.run("gio", ["trash", "--empty"], (c, o, e) => { page.note = c === 0 ? qsTr("Cestino svuotato") : e; page.reload() }) } }
        OmniButton { text: qsTr("Annulla"); ghost: true; onClicked: confirm.visible = false }
    }
    StatusNote { text: page.note }
}
