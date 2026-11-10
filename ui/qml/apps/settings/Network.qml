import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    readonly property var n: services ? services.network : null
    title: qsTr("Rete e Internet")
    subtitle: qsTr("Connessioni reali di NetworkManager. Le password restano al portachiavi di sistema.")
    property var ip: ({})
    function loadIp() {
        const NM = "org.freedesktop.NetworkManager"
        Sys.prop("system", NM, "/org/freedesktop/NetworkManager", NM, "PrimaryConnection", (ok, ac) => {
            if (!ok || !ac || ac === "/") { page.ip = {}; return }
            Sys.prop("system", NM, ac, NM + ".Connection.Active", "Ip4Config", (ok2, cfg) => {
                if (!ok2 || !cfg || cfg === "/") return
                Sys.prop("system", NM, cfg, NM + ".IP4Config", "AddressData", (ok3, a) => { if (ok3 && a && a.length) page.ip = Object.assign({}, page.ip, { addr: a[0].address + "/" + a[0].prefix }) })
                Sys.prop("system", NM, cfg, NM + ".IP4Config", "Gateway", (ok4, g) => { if (ok4) page.ip = Object.assign({}, page.ip, { gw: g }) })
                Sys.prop("system", NM, cfg, NM + ".IP4Config", "NameserverData", (ok5, d) => { if (ok5 && d) page.ip = Object.assign({}, page.ip, { dns: d.map(x => x.address).join(", ") }) })
            })
        })
    }
    Component.onCompleted: { systemStatus.refreshNetwork(); loadIp() }
    Connections { target: systemStatus; function onNetworkChanged() { page.loadIp() } }
    SettingCard {
        objectName: "net:stato"
        icon: systemStatus.networkType === "wifi" ? "wifi" : systemStatus.networkConnected ? "ethernet" : "network-off"
        title: systemStatus.networkConnected ? (systemStatus.networkName || qsTr("Connesso")) : qsTr("Non connesso")
        subtitle: [page.ip.addr ? "IPv4 " + page.ip.addr : "", page.ip.gw ? qsTr("gateway ") + page.ip.gw : "", page.ip.dns ? "DNS " + page.ip.dns : ""].filter(x => x).join(" · ")
    }
    SettingCard {
        icon: "wifi"; title: "Wi-Fi"
        subtitle: !page.n ? qsTr("Servizio di rete non collegato") : page.n.wirelessAvailable ? (page.n.wirelessEnabled ? qsTr("Attivo") : qsTr("Disattivato")) : qsTr("Nessuna scheda Wi-Fi (in una macchina virtuale di solito c'è solo la rete cablata virtuale)")
        OmniSwitch { visible: page.n && page.n.wirelessAvailable; checked: page.n ? page.n.wirelessEnabled : false; onToggled: page.n.setWireless(checked) }
    }
    SectionTitle { text: qsTr("Connessioni") }
    Repeater {
        model: page.n ? page.n.connections : null
        delegate: SettingCard {
            id: c
            required property var model
            readonly property bool active: page.n.isActivated(model.ConnectionState)
            objectName: "net:" + (model.ItemUniqueName || model.Name)
            icon: page.n.isWireless(model.Type) ? "wifi" : "ethernet"
            title: model.ItemUniqueName || model.Name
            subtitle: c.active ? qsTr("Connesso") : page.n.isActivating(model.ConnectionState) ? qsTr("Connessione…") : (model.ConnectionPath ? qsTr("Salvata") : qsTr("Disponibile"))
            OmniButton {
                text: c.active ? qsTr("Disconnetti") : qsTr("Connetti"); primary: !c.active
                onClicked: c.active ? page.n.disconnectFrom(c.model.ConnectionPath, c.model.DevicePath)
                                    : (c.model.ConnectionPath ? page.n.connectTo(c.model.ConnectionPath, c.model.DevicePath, c.model.SpecificPath)
                                                              : page.n.connectNew(c.model.DevicePath, c.model.SpecificPath, ""))
            }
        }
    }
    SettingCard { icon: "settings"; title: qsTr("Impostazioni di rete avanzate"); subtitle: qsTr("IP statico, DNS, VPN, proxy (KDE)"); clickable: true; onClicked: systemStatus.openSettings("kcm_networkmanagement")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
}
