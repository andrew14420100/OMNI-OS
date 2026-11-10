import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Energia e batteria")
    subtitle: qsTr("Profilo energetico, spegnimento dello schermo e sospensione (PowerDevil). I valori mostrati sono quelli letti dalla configurazione.")
    property int screenOffMin: -1
    property int suspendMin: -1
    property int lockMin: -1
    property string note: ""
    property int noteKind: 0
    function reload() {
        Sys.readKde("powerdevilrc", ["AC", "Display"], "TurnOffDisplayIdleTimeoutSec", 600, v => page.screenOffMin = Math.round(Number(v) / 60))
        Sys.readKde("powerdevilrc", ["AC", "SuspendAndShutdown"], "AutoSuspendIdleTimeoutSec", 900, v => page.suspendMin = Math.round(Number(v) / 60))
        Sys.readKde("kscreenlockerrc", "Daemon", "Timeout", 5, v => page.lockMin = Number(v))
    }
    function save(file, group, key, value, label) {
        Sys.writeKde(file, group, key, value, (ok, err) => {
            if (!ok) { page.note = qsTr("%1 non salvato: %2").arg(label).arg(err); page.noteKind = 2; return }
            // PowerDevil rilegge la configurazione; poi si rilegge il valore effettivo
            Sys.dbus("session", "org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement", "org.kde.Solid.PowerManagement", "refreshStatus", [], () => {
                page.reload(); page.note = qsTr("%1 aggiornato").arg(label); page.noteKind = 1 })
        })
    }
    Component.onCompleted: { reload(); systemStatus.refresh() }
    SettingCard {
        icon: "leaf"; title: qsTr("Profilo energetico")
        subtitle: systemStatus.powerProfiles.length ? qsTr("Attuale: %1").arg(systemStatus.powerProfile) : qsTr("Profili energetici non disponibili su questo sistema")
        Row { spacing: 6
            Repeater { model: systemStatus.powerProfiles; delegate: OmniChip { required property var modelData; objectName: "power:" + modelData
                text: modelData === "power-saver" ? qsTr("Risparmio") : modelData === "balanced" ? qsTr("Bilanciato") : modelData === "performance" ? qsTr("Prestazioni") : modelData
                checked: systemStatus.powerProfile === modelData; onClicked: systemStatus.setPowerProfile(modelData) } } }
    }
    SettingCard {
        icon: "battery"; title: qsTr("Batteria")
        subtitle: systemStatus.batteryPresent ? systemStatus.batteryPercent + "%" + (systemStatus.batteryCharging ? qsTr(" · in carica") : "") : qsTr("Nessuna batteria (computer fisso o macchina virtuale)")
    }
    component Minutes: Row {
        id: mr
        property int value: -1
        property var options: []
        signal picked(int minutes)
        spacing: 6
        Repeater { model: mr.options; delegate: OmniChip { required property var modelData; text: modelData === 0 ? qsTr("Mai") : modelData + " min"; checked: mr.value === modelData; onClicked: mr.picked(modelData) } }
    }
    SettingCard {
        objectName: "power:screenoff"
        icon: "display"; title: qsTr("Spegni lo schermo dopo"); subtitle: page.screenOffMin < 0 ? qsTr("lettura…") : ""
        Minutes { value: page.screenOffMin; options: [5, 10, 15, 30]; onPicked: m => page.save("powerdevilrc", ["AC", "Display"], "TurnOffDisplayIdleTimeoutSec", m * 60, qsTr("Spegnimento dello schermo")) }
    }
    SettingCard {
        icon: "moon"; title: qsTr("Sospendi dopo"); subtitle: sessionActions.canSuspend ? "" : qsTr("La sospensione non è supportata da questo sistema")
        Minutes { value: page.suspendMin; options: [15, 30, 60]; enabled: sessionActions.canSuspend; onPicked: m => page.save("powerdevilrc", ["AC", "SuspendAndShutdown"], "AutoSuspendIdleTimeoutSec", m * 60, qsTr("Sospensione automatica")) }
    }
    SettingCard {
        objectName: "power:lock"
        icon: "lock"; title: qsTr("Blocca lo schermo dopo")
        Minutes { value: page.lockMin; options: [1, 5, 10, 15]; onPicked: m => page.save("kscreenlockerrc", "Daemon", "Timeout", m, qsTr("Blocco dello schermo")) }
    }
    StatusNote { objectName: "power:note"; text: page.note; kind: page.noteKind }
    SettingCard { icon: "settings"; title: qsTr("Impostazioni energetiche avanzate"); subtitle: qsTr("Azioni del pulsante di accensione, coperchio, profili per batteria (KDE)"); clickable: true; onClicked: systemStatus.openSettings("kcm_powerdevilprofilesconfig")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
}
