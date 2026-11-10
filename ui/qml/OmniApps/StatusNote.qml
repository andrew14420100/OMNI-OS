import QtQuick
import OmniDesign
// Esito reale di un'operazione o limite dichiarato (nessun esito supposto).
Text {
    property int kind: 0          // 0 informazione, 1 riuscito, 2 errore, 3 in corso
    width: parent ? parent.width : 400
    visible: text !== ""
    wrapMode: Text.WordWrap
    color: kind === 1 ? Theme.success : kind === 2 ? Theme.danger : kind === 3 ? Theme.accent : Theme.textSecondary
    font.pixelSize: 12; font.family: Theme.fontFamily
}
