import QtQuick
import org.kde.plasma.private.volume

// Audio REALE tramite PipeWire (interfaccia PulseAudio di plasma-pa): volume, muto,
// dispositivo di uscita e microfono predefiniti, flussi delle applicazioni.
QtObject {
    id: root
    readonly property bool available: PreferredDevice.sink !== null && PreferredDevice.sink !== undefined
    readonly property var sink: PreferredDevice.sink
    readonly property var source: PreferredDevice.source
    readonly property real normal: PulseAudio.NormalVolume
    readonly property real volume: sink ? sink.volume / normal : 0           // 0..1 (oltre 1 = amplificato)
    readonly property bool muted: sink ? sink.muted : true
    readonly property string deviceName: sink ? (sink.description || sink.name) : ""
    readonly property real micVolume: source ? source.volume / normal : 0
    readonly property bool micMuted: source ? source.muted : true
    property SinkModel sinks: SinkModel {}
    property SourceModel sources: SourceModel {}
    property SinkInputModel streams: SinkInputModel {}

    function setVolume(v) { if (sink) { sink.volume = Math.round(Math.max(0, Math.min(1, v)) * normal); if (v > 0 && sink.muted) sink.muted = false } }
    function toggleMute() { if (sink) sink.muted = !sink.muted }
    function setMicVolume(v) { if (source) source.volume = Math.round(Math.max(0, Math.min(1, v)) * normal) }
    function toggleMicMute() { if (source) source.muted = !source.muted }
    // oggetto PulseObject di una riga dei modelli: diventa il dispositivo predefinito
    function makeDefault(pulseObject) { if (pulseObject) pulseObject.default = true }
}
