#pragma once
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QStringList>
#include <QVariantList>

class QProcess;

// Accesso CONTROLLATO ai servizi di sistema per le applicazioni OMNI (Impostazioni, Gestione
// attività, Store, Explorer):
//  - run(): avvia SOLO programmi di un elenco consentito, con argomenti in lista (nessuna
//    shell, nessuna espansione), in modo asincrono; uscita completa o riga per riga.
//  - dbus(): chiamata D-Bus asincrona con argomenti tipizzati ("s:testo", "b:true", "u:5",
//    "i:-1", "x:..", "t:..", "d:1.5", "as:a,b", "v:s:testo"); l'autorizzazione delle operazioni
//    privilegiate resta a polkit (richiesta interattiva all'utente), mai concessa qui.
// Ogni esito arriva con un identificativo: nessuna operazione viene dichiarata riuscita
// prima della risposta del sistema.
class OmniSystem : public QObject {
    Q_OBJECT
public:
    explicit OmniSystem(QObject *parent = nullptr);
    static QStringList allowedPrograms();

    Q_INVOKABLE int run(const QString &program, const QStringList &args, int timeoutMs = 60000, bool streamLines = false);
    Q_INVOKABLE void cancel(int id);
    Q_INVOKABLE int dbus(const QString &bus, const QString &service, const QString &path, const QString &iface,
                         const QString &method, const QStringList &typedArgs = {}, bool interactive = false, int timeoutMs = 60000);
    Q_INVOKABLE int dbusGet(const QString &bus, const QString &service, const QString &path, const QString &iface, const QString &prop);
    Q_INVOKABLE bool available(const QString &program) const;
    Q_INVOKABLE QString readFile(const QString &path, int maxBytes = 1 << 20) const;   // sola lettura, file di sistema o dell'utente
    Q_INVOKABLE QString homePath() const;
    Q_INVOKABLE QString env(const QString &name) const;

    // Avvio automatico dell'utente (solo ~/.config/autostart, nomi senza percorso): abilitare,
    // disabilitare (Hidden=true, come da specifica freedesktop) o rimuovere la propria voce.
    Q_INVOKABLE bool setAutostart(const QString &desktopId, bool enabled);
    Q_INVOKABLE QVariantList autostartEntries() const;
    // dopo aver cambiato i layout di tastiera (kxkbrc): segnale standard di KDE a KWin
    Q_INVOKABLE void reloadKeyboardConfig();
    // ripristino delle preferenze OMNI: il file attuale viene conservato con un suffisso
    Q_INVOKABLE QString resetShellPreferences(const QString &file);
    // file e cartelle per le pagine Archiviazione e Backup (sola lettura)
    Q_INVOKABLE QStringList userDirs() const;
    Q_INVOKABLE bool exists(const QString &path) const;
    // elenco (sola lettura) dei file con le estensioni indicate, fino a "max" voci
    Q_INVOKABLE QStringList listFiles(const QString &dir, const QStringList &suffixes, bool recursive = true, int max = 200) const;

    // conversione degli argomenti tipizzati (pubblica per i test)
    static bool parseTyped(const QString &spec, QVariant *out);

signals:
    void finished(int id, int exitCode, const QString &out, const QString &err);
    void line(int id, const QString &text);
    void dbusFinished(int id, bool ok, const QVariant &result, const QString &error);

private:
    int m_next = 1;
    QHash<int, QPointer<QProcess>> m_procs;
};
