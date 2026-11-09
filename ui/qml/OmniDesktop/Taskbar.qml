import QtQuick
import OmniDesign

// Barra delle applicazioni OMNI (unica barra del desktop): Start, ricerca, visualizzazione
// attività, app fissate e finestre aperte REALI (KWin), area di stato e orologio.
// Comportamento come in Windows 11: clic su un'app aperta = attiva/riduce, clic centrale =
// nuova finestra, clic destro = menu dell'app; le app fissate restano al loro posto.
Item {
    id: bar
    property var session: null
    property var tasks: session ? session.services.tasks : null
    property var audio: session ? session.services.audio : null
    property var network: session ? session.services.network : null
    property var appIndex: session ? session.appIndex : null
    readonly property string popup: session ? session.popup : ""
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        color: Theme.dark ? Qt.rgba(0.055, 0.07, 0.125, 0.97) : Qt.rgba(0.965, 0.972, 0.99, 0.97)
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.outline }
    }

    component BarButton: Item {
        id: bb
        property bool active: false
        property bool pressedNow: ma.pressed
        property alias hovered: ma.containsMouse
        property string tip: ""
        signal clicked(var mouse)
        width: 44; height: 40
        Accessible.role: Accessible.Button
        Accessible.name: tip
        Accessible.onPressAction: bb.clicked(null)
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: bb.pressedNow ? Theme.pressed : (bb.active || ma.containsMouse ? Theme.hover : "transparent")
            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 90 } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouse => bb.clicked(mouse)
        }
    }

    Row {
        id: center
        anchors.centerIn: parent
        spacing: 2

        BarButton {
            objectName: "bar:start"
            tip: qsTr("Start")
            active: bar.popup === "start"
            onClicked: bar.session.toggle("start")
            OmniLogo { anchors.centerIn: parent; size: 22 }
        }
        BarButton {
            objectName: "bar:search"
            tip: qsTr("Cerca")
            onClicked: bar.session.openStart(true)
            OmniIcon { anchors.centerIn: parent; name: "search"; width: 20; height: 20; color: Theme.textSecondary }
        }
        BarButton {
            objectName: "bar:taskview"
            tip: qsTr("Visualizzazione attività e desktop virtuali")
            onClicked: { bar.session.close(); kwinActions.invokeShortcut("Overview") }
            OmniIcon { anchors.centerIn: parent; name: "layers"; width: 20; height: 20; color: Theme.textSecondary }
        }

        Repeater {
            model: bar.tasks ? bar.tasks.model : null
            delegate: BarButton {
                id: task
                required property int index
                required property var model
                readonly property var entry: bar.appIndex ? bar.appIndex.find(model.LauncherUrlWithoutIcon || model.AppId) : null
                readonly property bool running: model.IsWindow === true || model.IsGroupParent === true
                objectName: "bar:task:" + (entry ? entry.desktopId : (model.AppId || index))
                tip: model.display || (entry ? entry.name : "")
                active: model.IsActive === true
                onClicked: mouse => {
                    if (mouse && mouse.button === Qt.RightButton) { bar.session.openTaskMenu(index, task, model); return }
                    if (mouse && mouse.button === Qt.MiddleButton) { bar.tasks.newInstance(index); return }
                    if (model.IsGroupParent === true && model.ChildCount > 1) { bar.session.openTaskMenu(index, task, model); return }
                    if (running) {
                        if (model.IsActive === true) bar.tasks.toggleMinimized(index)
                        else bar.tasks.activate(index)
                    } else {
                        bar.session.noteLaunch(entry ? entry.desktopId : model.AppId)
                        bar.tasks.activate(index)            // launcher: avvio reale
                    }
                }
                AppIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    size: 26
                    appName: task.entry ? task.entry.name : (task.model.AppName || "")
                    desktopId: task.entry ? task.entry.desktopId : (task.model.AppId || "")
                    iconName: task.entry ? task.entry.iconName : (task.model.AppId || "")
                    categories: task.entry ? task.entry.categories : []
                    opacity: task.model.IsStartup === true ? 0.55 : 1
                    SequentialAnimation on opacity {
                        running: task.model.IsStartup === true && !Theme.reducedMotion
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 420 }
                        NumberAnimation { to: 0.9; duration: 420 }
                    }
                }
                // indicatore: lungo = finestra attiva, corto = app aperta
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    height: 3; radius: 1.5
                    width: task.active ? 16 : 6
                    visible: task.running || task.model.IsStartup === true
                    color: task.active ? Theme.accent : Theme.textTertiary
                    Behavior on width { enabled: !Theme.reducedMotion; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
                Rectangle {   // richiesta di attenzione
                    visible: task.model.IsDemandingAttention === true
                    anchors.fill: parent; radius: 8; color: "transparent"
                    border.color: Theme.prototype; border.width: 1
                }
            }
        }
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        BarButton {
            objectName: "bar:status"
            tip: qsTr("Rete, audio e impostazioni rapide")
            width: statusRow.implicitWidth + 20
            active: bar.popup === "quick"
            onClicked: bar.session.toggle("quick")
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 10
                OmniIcon {
                    width: 18; height: 18
                    name: bar.session && bar.session.networkIcon ? bar.session.networkIcon : "globe"
                    color: Theme.textPrimary
                }
                OmniIcon {
                    width: 18; height: 18
                    name: bar.audio && bar.audio.available && !bar.audio.muted ? "volume" : "volume-off"
                    color: Theme.textPrimary
                }
                OmniIcon {
                    visible: systemStatus.batteryPresent
                    width: 18; height: 18; name: "battery"; color: Theme.textPrimary
                }
            }
        }
        BarButton {
            objectName: "bar:clock"
            tip: qsTr("Notifiche e calendario")
            width: clockCol.implicitWidth + 24
            active: bar.popup === "notifications"
            onClicked: bar.session.toggle("notifications")
            Column {
                id: clockCol
                anchors.centerIn: parent
                Text {
                    anchors.right: parent.right
                    text: Qt.formatTime(bar.session ? bar.session.now : new Date(), "HH:mm")
                    color: Theme.textPrimary; font.pixelSize: 12; font.family: Theme.fontFamily
                }
                Text {
                    anchors.right: parent.right
                    text: Qt.formatDate(bar.session ? bar.session.now : new Date(), "dd/MM/yyyy")
                    color: Theme.textPrimary; font.pixelSize: 12; font.family: Theme.fontFamily
                }
            }
            Rectangle {   // notifiche non lette / non disturbare
                anchors { right: parent.right; top: parent.top; rightMargin: 3; topMargin: 4 }
                width: 8; height: 8; radius: 4
                visible: notificationServer.unreadCount > 0 || notificationServer.doNotDisturb
                color: notificationServer.doNotDisturb ? Theme.textTertiary : Theme.accent
            }
        }
        // "Mostra desktop" (striscia all'estremità destra, come in Windows)
        Item {
            objectName: "bar:showdesktop"
            width: 8; height: 40
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Mostra desktop")
            Rectangle { anchors.centerIn: parent; width: 1; height: 18; color: Theme.outlineStrong }
            MouseArea { anchors.fill: parent; onClicked: { bar.session.close(); kwinActions.invokeShortcut("Show Desktop") } }
        }
    }
}
