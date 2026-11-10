#pragma once
#include <QObject>
#include <QStringList>

// Azioni REALI di sessione ed energia, tramite i servizi del sistema:
//  - spegnimento, riavvio, disconnessione: org.kde.Shutdown (ksmserver di Plasma), che chiede
//    alle applicazioni di chiudersi e salvare il lavoro prima di chiamare systemd-logind;
//    se ksmserver non risponde: org.freedesktop.login1 (con autorizzazione polkit).
//  - sospensione: org.freedesktop.login1.Manager.Suspend (solo se CanSuspend lo consente)
//  - blocco: org.freedesktop.ScreenSaver.Lock (kscreenlocker)
// Ogni chiamata è asincrona: l'interfaccia non si blocca mai in attesa del servizio.
class SessionActions : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool canShutdown READ canShutdown NOTIFY capabilitiesChanged)
    Q_PROPERTY(bool canReboot READ canReboot NOTIFY capabilitiesChanged)
    Q_PROPERTY(bool canSuspend READ canSuspend NOTIFY capabilitiesChanged)
    Q_PROPERTY(QString suspendNote READ suspendNote NOTIFY capabilitiesChanged)
    Q_PROPERTY(QStringList inhibitors READ inhibitors NOTIFY inhibitorsChanged)
public:
    explicit SessionActions(QObject *parent = nullptr);
    bool canShutdown() const { return m_canShutdown; }
    bool canReboot() const { return m_canReboot; }
    bool canSuspend() const { return m_canSuspend; }
    QString suspendNote() const { return m_suspendNote; }
    QStringList inhibitors() const { return m_inhibitors; }

    Q_INVOKABLE void refresh();          // rilegge capacità e blocchi (inibitori) di logind
    Q_INVOKABLE void shutdown();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void lock();

signals:
    void capabilitiesChanged();
    void inhibitorsChanged();
    void actionStarted(const QString &what);
    void actionFailed(const QString &what, const QString &reason);

private:
    void ksmserver(const QString &method, const QString &what, const QString &login1Fallback);
    void login1(const QString &method, const QString &what);
    bool m_canShutdown = false, m_canReboot = false, m_canSuspend = false;
    QString m_suspendNote;
    QStringList m_inhibitors;
};
