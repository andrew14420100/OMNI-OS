import QtQuick
import OmniDesign
import OmniApps
import "../../OmniApps/sys.js" as Sys

// Backup dei FILE PERSONALI (copia con rsync, mai cancellazioni) e strumenti di recupero.
// Da non confondere con il ripristino del SISTEMA (rpm-ostree, pagina Aggiornamenti).
SettingsPage {
    id: page
    property var services: null
    property var frame: null
    title: qsTr("Backup e ripristino")
    subtitle: qsTr("Backup = copia dei tuoi file personali. Ripristino del sistema = tornare alla versione precedente di OMNI OS (pagina Aggiornamenti): sono cose diverse.")
    property var dirs: omniSystem.userDirs()
    property var chosen: dirs.slice()
    property string dest: ""
    property string restoreFrom: ""
    property bool busy: false
    property string progress: ""
    property string state: ""
    property int stateKind: 0
    property string failed: ""
    property string errors: ""
    function stamp() { return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmm") }
    function health() {
        Sys.run("systemctl", ["--failed", "--no-legend", "--plain"], (c, o) => page.failed = o.trim())
        Sys.run("systemctl", ["--user", "--failed", "--no-legend", "--plain"], (c, o) => page.failed = (page.failed + "\n" + o.trim()).trim())
        Sys.run("journalctl", ["-b", "-p", "err", "-n", "15", "--no-pager", "-o", "short"], (c, o) => page.errors = o.trim())
    }
    Component.onCompleted: health()
    SectionTitle { text: qsTr("Backup dei file personali") }
    Repeater {
        model: page.dirs
        delegate: SettingCard { required property string modelData; icon: "folder"; title: modelData.split("/").pop(); subtitle: modelData
            OmniSwitch { checked: page.chosen.indexOf(modelData) >= 0; onToggled: page.chosen = checked ? page.chosen.concat([modelData]) : page.chosen.filter(x => x !== modelData) } }
    }
    SettingCard { objectName: "backup:dest"; icon: "drive"; title: qsTr("Destinazione"); subtitle: qsTr("Una cartella, ad esempio su un disco esterno")
        FolderPicker { dialogTitle: qsTr("Cartella di destinazione del backup"); path: page.dest; onPathChanged: page.dest = path } }
    Row { spacing: 8
        OmniButton { objectName: "backup:avvia"; text: qsTr("Esegui il backup"); primary: true; enabled: !page.busy && page.dest !== "" && page.chosen.length > 0
            onClicked: {
                const target = page.dest + "/OMNI-backup-" + page.stamp() + "/"
                page.busy = true; page.state = qsTr("Backup in corso verso %1").arg(target); page.stateKind = 3
                Sys.run("rsync", ["-a", "--info=progress2", "--no-inc-recursive"].concat(page.chosen).concat([target]), (c, o, e) => {
                    page.busy = false; page.progress = ""
                    page.state = c === 0 ? qsTr("Backup completato: %1").arg(target) : qsTr("Backup non riuscito: %1").arg(e.trim().split("\n").pop())
                    page.stateKind = c === 0 ? 1 : 2 }, { timeout: 0, onLine: l => page.progress = l })
            } }
    }
    StatusNote { text: page.progress; kind: 3 }
    StatusNote { objectName: "backup:stato"; text: page.state; kind: page.stateKind }
    SectionTitle { text: qsTr("Ripristino dei file personali") }
    SettingCard { icon: "history"; title: qsTr("Backup da ripristinare"); subtitle: qsTr("Una cartella OMNI-backup-…")
        FolderPicker { dialogTitle: qsTr("Backup da ripristinare"); path: page.restoreFrom; onPathChanged: page.restoreFrom = path } }
    StatusNote { text: qsTr("Il ripristino copia nella cartella personale solo i file che mancano: i file esistenti non vengono mai sovrascritti né cancellati.") }
    OmniButton { text: qsTr("Ripristina i file mancanti"); enabled: !page.busy && page.restoreFrom !== ""
        onClicked: { page.busy = true; page.state = qsTr("Ripristino in corso…"); page.stateKind = 3
            Sys.run("rsync", ["-a", "--ignore-existing", "--info=progress2", page.restoreFrom + "/", omniSystem.homePath() + "/"], (c, o, e) => {
                page.busy = false; page.progress = ""; page.state = c === 0 ? qsTr("Ripristino completato") : qsTr("Ripristino non riuscito: %1").arg(e.trim()); page.stateKind = c === 0 ? 1 : 2 }, { timeout: 0, onLine: l => page.progress = l }) } }
    SectionTitle { text: qsTr("Stato del sistema e recupero") }
    SettingCard { objectName: "backup:servizi"; icon: page.failed ? "info" : "check"; title: qsTr("Servizi"); subtitle: page.failed ? qsTr("Servizi non riusciti:\n%1").arg(page.failed) : qsTr("Nessun servizio in errore"); warning: page.failed !== "" }
    SettingCard { icon: "info"; title: qsTr("Errori recenti (questo avvio)"); subtitle: page.errors ? page.errors.split("\n").slice(-6).join("\n") : qsTr("Nessun errore registrato") }
    SettingCard { icon: "restart"; title: qsTr("Riavvia l'interfaccia OMNI"); subtitle: qsTr("Se la barra o i pannelli non rispondono: le app aperte restano aperte")
        OmniButton { text: qsTr("Riavvia"); onClicked: Sys.run("systemctl", ["--user", "restart", "omni-shell.service"], (c, o, e) => { page.state = c === 0 ? qsTr("Interfaccia riavviata") : e; page.stateKind = c === 0 ? 1 : 2 }) } }
    SettingCard { icon: "palette"; title: qsTr("Ripristina le preferenze di OMNI"); subtitle: qsTr("Tema, barra, app aggiunte tornano a quelli iniziali; il file attuale viene conservato")
        OmniButton { text: qsTr("Ripristina…"); onClicked: { const k = omniSystem.resetShellPreferences(shellSettings.file()); page.state = k ? qsTr("Preferenze ripristinate (copia: %1)").arg(k) : qsTr("Nessuna preferenza da ripristinare"); page.stateKind = k ? 1 : 0 } } }
    SettingCard { icon: "shield"; title: qsTr("Modalità sicura"); subtitle: qsTr("All'accesso scegli \"OMNI OS – modalità sicura (desktop Plasma)\": desktop Plasma originale senza OMNI Shell. Se OMNI Shell si arresta più volte di seguito, il desktop Plasma parte da solo.") }
    SettingCard { icon: "history"; title: qsTr("Ripristino del sistema"); subtitle: qsTr("Per tornare alla versione precedente di OMNI OS"); clickable: true; onClicked: page.frame.open("aggiornamenti")
        OmniIcon { width: 16; height: 16; name: "chevron-right"; color: Theme.textSecondary } }
}
