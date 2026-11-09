import QtQuick
import org.kde.taskmanager as TaskManager

// Finestre REALI (KWin, protocollo org_kde_plasma_window_management) e desktop virtuali.
// Le icone fissate nella barra sono "launcher" del modello: unite alle finestre della stessa app.
QtObject {
    id: root
    readonly property bool available: true
    property var pinned: []                 // es. ["applications:org.kde.dolphin.desktop"]
    readonly property var desktopIds: vd.desktopIds
    readonly property var desktopNames: vd.desktopNames
    readonly property var currentDesktop: vd.currentDesktop
    readonly property int desktopCount: vd.numberOfDesktops

    property TaskManager.VirtualDesktopInfo vd: TaskManager.VirtualDesktopInfo {}
    property TaskManager.ActivityInfo activityInfo: TaskManager.ActivityInfo {}
    property TaskManager.TasksModel model: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        launchInPlace: true
        filterByVirtualDesktop: true
        virtualDesktop: root.vd.currentDesktop
        filterByActivity: false
        activity: root.activityInfo.currentActivity
        launcherList: root.pinned
    }

    function index(row, child) { return model.makeModelIndex(row, child === undefined ? -1 : child) }
    // clic come in Windows: finestra attiva -> riduce; altrimenti attiva (o avvia il launcher)
    function activate(row) { model.requestActivate(index(row)) }
    function toggleMinimized(row) { model.requestToggleMinimized(index(row)) }
    function toggleMaximized(row) { model.requestToggleMaximized(index(row)) }
    function close(row) { model.requestClose(index(row)) }
    function newInstance(row) { model.requestNewInstance(index(row)) }
    function activateChild(row, child) { model.requestActivate(index(row, child)) }
    function publishGeometry(row, rect, item) { model.requestPublishDelegateGeometry(index(row), rect, item) }
    function pin(url) { return model.requestAddLauncher(url) }
    function unpin(url) { return model.requestRemoveLauncher(url) }
}
