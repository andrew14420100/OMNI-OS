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
    // dopo l'attivazione di una finestra (asincrona in Wayland): azione di KWin sulla finestra attiva
    Q_INVOKABLE void invokeShortcutLater(const QString &name, int delayMs = 200);
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
    // la schermata di caricamento di Plasma (KSplash) attende lo stadio "desktop", che nella
    // sessione Plasma invia plasmashell: nella sessione OMNI lo invia OMNI Shell al primo fotogramma
    Q_INVOKABLE void splashDesktopReady();
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
    Q_SCRIPTABLE QString Version() { return QStringLiteral("0.4.0"); }
    // avvio di un'app come dal menu Start (file .desktop elencato dal sistema): usato anche dalle misure
    Q_SCRIPTABLE bool Launch(const QString &desktopFile);
    // eventi della sonda delle prove (script KWin): solo registrati nel journal
    Q_SCRIPTABLE void Probe(const QString &text);
    void setLauncher(class AppLauncher *l) { m_launcher = l; }
signals:
    void popupRequested(const QString &name);
private:
    class AppLauncher *m_launcher = nullptr;
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
    // condivise fra OMNI Shell e le app OMNI (stesso file, aggiornate dal vivo in entrambi)
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb NOTIFY changed)
    Q_PROPERTY(int barSize READ barSize WRITE setBarSize NOTIFY changed)
    Q_PROPERTY(QString wallpaper READ wallpaper WRITE setWallpaper NOTIFY changed)
    Q_PROPERTY(int effects READ effects WRITE setEffects NOTIFY changed)          // 0 essenziali, 1 equilibrati, 2 completi
    Q_PROPERTY(bool startShowRecent READ startShowRecent WRITE setStartShowRecent NOTIFY changed)
    // con grafica software (llvmpipe): le app Qt Quick avviate dalla shell usano il renderer
    // software di Qt Quick (misurato: Impostazioni utilizzabili in 1,0 s invece di 2,2 s)
    Q_PROPERTY(bool softwareQuickApps READ softwareQuickApps WRITE setSoftwareQuickApps NOTIFY changed)
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
    bool doNotDisturb() const;
    int barSize() const;
    QString wallpaper() const;
    int effects() const;
    bool startShowRecent() const;
    void setDoNotDisturb(bool v) { set("doNotDisturb", v); }
    void setBarSize(int v) { set("barSize", qBound(40, v, 64)); }
    void setWallpaper(const QString &v) { set("wallpaper", v); }
    void setEffects(int v) { set("effects", qBound(0, v, 2)); }
    void setStartShowRecent(bool v) { set("startShowRecent", v); }
    bool softwareQuickApps() const;
    void setSoftwareQuickApps(bool v) { set("softwareQuickApps", v); }
    Q_INVOKABLE QString file() const { return m_file; }
signals:
    void changed();
private:
    void set(const char *key, const QVariant &v);
    void watch();
    QString m_file;
    class QFileSystemWatcher *m_watcher = nullptr;
};

class ThemeIconProvider : public QQuickImageProvider {
public:
    ThemeIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
