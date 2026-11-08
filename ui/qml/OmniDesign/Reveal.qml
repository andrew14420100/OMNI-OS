import QtQuick

// Contenitore con ingresso animato (dissolvenza + leggero scorrimento), ritardabile per
// creare sequenze sfalsate. Con "movimento ridotto" il contenuto compare subito.
Item {
    id: root
    property bool shown: false
    property int delay: 0
    property real distance: 12
    default property alias content: holder.data
    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height
    Item {
        id: holder
        width: root.width; height: root.height
        opacity: 0
        transform: Translate { id: tr; y: root.distance }
    }
    onShownChanged: run()
    Component.onCompleted: if (shown) run()
    function run() {
        anim.stop()
        if (shown && Theme.durationNormal > 0) { holder.opacity = 0; tr.y = distance; anim.start() }
        else { holder.opacity = shown ? 1 : 0; tr.y = 0 }
    }
    SequentialAnimation {
        id: anim
        PauseAnimation { duration: root.delay }
        ParallelAnimation {
            NumberAnimation { target: holder; property: "opacity"; to: 1; duration: Theme.durationSlow; easing.type: Theme.easing }
            NumberAnimation { target: tr; property: "y"; to: 0; duration: Theme.durationSlow; easing.type: Theme.easing }
        }
    }
}
