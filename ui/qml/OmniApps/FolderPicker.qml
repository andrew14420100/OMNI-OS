import QtQuick
import OmniDesign
// Scelta di una cartella: campo con il percorso e pulsante "Scegli…" che apre il selettore di
// sistema (se il modulo QtQuick.Dialogs non c'è, resta il campo di testo).
Row {
    id: fp
    property string path: ""
    property string dialogTitle: qsTr("Scegli una cartella")
    spacing: 8
    property var dlg: null
    Rectangle { width: 300; height: 34; radius: 6; color: Theme.surfaceSunken; border.color: Theme.outlineStrong
        TextInput { id: field; objectName: "cartella:percorso"; anchors.fill: parent; anchors.margins: 8; text: fp.path; color: Theme.textPrimary; font.pixelSize: 13; clip: true
            onEditingFinished: fp.path = text } }
    OmniButton {
        text: qsTr("Scegli…")
        onClicked: {
            if (!fp.dlg) {
                const c = Qt.createComponent(Qt.resolvedUrl("FolderDialogImpl.qml"))
                if (c.status === Component.Ready) {
                    fp.dlg = c.createObject(fp, { title: fp.dialogTitle })
                    fp.dlg.accepted.connect(() => fp.path = decodeURIComponent(String(fp.dlg.selectedFolder).replace("file://", "")))
                }
            }
            if (fp.dlg) fp.dlg.open(); else field.forceActiveFocus()
        }
    }
}
