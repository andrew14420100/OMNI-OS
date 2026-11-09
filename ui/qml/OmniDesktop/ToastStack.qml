import QtQuick
import OmniDesign

// Fumetti delle notifiche nuove (in basso a destra, sopra la barra). Scadono dopo il tempo
// richiesto dall'app (o 6 s) e restano nel centro notifiche. Con "Non disturbare" non
// compaiono (tranne le urgenti: lo decide il server).
Column {
    id: stack
    property var ids: []
    signal openCenter()
    spacing: 8
    width: 380
    function add(id) { if (ids.indexOf(id) < 0) ids = [id].concat(ids).slice(0, 3) }
    function remove(id) { ids = ids.filter(x => x !== id) }
    Connections { target: notificationServer; function onPopupRequested(id) { stack.add(id) } }
    Repeater {
        model: notificationServer
        delegate: NoteCard {
            id: t
            required property var model
            readonly property bool shownHere: stack.ids.indexOf(model.notificationId) >= 0 && model.popup
            visible: shownHere
            height: shownHere ? implicitHeight : 0
            width: stack.width
            toast: true
            note: model
            onClosed: { stack.remove(model.notificationId); notificationServer.dismiss(model.notificationId) }
            Timer {
                running: t.shownHere && t.model.urgency !== 2 && t.model.timeout !== 0 && !hover.containsMouse
                interval: t.model.timeout > 0 ? t.model.timeout : notificationServer.defaultTimeout()
                onTriggered: { stack.remove(t.model.notificationId); notificationServer.popupTimedOut(t.model.notificationId) }
            }
            HoverHandler { id: hover }
            TapHandler { onTapped: { stack.remove(t.model.notificationId); notificationServer.hidePopup(t.model.notificationId); stack.openCenter() } }
        }
    }
}
