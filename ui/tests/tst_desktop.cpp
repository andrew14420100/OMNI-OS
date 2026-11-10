// Prove dei componenti della sessione OMNI (barra, Start, impostazioni rapide, notifiche)
// con gli oggetti C++ reali come contesto (server delle notifiche non registrato sul bus,
// stato del sistema, azioni di sessione) e un elenco di app di prova.
#include "desktopentries.h"
#include "applauncher.h"
#include "notificationserver.h"
#include "sessionactions.h"
#include "shellservices.h"
#include "omnisystem.h"
#include "systemstatus.h"
#include <QQmlContext>
#include <QQmlEngine>
#include <QtQuickTest>

class Setup : public QObject {
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        apps.load({QStringLiteral(OMNI_TEST_APPS)}, QStringLiteral("it_IT"));
        auto *c = engine->rootContext();
        c->setContextProperty("appModel", &apps);
        c->setContextProperty("omniLauncher", &launcher);
        c->setContextProperty("notificationServer", &notes);
        c->setContextProperty("sessionActions", &session);
        c->setContextProperty("systemStatus", &system);
        c->setContextProperty("kwinActions", &kwin);
        static OmniSystem omniSys;
        c->setContextProperty("omniSystem", &omniSys);
        c->setContextProperty("shellPerf", &perf);
        c->setContextProperty("currentUser", QStringLiteral("Prova"));
        c->setContextProperty("rendererName", QStringLiteral("test"));
        c->setContextProperty("softwareRendering", true);
        c->setContextProperty("initialReducedMotion", false);
        engine->addImageProvider(QStringLiteral("omniicon"), new ThemeIconProvider);
    }
public:
    DesktopEntryModel apps;
    AppLauncher launcher{&apps, false};
    NotificationServer notes;
    SessionActions session;
    SystemStatus system;
    KWinActions kwin;
    ShellPerf perf;
};

QUICK_TEST_MAIN_WITH_SETUP(desktop, Setup)
#include "tst_desktop.moc"
