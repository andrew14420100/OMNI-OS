import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Mouse, tastiera e touchpad")
    subtitle: qsTr("Dispositivi di input reali gestiti da KWin: le modifiche valgono subito e KWin le conserva.")
    property var devices: []
    property string layouts: ""
    property int repeatDelay: 0
    property int repeatRate: 0
    property string note: ""
    readonly property string base: "/org/kde/KWin/InputDevice"
    readonly property string iface: "org.kde.KWin.InputDevice"
    function loadDevice(sys) {
        Sys.dbus("session", "org.kde.KWin", base + "/" + sys, "org.freedesktop.DBus.Properties", "GetAll", ["s:" + iface], (ok, p) => {
            if (!ok || !p) return
            if (!(p.pointer || p.touchpad || p.keyboard) || p.name.indexOf("QEMU") >= 0 && !p.pointer && !p.keyboard) return
            const l = page.devices.filter(d => d.sys !== sys)
            l.push(Object.assign({ sys: sys }, p))
            page.devices = l.sort((a, b) => (b.pointer || b.touchpad ? 1 : 0) - (a.pointer || a.touchpad ? 1 : 0))
        })
    }
    function reload() {
        page.devices = []
        Sys.prop("session", "org.kde.KWin", base, "org.kde.KWin.InputDeviceManager", "devicesSysNames", (ok, names) => { if (ok && names) for (const n of names) loadDevice(n) })
        Sys.readKde("kxkbrc", "Layout", "LayoutList", "", v => page.layouts = v)
        Sys.readKde("kcminputrc", "Keyboard", "RepeatDelay", 600, v => page.repeatDelay = Number(v))
        Sys.readKde("kcminputrc", "Keyboard", "RepeatRate", 25, v => page.repeatRate = Number(v))
    }
    function setProp(sys, name, typed) {
        Sys.dbus("session", "org.kde.KWin", base + "/" + sys, "org.freedesktop.DBus.Properties", "Set", ["s:" + iface, "s:" + name, "v:" + typed], (ok, r, err) => {
            page.note = ok ? "" : qsTr("Impostazione non applicata: %1").arg(err); loadDevice(sys) })
    }
    Component.onCompleted: reload()
    SectionTitle { text: qsTr("Mouse e touchpad") }
    Repeater {
        model: page.devices.filter(d => d.pointer || d.touchpad)
        delegate: Column {
            id: dev
            required property var modelData
            width: parent.width; spacing: 6
            SettingCard { icon: "tool"; title: dev.modelData.name; subtitle: dev.modelData.touchpad ? qsTr("Touchpad") : qsTr("Mouse / dispositivo di puntamento") }
            SettingCard {
                visible: dev.modelData.supportsPointerAcceleration === true
                objectName: "input:velocita"
                title: qsTr("Velocità del puntatore"); subtitle: Math.round(((dev.modelData.pointerAcceleration || 0) + 1) * 50) + "%"
                AppSlider { width: 260; value: ((dev.modelData.pointerAcceleration || 0) + 1) / 2; onMoved: v => page.setProp(dev.modelData.sys, "pointerAcceleration", "d:" + (v * 2 - 1).toFixed(2)) }
            }
            SettingCard { visible: dev.modelData.supportsNaturalScroll === true; title: qsTr("Scorrimento naturale"); subtitle: qsTr("Il contenuto segue il movimento delle dita")
                OmniSwitch { checked: !!dev.modelData.naturalScroll; onToggled: page.setProp(dev.modelData.sys, "naturalScroll", "b:" + checked) } }
            SettingCard { visible: dev.modelData.supportsLeftHanded === true; title: qsTr("Mano sinistra"); subtitle: qsTr("Scambia i pulsanti sinistro e destro")
                OmniSwitch { checked: !!dev.modelData.leftHanded; onToggled: page.setProp(dev.modelData.sys, "leftHanded", "b:" + checked) } }
            SettingCard { visible: dev.modelData.tapFingerCount > 0; title: qsTr("Tocco per fare clic")
                OmniSwitch { checked: !!dev.modelData.tapToClick; onToggled: page.setProp(dev.modelData.sys, "tapToClick", "b:" + checked) } }
        }
    }
    StatusNote { visible: page.devices.filter(d => d.pointer || d.touchpad).length === 0; text: qsTr("Nessun mouse o touchpad configurabile rilevato") }
    SectionTitle { text: qsTr("Tastiera") }
    SettingCard {
        icon: "tool"; title: qsTr("Layout di tastiera"); subtitle: page.layouts !== "" ? page.layouts : qsTr("Quello predefinito del sistema")
        Row { spacing: 6
            Repeater { model: [["it", qsTr("Italiano")], ["us", qsTr("Inglese (USA)")], ["it,us", qsTr("Italiano + USA")]]
                delegate: OmniChip { required property var modelData; text: modelData[1]; checked: page.layouts === modelData[0]
                    onClicked: Sys.writeKde("kxkbrc", "Layout", "LayoutList", modelData[0], ok => {
                        Sys.writeKde("kxkbrc", "Layout", "Use", "true", () => { omniSystem.reloadKeyboardConfig(); page.reload() }, "bool") }) } } }
    }
    SettingCard {
        title: qsTr("Ritardo della ripetizione"); subtitle: page.repeatDelay + " ms"
        Row { spacing: 6; Repeater { model: [250, 400, 600]; delegate: OmniChip { required property var modelData; text: modelData + " ms"; checked: page.repeatDelay === modelData
            onClicked: Sys.writeKde("kcminputrc", "Keyboard", "RepeatDelay", modelData, () => { Sys.dbus("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", []); page.reload() }) } } }
    }
    StatusNote { text: page.note; kind: 2 }
    SettingCard { icon: "settings"; title: qsTr("Opzioni avanzate di tastiera e mouse"); subtitle: qsTr("Scorciatoie, varianti del layout, accelerazione personalizzata (KDE)"); clickable: true; onClicked: systemStatus.openSettings("kcm_keyboard")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
}
