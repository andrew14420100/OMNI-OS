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
    // movimento ridotto per TUTTO il desktop (animazioni di KWin e delle app KDE):
    // impostazione KDE AnimationDurationFactor (0 = nessuna animazione, 1 = normale)
    Q_INVOKABLE void setSystemReducedMotion(bool reduced);
    // rendering software (nessuna GPU): disattiva per questa sessione gli effetti più costosi
    // di KWin (sfocatura e contrasto dello sfondo); nessuna modifica permanente
    Q_INVOKABLE void optimizeForSoftwareRendering();
signals:
    void failed(const QString &what, const QString &reason);
};

// Controllo della shell via D-Bus (org.omnios.Shell /Shell): usato dalle prove in VM per
// conoscere la posizione reale degli elementi (clic veri) e per aprire i pannelli.
class ShellControl : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.omnios.Shell")
public:
    explicit ShellControl(QObject *parent = nullptr) : QObject(parent) {}
    bool registerOnBus();
public slots:
    Q_SCRIPTABLE bool DumpGeometry(const QString &file);
    Q_SCRIPTABLE void ShowPopup(const QString &name);
    Q_SCRIPTABLE QString Version() { return QStringLiteral("0.3.0"); }
    // eventi della sonda delle prove (script KWin): solo registrati nel journal
    Q_SCRIPTABLE void Probe(const QString &text);
signals:
    void popupRequested(const QString &name);
};

// Preferenze dell'utente (QSettings, ~/.config/omni-os/omni-shell.conf): tema, accento,
// movimento ridotto, app aggiunte a Start e alla barra.
class ShellSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool dark READ dark WRITE setDark NOTIFY changed)
    Q_PROPERTY(int accent READ accent WRITE setAccent NOTIFY changed)
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY changed)
    Q_PROPERTY(QStringList startPins READ startPins WRITE setStartPins NOTIFY changed)
    Q_PROPERTY(QStringList barPins READ barPins WRITE setBarPins NOTIFY changed)
    Q_PROPERTY(bool pinsInitialized READ pinsInitialized WRITE setPinsInitialized NOTIFY changed)
public:
    explicit ShellSettings(const QString &file = QString(), QObject *parent = nullptr);
    bool dark() const;
    int accent() const;
    bool reducedMotion() const;
    QStringList startPins() const;
    QStringList barPins() const;
    bool pinsInitialized() const;
    void setDark(bool v) { set("dark", v); }
    void setAccent(int v) { set("accent", v); }
    void setReducedMotion(bool v) { set("reducedMotion", v); }
    void setStartPins(const QStringList &v) { set("startPins", v); }
    void setBarPins(const QStringList &v) { set("barPins", v); }
    void setPinsInitialized(bool v) { set("pinsInitialized", v); }
signals:
    void changed();
private:
    void set(const char *key, const QVariant &v);
    QString m_file;
};

class ThemeIconProvider : public QQuickImageProvider {
public:
    ThemeIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
