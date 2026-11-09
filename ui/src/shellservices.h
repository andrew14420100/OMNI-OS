#pragma once
#include <QElapsedTimer>
#include <QObject>
#include <QQuickImageProvider>

// Servizi di supporto della shell OMNI:
//  - ShellPerf: tempi reali di avvio (registrati nel journal, usati dalle prove)
//  - PlasmaShellProxy: risponde al tasto Meta (KWin chiama org.kde.plasmashell
//    /PlasmaShell activateLauncherMenu): nella sessione OMNI apre il menu Start di OMNI
//  - ThemeIconProvider: "image://omniicon/<nome>" icone del tema di sistema (Breeze)
class ShellPerf : public QObject {
    Q_OBJECT
public:
    explicit ShellPerf(QObject *parent = nullptr) : QObject(parent) { m_t.start(); }
    // registra "OMNI Shell: <evento> dopo N ms" una sola volta per evento
    Q_INVOKABLE void mark(const QString &event);
    Q_INVOKABLE qint64 elapsed() const { return m_t.elapsed(); }
    Q_INVOKABLE qint64 epochMs() const;
private:
    QElapsedTimer m_t;
    QStringList m_done;
};

class PlasmaShellProxy : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.PlasmaShell")
    Q_PROPERTY(bool registered READ registered CONSTANT)
public:
    explicit PlasmaShellProxy(QObject *parent = nullptr);
    bool registerOnBus();
    bool registered() const { return m_registered; }
public slots:
    Q_SCRIPTABLE void activateLauncherMenu();
    Q_SCRIPTABLE void toggleDashboard();
signals:
    void startRequested();
    void showDesktopRequested();
private:
    bool m_registered = false;
};

// Azioni reali di KWin via D-Bus: scorciatoie (Panoramica = Visualizzazione attività,
// Mostra desktop) e desktop virtuali (org.kde.KWin.VirtualDesktopManager).
class KWinActions : public QObject {
    Q_OBJECT
public:
    explicit KWinActions(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void invokeShortcut(const QString &name);
    Q_INVOKABLE void setCurrentDesktop(const QString &id);
    Q_INVOKABLE void createDesktop(int position, const QString &name);
    Q_INVOKABLE void removeDesktop(const QString &id);
    // ricerca di sistema (file, impostazioni, calcoli) con KRunner
    Q_INVOKABLE void krunnerQuery(const QString &text);
signals:
    void failed(const QString &what, const QString &reason);
};

class ThemeIconProvider : public QQuickImageProvider {
public:
    ThemeIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
