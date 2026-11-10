import QtQuick
import OmniDesign
import OmniApps

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    readonly property var a: services ? services.audio : null
    title: qsTr("Audio")
    subtitle: qsTr("Dispositivi e volumi reali (PipeWire). Le modifiche valgono subito anche nelle impostazioni rapide della barra.")
    StatusNote { visible: !page.a || !page.a.available; text: page.a ? qsTr("Nessun dispositivo audio disponibile") : qsTr("Servizio audio non collegato"); kind: 2 }
    SectionTitle { text: qsTr("Uscita") }
    Repeater {
        model: page.a ? page.a.sinks : null
        delegate: SettingCard {
            required property var model
            icon: "volume"; title: model.Description; subtitle: model.PulseObject && model.PulseObject.default ? qsTr("Dispositivo predefinito") : ""
            clickable: true; onClicked: page.a.makeDefault(model.PulseObject)
            OmniIcon { visible: model.PulseObject && model.PulseObject.default; width: 16; height: 16; name: "check"; color: Theme.accent }
        }
    }
    SettingCard {
        objectName: "audio:volume"
        icon: page.a && page.a.muted ? "volume-off" : "volume"; title: qsTr("Volume"); subtitle: page.a ? Math.round(page.a.volume * 100) + "%" + (page.a.muted ? qsTr(" · disattivato") : "") : ""
        Row { spacing: 8
            AppSlider { objectName: "audio:slider"; width: 260; value: page.a ? page.a.volume : 0; onMoved: v => page.a.setVolume(v) }
            OmniButton { text: page.a && page.a.muted ? qsTr("Riattiva") : qsTr("Disattiva"); onClicked: page.a.toggleMute() } }
    }
    SectionTitle { text: qsTr("Ingresso") }
    Repeater {
        model: page.a ? page.a.sources : null
        delegate: SettingCard {
            required property var model
            icon: "mic"; title: model.Description; subtitle: model.PulseObject && model.PulseObject.default ? qsTr("Microfono predefinito") : ""
            clickable: true; onClicked: page.a.makeDefault(model.PulseObject)
            OmniIcon { visible: model.PulseObject && model.PulseObject.default; width: 16; height: 16; name: "check"; color: Theme.accent }
        }
    }
    SettingCard {
        icon: "mic"; title: qsTr("Volume del microfono"); subtitle: page.a && page.a.source ? Math.round(page.a.micVolume * 100) + "%" : qsTr("Nessun microfono")
        AppSlider { width: 260; enabled: !!(page.a && page.a.source); value: page.a ? page.a.micVolume : 0; onMoved: v => page.a.setMicVolume(v) }
    }
    SectionTitle { text: qsTr("App che riproducono audio") }
    Repeater {
        model: page.a ? page.a.streams : null
        delegate: SettingCard { required property var model; icon: "music"; title: model.Client ? model.Client.name : model.Name; subtitle: Math.round(model.Volume / page.a.normal * 100) + "%" }
    }
    SettingCard { icon: "settings"; title: qsTr("Impostazioni audio avanzate"); subtitle: qsTr("Profili delle schede e configurazione avanzata (KDE)"); clickable: true; onClicked: systemStatus.openSettings("kcm_pulseaudio")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
}
