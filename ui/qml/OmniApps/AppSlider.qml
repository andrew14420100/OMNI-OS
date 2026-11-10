import QtQuick
import OmniDesign
// Cursore delle app OMNI: segue il valore reale (value) ed emette moved() durante il trascinamento.
Item {
    id: s
    property real value: 0
    property real live: value
    signal moved(real value)
    width: 260; height: 28
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.Slider
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.outlineStrong }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, ma.pressed ? s.live : s.value)); height: 4; radius: 2; color: Theme.accent }
    Rectangle {
        x: parent.width * Math.max(0, Math.min(1, ma.pressed ? s.live : s.value)) - width / 2; anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18; radius: 9; color: Theme.accent; border.color: Theme.dark ? "#161D31" : "#FFFFFF"; border.width: 4
    }
    MouseArea {
        id: ma; anchors.fill: parent
        function at(mx) { return Math.max(0, Math.min(1, mx / width)) }
        onPressed: mouse => { s.live = at(mouse.x); s.moved(s.live) }
        onPositionChanged: mouse => { if (pressed) { s.live = at(mouse.x); s.moved(s.live) } }
        onWheel: wheel => s.moved(Math.max(0, Math.min(1, s.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
