import QtQuick
import OmniDesign
import OmniDesktop
import OmniApps

// OMNI Settings: impostazioni complete del sistema. Ogni pagina legge lo stato reale dal
// servizio responsabile e lo rilegge dopo ogni modifica; le operazioni privilegiate passano
// da polkit. Le preferenze condivise con la barra (tema, Non disturbare, ...) sono le stesse.
AppFrame {
    id: app
    appTitle: qsTr("Impostazioni")
    baseUrl: Qt.resolvedUrl(".")
    property Services svc: Services {}
    pageProps: ({ services: svc, frame: app })
    sections: [
        { id: "schermo", title: qsTr("Schermo"), icon: "display", source: "settings/Display.qml", keywords: "risoluzione scala frequenza monitor" },
        { id: "audio", title: qsTr("Audio"), icon: "volume", source: "settings/Audio.qml", keywords: "volume microfono altoparlanti uscita ingresso" },
        { id: "notifiche", title: qsTr("Notifiche"), icon: "bell", source: "settings/Notifications.qml", keywords: "non disturbare avvisi" },
        { id: "energia", title: qsTr("Energia e batteria"), icon: "battery", source: "settings/Power.qml", keywords: "sospensione profilo schermo spegnimento" },
        { id: "archiviazione", title: qsTr("Archiviazione"), icon: "drive", source: "settings/Storage.qml", keywords: "disco spazio cestino" },
        { id: "rete", title: qsTr("Rete e Internet"), icon: "globe", source: "settings/Network.qml", keywords: "wifi ethernet connessione" },
        { id: "bluetooth", title: qsTr("Bluetooth e dispositivi"), icon: "bluetooth", source: "settings/Bluetooth.qml", keywords: "associa cuffie" },
        { id: "input", title: qsTr("Mouse, tastiera e touchpad"), icon: "tool", source: "settings/Input.qml", keywords: "puntatore velocità scorrimento layout ripetizione" },
        { id: "aspetto", title: qsTr("Personalizzazione"), icon: "palette", source: "settings/Appearance.qml", keywords: "tema scuro chiaro colore sfondo barra animazioni effetti" },
        { id: "app", title: qsTr("App"), icon: "apps", source: "settings/Apps.qml", keywords: "predefinite avvio automatico disinstalla" },
        { id: "account", title: qsTr("Account"), icon: "user", source: "settings/Account.qml", keywords: "utente nome password sessioni" },
        { id: "ora", title: qsTr("Ora e lingua"), icon: "calendar", source: "settings/DateTime.qml", keywords: "data fuso orario lingua regione formati" },
        { id: "privacy", title: qsTr("Privacy e sicurezza"), icon: "shield", source: "settings/Privacy.qml", keywords: "firewall permessi blocco schermo selinux" },
        { id: "aggiornamenti", title: qsTr("Aggiornamenti"), icon: "restart", source: "settings/Updates.qml", keywords: "rpm-ostree flatpak ripristino versione" },
        { id: "backup", title: qsTr("Backup e ripristino"), icon: "history", source: "settings/Backup.qml", keywords: "copia recupero errori modalità sicura" },
        { id: "info", title: qsTr("Informazioni"), icon: "info", source: "settings/About.qml", keywords: "versione sistema processore memoria" }
    ]
    Component.onCompleted: {
        Qt.callLater(svc.loadLate)
        systemStatus.refresh()
    }
}
