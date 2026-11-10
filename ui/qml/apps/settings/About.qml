import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Informazioni")
    property var info: ({})
    function kv(text) { const m = {}; for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.substring(0, i)] = l.substring(i + 1).replace(/^"|"$/g, "") } return m }
    Component.onCompleted: {
        const b = kv(omniSystem.readFile("/usr/lib/omni-os/build-info")), r = kv(omniSystem.readFile("/etc/os-release"))
        const mem = (omniSystem.readFile("/proc/meminfo").match(/MemTotal:\s+(\d+)/) || [0, 0])[1]
        const up = Number((omniSystem.readFile("/proc/uptime").split(" ")[0]) || 0)
        let gpu = ""
        for (let i = 0; i < 4 && !gpu; ++i) { const u = omniSystem.readFile("/sys/class/drm/card" + i + "/device/uevent"); const d = (u.match(/DRIVER=(.*)/) || [])[1]; if (d) gpu = d }
        info = { version: (b.OMNI_OS_VERSION || "?"), stage: b.OMNI_OS_STAGE || "", base: r.PRETTY_NAME || "", mem: Sys.humanBytes(Number(mem) * 1024), uptime: Math.floor(up / 3600) + " h " + Math.floor((up % 3600) / 60) + " min", gpu: gpu }
        Sys.run("uname", ["-r"], (c, o) => info = Object.assign({}, info, { kernel: o.trim() }))
        Sys.run("lscpu", [], (c, o) => info = Object.assign({}, info, { cpu: ((o.match(/Model name:\s*(.*)/) || [])[1] || "?") + " · " + ((o.match(/^CPU\(s\):\s*(\d+)/m) || [])[1] || "?") + " CPU" }))
        Sys.run("hostnamectl", ["--static"], (c, o) => info = Object.assign({}, info, { host: o.trim() }))
        Sys.run("rpm-ostree", ["status", "--booted", "--json"], (c, o) => { try { const d = JSON.parse(o).deployments[0]; info = Object.assign({}, info, { deploy: (d.version || "") + " · " + (d.checksum || "").substring(0, 12) }) } catch (e) {} })
    }
    SettingCard { icon: "info"; title: "OMNI OS " + (page.info.version || ""); subtitle: page.info.stage || "" }
    SettingCard { icon: "layers"; title: qsTr("Base"); subtitle: (page.info.base || "") + (page.info.deploy ? " · deployment " + page.info.deploy : "") }
    SettingCard { icon: "cpu"; title: qsTr("Processore"); subtitle: page.info.cpu || "…" }
    SettingCard { icon: "drive"; title: qsTr("Memoria"); subtitle: page.info.mem || "…" }
    SettingCard { icon: "display"; title: qsTr("Grafica"); subtitle: (page.info.gpu ? qsTr("driver %1").arg(page.info.gpu) : qsTr("non rilevata")) + (page.info.gpu === "vmwgfx" || page.info.gpu === "virtio-pci" || page.info.gpu === "virtio_gpu" ? qsTr(" · scheda virtuale della macchina virtuale (non la GPU fisica)") : "") }
    SettingCard { icon: "settings"; title: qsTr("Kernel"); subtitle: page.info.kernel || "…" }
    SettingCard { icon: "user"; title: qsTr("Nome del dispositivo"); subtitle: page.info.host || "…" }
    SettingCard { icon: "history"; title: qsTr("Acceso da"); subtitle: page.info.uptime || "" }
}
