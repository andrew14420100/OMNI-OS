import QtQuick
import OmniDesign

// Impostazioni rapide OMNI: ogni controllo agisce sul servizio reale e mostra lo stato
// effettivo; se il sistema o l'hardware non supportano una funzione lo dice chiaramente.
PanelFrame {
    id: qp
    property var session: null
    property var net: session ? session.services.network : null
    property var audio: session ? session.services.audio : null
    property var bt: session ? session.services.bluetooth : null
    property string page: "main"          // main | network | audio | bluetooth | display | system
    width: 400
    height: Math.min(page === "main" ? mainCol.implicitHeight + 48 + 56 : 600, 760)

    function reset() { page = "main" }
    Keys.onEscapePressed: page === "main" ? session.close() : page = "main"

    component QuickTile: Item {
        id: t
        property string icon: "sparkle"
        property string label: ""
        property string sub: ""
        property bool checked: false
        property bool available: true
        property bool arrow: false
        signal toggled()
        signal opened()
        width: 112; height: 76
        opacity: available ? 1 : 0.55
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checked: checked
        Rectangle {
            id: face
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 48; radius: 8
            color: t.checked && t.available ? Theme.accent : (Theme.dark ? "#1E2640" : "#ECEFF6")
            border.color: t.checked && t.available ? "transparent" : Theme.outline
            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 110 } }
            OmniIcon {
                anchors.verticalCenter: parent.verticalCenter
                x: t.arrow ? 22 : (parent.width - width) / 2
                width: 20; height: 20; name: t.icon
                color: t.checked && t.available ? Theme.textOnAccent : Theme.textPrimary
            }
            MouseArea {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: t.arrow ? parent.width * 0.6 : parent.width
                enabled: t.available; hoverEnabled: true
                onClicked: t.toggled()
            }
            Rectangle { visible: t.arrow; x: parent.width * 0.6; width: 1; height: 28; anchors.verticalCenter: parent.verticalCenter; color: t.checked ? Qt.rgba(0, 0, 0, 0.2) : Theme.outline }
            OmniIcon {
                visible: t.arrow
                x: parent.width * 0.8 - 8; anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; name: "chevron-right"
                color: t.checked && t.available ? Theme.textOnAccent : Theme.textSecondary
            }
            MouseArea {
                visible: t.arrow
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: parent.width * 0.4
                onClicked: t.opened()
            }
        }
        Text {
            anchors { top: face.bottom; topMargin: 6; left: parent.left; right: parent.right }
            horizontalAlignment: Text.AlignHCenter
            text: t.sub !== "" ? t.sub : t.label
            color: Theme.textPrimary; font.pixelSize: 11; font.family: Theme.fontFamily; elide: Text.ElideRight
        }
    }

    component SliderRow: Item {
        id: sr
        property string icon: "volume"
        property real value: 0
        property bool available: true
        property string note: ""
        property bool arrow: false
        signal moved(real v)
        signal iconClicked()
        signal opened()
        width: parent ? parent.width : 340
        height: available ? 40 : 40 + noteText.implicitHeight
        OmniIconButton {
            id: ib
            anchors.verticalCenter: parent.verticalCenter
            y: 0; icon: sr.icon; label: sr.icon; iconSize: 18
            enabled: sr.available
            onClicked: sr.iconClicked()
        }
        Item {
            id: track
            anchors { left: ib.right; leftMargin: 8; right: sr.arrow ? arrowBtn.left : parent.right; rightMargin: 8; verticalCenter: ib.verticalCenter }
            height: 24
            opacity: sr.available ? 1 : 0.4
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.outlineStrong }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.min(1, sr.value); height: 4; radius: 2; color: Theme.accent }
            Rectangle {
                x: parent.width * Math.min(1, sr.value) - width / 2; anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; radius: 9; color: Theme.accent
                border.color: Theme.dark ? "#141A2C" : "#FFFFFF"; border.width: 4
            }
            MouseArea {
                anchors.fill: parent; enabled: sr.available
                function at(mx) { return Math.max(0, Math.min(1, mx / width)) }
                onPressed: mouse => sr.moved(at(mouse.x))
                onPositionChanged: mouse => { if (pressed) sr.moved(at(mouse.x)) }
                onWheel: wheel => sr.moved(Math.max(0, Math.min(1, sr.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        OmniIconButton { id: arrowBtn; visible: sr.arrow; anchors { right: parent.right; verticalCenter: ib.verticalCenter } icon: "chevron-right"; label: qsTr("Dispositivi"); iconSize: 16; onClicked: sr.opened() }
        Text {
            id: noteText
            visible: !sr.available
            anchors { left: track.left; right: parent.right; top: track.bottom; topMargin: 2 }
            text: sr.note; wrapMode: Text.WordWrap
            color: Theme.textTertiary; font.pixelSize: 11; font.family: Theme.fontFamily
        }
    }

    // ===== pagina principale =====
    Column {
        id: mainCol
        visible: qp.page === "main"
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 16
        Grid {
            columns: 3; columnSpacing: 12; rowSpacing: 10
            QuickTile {
                objectName: "qs:network"
                icon: qp.session ? qp.session.networkIcon : "globe"
                label: qsTr("Rete")
                sub: qp.session ? qp.session.networkLabel : qsTr("Rete")
                available: qp.net !== null
                checked: qp.net !== null && (qp.net.wirelessAvailable ? qp.net.wirelessEnabled : qp.session.networkConnected)
                arrow: true
                onToggled: { if (qp.net && qp.net.wirelessAvailable) qp.net.setWireless(!qp.net.wirelessEnabled); else qp.page = "network" }
                onOpened: qp.page = "network"
            }
            QuickTile {
                objectName: "qs:bluetooth"
                icon: "bluetooth"; label: qsTr("Bluetooth")
                sub: qp.bt && qp.bt.available ? (qp.bt.powered ? qsTr("Attivo") : qsTr("Bluetooth")) : qsTr("Non disponibile")
                available: qp.bt !== null && qp.bt.available
                checked: qp.bt !== null && qp.bt.powered
                arrow: true
                onToggled: qp.bt.setPowered(!qp.bt.powered)
                onOpened: qp.page = "bluetooth"
            }
            QuickTile {
                objectName: "qs:dnd"
                icon: notificationServer.doNotDisturb ? "bell-off" : "bell"
                label: qsTr("Non disturbare")
                checked: notificationServer.doNotDisturb
                onToggled: notificationServer.doNotDisturb = !notificationServer.doNotDisturb
            }
            QuickTile {
                objectName: "qs:powersaver"
                icon: "leaf"; label: qsTr("Risparmio energia")
                available: systemStatus.powerProfiles.indexOf("power-saver") >= 0
                sub: available ? "" : qsTr("Non disponibile")
                checked: systemStatus.powerProfile === "power-saver"
                onToggled: systemStatus.setPowerProfile(checked ? "balanced" : "power-saver")
            }
            QuickTile {
                objectName: "qs:theme"
                icon: Theme.dark ? "moon" : "sun"; label: Theme.dark ? qsTr("Tema scuro") : qsTr("Tema chiaro")
                checked: Theme.dark
                onToggled: qp.session.setDark(!Theme.dark)
            }
            QuickTile {
                objectName: "qs:motion"
                icon: "motion"; label: qsTr("Movimento ridotto")
                checked: Theme.reducedMotion
                onToggled: qp.session.setReducedMotion(!Theme.reducedMotion)
            }
        }
        SliderRow {
            objectName: "qs:volume"
            icon: qp.audio && qp.audio.muted ? "volume-off" : "volume"
            available: qp.audio !== null && qp.audio.available
            note: qsTr("Nessun dispositivo audio disponibile")
            value: qp.audio ? qp.audio.volume : 0
            arrow: true
            onMoved: v => qp.audio.setVolume(v)
            onIconClicked: qp.audio.toggleMute()
            onOpened: qp.page = "audio"
        }
        SliderRow {
            objectName: "qs:brightness"
            icon: "sun"
            available: systemStatus.brightnessAvailable
            note: systemStatus.brightnessNote
            value: systemStatus.maxBrightness > 0 ? systemStatus.brightness / systemStatus.maxBrightness : 0
            onMoved: v => systemStatus.setBrightness(Math.round(v * systemStatus.maxBrightness))
        }
    }
    // piede della pagina principale
    Rectangle {
        visible: qp.page === "main"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 52; radius: qp.radius
        color: Theme.dark ? "#10162A" : "#F0F2F8"
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.outline }
        Row {
            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 8
            OmniIcon { visible: systemStatus.batteryPresent; width: 18; height: 18; name: "battery"; color: Theme.textPrimary }
            Text {
                visible: systemStatus.batteryPresent
                text: systemStatus.batteryPercent + "%" + (systemStatus.batteryCharging ? qsTr(" in carica") : "")
                color: Theme.textPrimary; font.pixelSize: 12; font.family: Theme.fontFamily
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 4
            OmniIconButton { objectName: "qs:display"; icon: "display"; label: qsTr("Schermo"); iconSize: 18; onClicked: { systemStatus.refreshDisplay(); qp.page = "display" } }
            OmniIconButton { objectName: "qs:system"; icon: "info"; label: qsTr("Sistema"); iconSize: 18; onClicked: { systemStatus.refresh(); qp.page = "system" } }
            OmniIconButton { objectName: "qs:settings"; icon: "settings"; label: qsTr("Impostazioni di sistema"); iconSize: 18; onClicked: { qp.session.close(); systemStatus.openSettings("") } }
        }
    }

    // ===== sottopagine =====
    Loader {
        anchors.fill: parent
        anchors.margins: 16
        active: qp.page !== "main"
        sourceComponent: qp.page === "network" ? networkPage : qp.page === "audio" ? audioPage
                       : qp.page === "bluetooth" ? bluetoothPage : qp.page === "display" ? displayPage : systemPage
    }

    component PageHeader: Row {
        property string title: ""
        spacing: 8
        OmniIconButton { icon: "arrow-left"; label: qsTr("Indietro"); iconSize: 18; onClicked: qp.page = "main" }
        Text { anchors.verticalCenter: parent.verticalCenter; text: parent.title; color: Theme.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold; font.family: Theme.fontFamily }
    }
    component Note: Text {
        width: parent ? parent.width : 300
        wrapMode: Text.WordWrap
        color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily
    }

    Component {
        id: networkPage
        Column {
            spacing: 10
            PageHeader { title: qsTr("Rete") }
            Note { text: qp.net ? qp.session.networkLabel + (qp.net.wirelessAvailable ? "" : qsTr(" · nessuna scheda Wi-Fi (in una macchina virtuale di solito c'è solo la rete cablata virtuale)")) : qsTr("Servizio di rete non disponibile") }
            ListView {
                width: parent.width; height: 380; clip: true; spacing: 4
                model: qp.net ? qp.net.connections : null
                delegate: Item {
                    id: c
                    required property var model
                    readonly property bool active: qp.net.isActivated(model.ConnectionState)
                    readonly property bool busy: qp.net.isActivating(model.ConnectionState)
                    width: ListView.view.width; height: pw.visible ? 96 : 52
                    objectName: "net:" + (model.Name || model.ItemUniqueName)
                    Rectangle { anchors.fill: parent; radius: 8; color: c.active ? Theme.accentSoft : (cm.containsMouse ? Theme.hover : "transparent") }
                    OmniIcon { x: 12; y: 15; width: 20; height: 20; name: qp.net.isWireless(c.model.Type) ? "wifi" : "ethernet"; color: Theme.textPrimary }
                    Column {
                        x: 44; y: 8; width: parent.width - 44 - 110
                        Text { width: parent.width; text: c.model.ItemUniqueName || c.model.Name; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        Text { text: c.active ? qsTr("Connesso") : (c.busy ? qsTr("Connessione…") : (c.model.ConnectionPath ? qsTr("Salvata") : qsTr("Disponibile"))); color: Theme.textSecondary; font.pixelSize: 11; font.family: Theme.fontFamily }
                    }
                    OmniButton {
                        anchors { right: parent.right; rightMargin: 8 } y: 10
                        text: c.active ? qsTr("Disconnetti") : qsTr("Connetti")
                        primary: !c.active
                        onClicked: {
                            if (c.active) qp.net.disconnectFrom(c.model.ConnectionPath, c.model.DevicePath)
                            else if (c.model.ConnectionPath) qp.net.connectTo(c.model.ConnectionPath, c.model.DevicePath, c.model.SpecificPath)
                            else if (qp.net.needsPassword(c.model.SecurityType)) pw.visible = true
                            else qp.net.connectNew(c.model.DevicePath, c.model.SpecificPath, "")
                        }
                    }
                    Row {
                        id: pw
                        visible: false
                        x: 44; y: 54; spacing: 8
                        Rectangle {
                            width: 200; height: 32; radius: 6; color: Theme.surfaceSunken; border.color: Theme.outlineStrong
                            TextInput { id: pwField; anchors.fill: parent; anchors.margins: 8; echoMode: TextInput.Password; color: Theme.textPrimary; font.pixelSize: 13; clip: true }
                        }
                        OmniButton { text: qsTr("Avanti"); primary: true; onClicked: { qp.net.connectNew(c.model.DevicePath, c.model.SpecificPath, pwField.text); pwField.text = ""; pw.visible = false } }
                    }
                    MouseArea { id: cm; anchors.fill: parent; z: -1; hoverEnabled: true }
                }
            }
            Row {
                spacing: 8
                OmniButton { visible: qp.net && qp.net.wirelessAvailable; text: qsTr("Cerca reti"); onClicked: qp.net.scan() }
                OmniButton { text: qsTr("Impostazioni di rete"); onClicked: { qp.session.close(); systemStatus.openSettings("kcm_networkmanagement") } }
            }
        }
    }

    Component {
        id: audioPage
        Column {
            spacing: 8
            PageHeader { title: qsTr("Audio") }
            Text { text: qsTr("Uscita"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily }
            Repeater {
                model: qp.audio ? qp.audio.sinks : null
                delegate: DeviceRow { required property var model; label: model.Description; selected: model.PulseObject ? model.PulseObject.default : false; onPicked: qp.audio.makeDefault(model.PulseObject) }
            }
            Text { text: qsTr("Microfono"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily; topPadding: 6 }
            Repeater {
                model: qp.audio ? qp.audio.sources : null
                delegate: DeviceRow { required property var model; label: model.Description; selected: model.PulseObject ? model.PulseObject.default : false; onPicked: qp.audio.makeDefault(model.PulseObject) }
            }
            SliderRow {
                icon: qp.audio && qp.audio.micMuted ? "mic" : "mic"
                available: qp.audio !== null && qp.audio.source !== null
                note: qsTr("Nessun microfono disponibile")
                value: qp.audio ? qp.audio.micVolume : 0
                onMoved: v => qp.audio.setMicVolume(v)
                onIconClicked: qp.audio.toggleMicMute()
            }
            Text { text: qsTr("App"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily; topPadding: 6 }
            Repeater {
                model: qp.audio ? qp.audio.streams : null
                delegate: Note { required property var model; text: (model.Client ? model.Client.name : model.Name) + " · " + Math.round(model.Volume / qp.audio.normal * 100) + "%" }
            }
            OmniButton { text: qsTr("Impostazioni audio"); onClicked: { qp.session.close(); systemStatus.openSettings("kcm_pulseaudio") } }
        }
    }
    component DeviceRow: Item {
        id: d
        property string label: ""
        property bool selected: false
        signal picked()
        width: parent ? parent.width : 340; height: 40
        Rectangle { anchors.fill: parent; radius: 8; color: d.selected ? Theme.accentSoft : (dm.containsMouse ? Theme.hover : "transparent") }
        OmniIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; name: "check"; visible: d.selected; color: Theme.accent }
        Text { x: 40; width: parent.width - 48; anchors.verticalCenter: parent.verticalCenter; text: d.label; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily; elide: Text.ElideRight }
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; onClicked: d.picked() }
    }

    Component {
        id: bluetoothPage
        Column {
            spacing: 10
            PageHeader { title: qsTr("Bluetooth") }
            Note { text: !qp.bt ? qsTr("Componente Bluetooth non disponibile") : (qp.bt.available ? (qp.bt.powered ? qsTr("Attivo") : qsTr("Disattivato")) : qp.bt.note + qsTr(". In una macchina virtuale serve un adattatore USB assegnato alla VM.")) }
            Row {
                visible: qp.bt !== null && qp.bt.available
                spacing: 8
                OmniButton { text: qp.bt && qp.bt.powered ? qsTr("Disattiva") : qsTr("Attiva"); onClicked: qp.bt.setPowered(!qp.bt.powered) }
                OmniButton { text: qp.bt && qp.bt.discovering ? qsTr("Interrompi ricerca") : qsTr("Cerca dispositivi"); enabled: qp.bt && qp.bt.powered; onClicked: qp.bt.discovering ? qp.bt.stopDiscovery() : qp.bt.startDiscovery() }
            }
            Repeater {
                model: qp.bt && qp.bt.available ? qp.bt.devices : null
                delegate: DeviceRow {
                    required property var model
                    label: model.Name + (model.Connected ? qsTr(" · connesso") : (model.Paired ? qsTr(" · associato") : ""))
                    selected: model.Connected
                    onPicked: qp.bt.toggleDevice(model.Device)
                }
            }
        }
    }

    Component {
        id: displayPage
        Column {
            id: dp
            spacing: 10
            property string result: ""
            Connections { target: systemStatus; function onDisplayApplied(ok, message) { dp.result = (ok ? "✓ " : "✕ ") + message } }
            PageHeader { title: qsTr("Schermo") }
            Note { visible: systemStatus.displayStatus !== ""; text: systemStatus.displayStatus }
            Repeater {
                model: systemStatus.outputs
                delegate: Column {
                    id: o
                    required property var modelData
                    width: dp.width; spacing: 8
                    property string mode: modelData.currentMode
                    property real scale: modelData.scale
                    readonly property var sizes: { const s = []; for (const m of modelData.modes) { const k = m.width + "x" + m.height; if (s.indexOf(k) < 0) s.push(k) } return s }
                    readonly property var rates: { const r = []; const k = o.mode.split("@")[0]; for (const m of modelData.modes) if (m.width + "x" + m.height === k && r.indexOf(Math.round(m.refresh)) < 0) r.push(Math.round(m.refresh)); return r.sort((a, b) => b - a) }
                    Text { text: o.modelData.name + " · " + o.modelData.currentMode + " · " + qsTr("scala") + " " + Math.round(o.modelData.scale * 100) + "%"; color: Theme.textPrimary; font.pixelSize: 13; font.family: Theme.fontFamily }
                    Text { text: qsTr("Risoluzione"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater { model: o.sizes.slice(0, 8); delegate: OmniChip { required property var modelData; text: modelData; checked: o.mode.split("@")[0] === modelData; onClicked: o.mode = modelData + "@" + (o.rates.length ? o.rates[0] : 60) } }
                    }
                    Text { text: qsTr("Frequenza (solo quelle offerte dallo schermo)"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater { model: o.rates; delegate: OmniChip { required property var modelData; text: modelData + " Hz"; checked: o.mode.split("@")[1] == modelData; onClicked: o.mode = o.mode.split("@")[0] + "@" + modelData } }
                    }
                    Text { text: qsTr("Scala"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater { model: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]; delegate: OmniChip { required property var modelData; text: Math.round(modelData * 100) + "%"; checked: Math.abs(o.scale - modelData) < 0.01; onClicked: o.scale = modelData } }
                    }
                    OmniButton {
                        objectName: "display:apply"
                        text: qsTr("Applica"); primary: true
                        enabled: o.mode !== o.modelData.currentMode || Math.abs(o.scale - o.modelData.scale) > 0.01
                        onClicked: { dp.result = qsTr("Applicazione in corso…"); systemStatus.applyDisplay(o.modelData.name, o.mode !== o.modelData.currentMode ? o.mode : "", Math.abs(o.scale - o.modelData.scale) > 0.01 ? o.scale : 0) }
                    }
                }
            }
            Note { visible: dp.result !== ""; text: dp.result }
            OmniButton { text: qsTr("Impostazioni dello schermo"); onClicked: { qp.session.close(); systemStatus.openSettings("kcm_kscreen") } }
        }
    }

    Component {
        id: systemPage
        Column {
            spacing: 10
            PageHeader { title: qsTr("Sistema") }
            Text { text: qsTr("Archiviazione"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily }
            Note {
                text: systemStatus.storage.valid ? qsTr("%1 GB liberi su %2 GB (%3% usato)").arg(systemStatus.storage.freeGb.toFixed(1)).arg(systemStatus.storage.totalGb.toFixed(1)).arg(systemStatus.storage.usedPercent) : qsTr("Spazio non leggibile")
                color: Theme.textPrimary
            }
            Rectangle {
                width: parent.width; height: 6; radius: 3; color: Theme.outlineStrong
                Rectangle { width: parent.width * (systemStatus.storage.usedPercent || 0) / 100; height: 6; radius: 3; color: Theme.accent }
            }
            Text { text: qsTr("Sicurezza"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily; topPadding: 6 }
            Note { text: qsTr("SELinux: %1").arg(systemStatus.security.selinux || "-"); color: Theme.textPrimary }
            Note { text: qsTr("Secure Boot: %1").arg(systemStatus.security.secureBoot || "-"); color: Theme.textPrimary }
            Note { text: qsTr("Firewall: %1").arg(systemStatus.security.firewall || "-"); color: Theme.textPrimary }
            Text { text: qsTr("Energia"); color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.fontFamily; topPadding: 6 }
            Note {
                text: systemStatus.powerProfile !== "" ? qsTr("Profilo energetico: %1").arg(systemStatus.powerProfile) : qsTr("Profili energetici non disponibili su questo sistema")
                color: Theme.textPrimary
            }
            Flow {
                width: parent.width; spacing: 6
                Repeater { model: systemStatus.powerProfiles; delegate: OmniChip { required property var modelData; text: modelData; checked: systemStatus.powerProfile === modelData; onClicked: systemStatus.setPowerProfile(modelData) } }
            }
            Row {
                spacing: 8; topPadding: 6
                OmniButton { text: qsTr("Gestione applicazioni"); onClicked: { qp.session.close(); qp.session.launchById("org.kde.discover.desktop") } }
                OmniButton { text: qsTr("Impostazioni"); onClicked: { qp.session.close(); systemStatus.openSettings("") } }
            }
            Note { text: qsTr("Renderer grafico: %1").arg(rendererName); color: Theme.textTertiary }
        }
    }
}
