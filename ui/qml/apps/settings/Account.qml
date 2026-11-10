import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Account")
    subtitle: qsTr("Il tuo account (AccountsService) e le sessioni aperte (systemd-logind).")
    property var user: ({})
    property string path: ""
    property var sessions: []
    property string note: ""
    property int noteKind: 0
    readonly property string asvc: "org.freedesktop.Accounts"
    function reload() {
        const uid = (omniSystem.readFile("/proc/self/status").match(/Uid:\s+(\d+)/) || [0, 0])[1]
        Sys.dbus("system", asvc, "/org/freedesktop/Accounts", asvc, "FindUserById", ["x:" + uid], (ok, p) => {
            if (!ok) { page.note = qsTr("AccountsService non disponibile"); page.noteKind = 2; return }
            page.path = p
            Sys.dbus("system", asvc, p, "org.freedesktop.DBus.Properties", "GetAll", ["s:" + asvc + ".User"], (ok2, props) => { if (ok2) page.user = props })
        })
        Sys.dbus("system", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListSessions", [], (ok, l) => { if (ok) page.sessions = l })
    }
    Component.onCompleted: reload()
    SettingCard {
        icon: "user"; title: page.user.RealName || page.user.UserName || currentUser
        subtitle: (page.user.UserName ? page.user.UserName + " · " : "") + (page.user.AccountType === 1 ? qsTr("Amministratore") : qsTr("Utente standard"))
    }
    SettingCard {
        objectName: "account:nome"
        title: qsTr("Nome visualizzato")
        Row { spacing: 8
            Rectangle { width: 220; height: 34; radius: 6; color: Theme.surfaceSunken; border.color: Theme.outlineStrong
                TextInput { id: nameIn; anchors.fill: parent; anchors.margins: 8; text: page.user.RealName || ""; color: Theme.textPrimary; font.pixelSize: 13; clip: true } }
            OmniButton { text: qsTr("Salva"); primary: true; enabled: nameIn.text.trim() !== "" && nameIn.text !== page.user.RealName
                onClicked: Sys.dbus("system", page.asvc, page.path, page.asvc + ".User", "SetRealName", ["s:" + nameIn.text.trim()], (ok, r, err) => {
                    page.note = ok ? qsTr("Nome aggiornato") : qsTr("Non aggiornato: %1").arg(err); page.noteKind = ok ? 1 : 2; page.reload() }, true) } }
    }
    SettingCard { icon: "lock"; title: qsTr("Password, immagine dell'account e altri utenti"); subtitle: qsTr("Gestione utenti di KDE: chiede la password di amministratore quando serve"); clickable: true; onClicked: systemStatus.openSettings("kcm_users")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
    StatusNote { text: page.note; kind: page.noteKind }
    SectionTitle { text: qsTr("Sessioni aperte") }
    Repeater {
        model: page.sessions
        delegate: SettingCard { required property var modelData; icon: "display"; title: qsTr("Sessione %1 · %2").arg(modelData[0]).arg(modelData[2]); subtitle: modelData[3] ? qsTr("posto %1").arg(modelData[3]) : "" }
    }
    Row { spacing: 8
        OmniButton { text: qsTr("Blocca"); onClicked: sessionActions.lock() }
        OmniButton { text: qsTr("Disconnetti"); onClicked: sessionActions.logout() } }
}
