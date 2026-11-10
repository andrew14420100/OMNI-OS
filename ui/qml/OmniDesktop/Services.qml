import QtQuick

// Collegamento ai servizi reali del sistema. Ogni adattatore è un file separato che importa
// il componente KDE corrispondente: se il componente manca, il servizio risulta "non
// disponibile" (con il motivo) invece di bloccare l'interfaccia o simulare un esito.
// Le finestre servono subito; rete, audio e Bluetooth si caricano dopo il primo fotogramma.
QtObject {
    id: svc
    property var tasks: null
    property var audio: null
    property var network: null
    property var bluetooth: null
    property var errors: ({})
    property bool late: false

    function load(file) {
        const c = Qt.createComponent(Qt.resolvedUrl("backends/" + file), Component.PreferSynchronous)
        if (c.status === Component.Ready) {
            const o = c.createObject(svc)
            if (o) { console.info("servizio collegato: " + file); return o }
        }
        const e = Object.assign({}, errors)
        e[file] = c.errorString().trim()
        errors = e
        console.warn("servizio NON disponibile: " + file + ": " + c.errorString().trim())
        return null
    }
    function loadEarly() { if (!tasks) tasks = load("TasksKde.qml") }
    function loadLate() {
        if (late) return
        late = true
        audio = load("AudioKde.qml")
        network = load("NetworkKde.qml")
        bluetooth = load("BluetoothKde.qml")
    }
}
