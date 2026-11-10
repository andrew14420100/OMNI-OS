// OMNI Shell — prototipo anticipato dell'interfaccia (non M4).
// Normale applicazione utente: nessun privilegio, nessuna modifica alla sessione KDE,
// nessun servizio di sistema. Opzioni utili per catturare schermate reali:
//   --scene desktop|launcher|notifications|quicksettings
//   --theme dark|light   --reduced-motion   --demo-apps   --apps-dir DIR
//   --size 1600x1000     --screenshot FILE.png [--delay MS]
#include "desktopentries.h"
#include "applauncher.h"
#include "recorder.h"
#include "notificationserver.h"
#include "sessionactions.h"
#include "shellservices.h"
#include "systemstatus.h"
#include <QIcon>
#include <QQmlApplicationEngine>
#include <pwd.h>
#ifdef OMNI_HAVE_KGLOBALACCEL
#include <KGlobalAccel>
#include <QAction>
#endif
#include <unistd.h>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <functional>
#include <QCommandLineParser>
#include <QDir>
#include <QFont>
#include <QGuiApplication>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QQuickWindow>
#include <QTimer>

#ifndef OMNI_QML_DIR
#define OMNI_QML_DIR "qml"
#endif

// Nome del renderer OpenGL in uso (es. "llvmpipe" = rendering software, senza GPU).
// Stringa vuota se OpenGL non è disponibile (es. piattaforma offscreen senza contesto).
static QString glRendererName() {
    QOffscreenSurface surface;
    surface.create();
    QOpenGLContext ctx;
    if (!ctx.create() || !ctx.makeCurrent(&surface)) return {};
    const auto *s = reinterpret_cast<const char *>(ctx.functions()->glGetString(GL_RENDERER));
    const QString name = s ? QString::fromLatin1(s) : QString();
    ctx.doneCurrent();
    return name;
}

// Nome visualizzato dell'utente (campo GECOS), altrimenti il nome di accesso.
static QString displayUserName() {
    const QString login = qEnvironmentVariable("USER", qEnvironmentVariable("USERNAME"));
    if (const passwd *pw = getpwuid(getuid())) {
        const QString gecos = QString::fromLocal8Bit(pw->pw_gecos).section(',', 0, 0).trimmed();
        if (!gecos.isEmpty()) return gecos;
    }
    return login;
}

// Sessione OMNI: OMNI Shell è l'interfaccia del desktop (sfondo, barra delle applicazioni,
// Start, pannelli) sopra KWin e i servizi di Plasma. Il pannello di Plasma non è attivo.
static int runSession(QGuiApplication &app, DesktopEntryModel &apps, ShellPerf &perf, const QString &qmlDir,
                      const QString &renderer, bool softwareGl, bool reducedMotion) {
    if (QIcon::themeName().isEmpty()) QIcon::setThemeName(QStringLiteral("breeze"));
    QIcon::setFallbackThemeName(QStringLiteral("breeze"));
    AppLauncher launcher(&apps, !apps.demo());
    NotificationServer notifications;
    notifications.registerOnBus();
    SessionActions session;
    SystemStatus system;
    KWinActions kwin;
    PlasmaShellProxy plasmaShell;
    plasmaShell.registerOnBus();
    ShellControl control;
    control.registerOnBus();
#ifdef OMNI_HAVE_KGLOBALACCEL
    // Stessa azione globale che registra plasmashell: in Plasma 6 il tasto Meta da solo è una
    // scorciatoia KGlobalAccel, non più un'impostazione di KWin. Nella sessione OMNI il
    // componente "plasmashell" è OMNI Shell (Plasma non è in esecuzione).
    QAction launcherAction;
    launcherAction.setObjectName(QStringLiteral("activate application launcher"));
    launcherAction.setText(QStringLiteral("Activate Application Launcher"));
    launcherAction.setProperty("componentName", QStringLiteral("plasmashell"));
    launcherAction.setProperty("componentDisplayName", QStringLiteral("Plasma"));
    QObject::connect(&launcherAction, &QAction::triggered, &plasmaShell, [&plasmaShell]() {
        qInfo("tasto Meta: scorciatoia globale ricevuta");
        emit plasmaShell.startRequested();
    });
    const bool keyOk = KGlobalAccel::self()->setGlobalShortcut(&launcherAction,
        QList<QKeySequence>() << QKeySequence(Qt::Key_Meta) << QKeySequence(Qt::AltModifier | Qt::Key_F1));
    qInfo("tasto Meta: scorciatoia globale %s", keyOk ? "registrata" : "NON registrata");
#endif
    ShellSettings settings;
    qInfo("avvio delle applicazioni: %s", launcher.enabled() ? "REALE (gio launch / kstart)" : "disattivato");

    QQmlApplicationEngine engine;
    engine.addImportPath(qmlDir);
    engine.addImageProvider(QStringLiteral("omniicon"), new ThemeIconProvider);
    auto *ctx = engine.rootContext();
    ctx->setContextProperty("appModel", &apps);
    ctx->setContextProperty("omniLauncher", &launcher);
    ctx->setContextProperty("notificationServer", &notifications);
    ctx->setContextProperty("sessionActions", &session);
    ctx->setContextProperty("systemStatus", &system);
    ctx->setContextProperty("kwinActions", &kwin);
    ctx->setContextProperty("plasmaShell", &plasmaShell);
    ctx->setContextProperty("shellControl", &control);
    ctx->setContextProperty("shellSettings", &settings);
    ctx->setContextProperty("shellPerf", &perf);
    ctx->setContextProperty("rendererName", renderer.isEmpty() ? QStringLiteral("non rilevato") : renderer);
    ctx->setContextProperty("softwareRendering", softwareGl);
    ctx->setContextProperty("initialReducedMotion", reducedMotion);
    ctx->setContextProperty("currentUser", displayUserName());
    perf.mark(QStringLiteral("servizi pronti"));
    engine.load(QUrl::fromLocalFile(QDir(qmlDir).filePath(QStringLiteral("DesktopSession.qml"))));
    if (engine.rootObjects().isEmpty()) {
        qCritical("sessione OMNI: interfaccia non caricata");
        return 1;
    }
    return app.exec();
}

int main(int argc, char *argv[]) {
    ShellPerf perf;
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("omni-shell-prototipo");
    QGuiApplication::setFont(QFont("Inter", 10));
    // I testi del prototipo sono in italiano: se la lingua di sistema non è disponibile
    // (es. "C" nella CI) si usa l'italiano anche per date e numeri.
    // I testi dell'interfaccia sono in italiano: date e numeri seguono la stessa lingua
    // (prima: solo se la lingua di sistema era "C"; nella VM inglese le date erano in inglese).
    QLocale::setDefault(QLocale(QLocale::Italian, QLocale::Italy));

    QCommandLineParser p;
    p.setApplicationDescription("OMNI Shell — prototipo anticipato dell'interfaccia");
    p.addHelpOption();
    QCommandLineOption scene("scene", "Scena iniziale", "nome", "desktop");
    QCommandLineOption theme("theme", "Tema (dark|light)", "tema", "dark");
    QCommandLineOption reduced("reduced-motion", "Movimento ridotto");
    QCommandLineOption demo("demo-apps", "Usa l'elenco dimostrativo delle applicazioni OMNI");
    QCommandLineOption appsDir("apps-dir", "Cartella di file .desktop (ripetibile)", "cartella");
    QCommandLineOption size("size", "Dimensione della finestra", "LxA", "1600x1000");
    QCommandLineOption shot("screenshot", "Salva una schermata reale e termina", "file");
    QCommandLineOption delay("delay", "Attesa prima della schermata (ms)", "ms", "1500");
    QCommandLineOption record("record", "Registra un video reale delle interazioni (MP4, richiede ffmpeg)", "file");
    QCommandLineOption script("script", "Script JSON delle interazioni per --record", "file");
    QCommandLineOption realLaunch("real-launch", "Avvio REALE delle applicazioni installate (solo file .desktop del sistema)");
    QCommandLineOption lowPower("low-power", "Risparmio risorse: sfondo statico (attivo da solo con rendering software)");
    QCommandLineOption fullscreen("fullscreen", "Finestra a schermo intero (prova nella sessione Plasma)");
    QCommandLineOption geometry("dump-geometry", "Scrive in JSON il centro degli elementi con objectName e termina", "file");
    QCommandLineOption sessionMode("session", "Interfaccia del desktop OMNI (sessione OMNI: barra, Start, pannelli, notifiche)");
    QCommandLineOption accent("accent", "Colore d'accento (0 Aurora, 1 Iris, 2 Corallo, 3 Giada)", "n", "0");
    p.addOptions({scene, theme, reduced, demo, appsDir, size, shot, delay, accent, record, script, fullscreen, geometry, lowPower, realLaunch, sessionMode});
    p.process(app);

    // piattaforma grafica effettiva (es. "wayland" nella sessione Plasma) e versione di Qt in uso
    qInfo("piattaforma: %s; Qt in esecuzione: %s (compilato con %s)", qPrintable(QGuiApplication::platformName()), qVersion(), QT_VERSION_STR);

    // Rendering software (nessuna GPU, es. VM senza accelerazione): si attiva il risparmio
    // risorse per mantenere l'interfaccia fluida. Rilevazione solo in lettura.
    const QString renderer = QGuiApplication::platformName() == QLatin1String("offscreen") ? QString() : glRendererName();
    const bool softwareGl = renderer.contains(QLatin1String("llvmpipe"), Qt::CaseInsensitive)
                         || renderer.contains(QLatin1String("softpipe"), Qt::CaseInsensitive)
                         || renderer.contains(QLatin1String("SwiftShader"), Qt::CaseInsensitive);
    qInfo("renderer OpenGL: %s%s", renderer.isEmpty() ? "non rilevato" : qPrintable(renderer), softwareGl ? " (rendering software: risparmio risorse automatico)" : "");

    DesktopEntryModel apps;
    if (p.isSet(sessionMode)) {
        apps.load({}, QLocale::system().name());
        qInfo("applicazioni: %d (file .desktop del sistema, sola lettura)", apps.count());
        const QString qmlDirS = qEnvironmentVariableIsSet("OMNI_QML_DIR") ? qEnvironmentVariable("OMNI_QML_DIR") : QStringLiteral(OMNI_QML_DIR);
        return runSession(app, apps, perf, qmlDirS, renderer, softwareGl, p.isSet(reduced));
    }
    int n = 0;
    if (!p.isSet(demo)) n = apps.load(p.values(appsDir), QLocale::system().name());
    if (n == 0) apps.loadDemo();
    qInfo("applicazioni: %d (%s)", apps.count(), apps.demo() ? "elenco dimostrativo" : "file .desktop del sistema, sola lettura");

    // L'avvio reale è possibile solo con l'elenco del sistema, mai con quello dimostrativo.
    AppLauncher launcher(&apps, p.isSet(realLaunch) && !apps.demo());
    qInfo("avvio delle applicazioni: %s", launcher.enabled() ? "REALE (gio launch / kstart)" : "disattivato (prototipo)");

    QQuickView view;
    const QString qmlDir = qEnvironmentVariableIsSet("OMNI_QML_DIR") ? qEnvironmentVariable("OMNI_QML_DIR") : QStringLiteral(OMNI_QML_DIR);
    view.engine()->addImportPath(qmlDir);
    view.rootContext()->setContextProperty("appModel", &apps);
    // Nome distinto dalla proprietà "appLauncher" di Shell: con lo stesso nome il binding
    // in Main.qml risolverebbe la proprietà stessa (null) invece dell'oggetto C++.
    view.rootContext()->setContextProperty("omniLauncher", &launcher);
    view.rootContext()->setContextProperty("initialScene", p.value(scene));
    view.rootContext()->setContextProperty("initialDark", p.value(theme) != QLatin1String("light"));
    view.rootContext()->setContextProperty("initialReducedMotion", p.isSet(reduced));
    view.rootContext()->setContextProperty("initialAccent", p.value(accent).toInt());
    view.rootContext()->setContextProperty("initialLowPower", p.isSet(lowPower) || softwareGl);
    view.rootContext()->setContextProperty("rendererName", renderer.isEmpty() ? QStringLiteral("non rilevato") : renderer);
    view.rootContext()->setContextProperty("softwareRendering", softwareGl);
    // nome dell'utente della sessione (solo lettura, mostrato nelle Impostazioni rapide)
    view.rootContext()->setContextProperty("currentUser", qEnvironmentVariable("USER", qEnvironmentVariable("USERNAME")));
    view.rootContext()->setContextProperty("shellPerf", &perf);
    // QQuickView non collega da solo Qt.quit() all'applicazione (a differenza di QQmlApplicationEngine).
    QObject::connect(view.engine(), &QQmlEngine::quit, &app, &QCoreApplication::quit, Qt::QueuedConnection);
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    const QStringList wh = p.value(size).split('x');
    view.resize(wh.value(0).toInt() > 0 ? wh.value(0).toInt() : 1600, wh.value(1).toInt() > 0 ? wh.value(1).toInt() : 1000);
    view.setTitle("OMNI Shell — prototipo");
    view.setSource(QUrl::fromLocalFile(QDir(qmlDir).filePath("Main.qml")));
    if (view.status() != QQuickView::Ready) {
        for (const auto &e : view.errors()) qCritical("%s", qPrintable(e.toString()));
        return 1;
    }
    if (p.isSet(fullscreen)) view.showFullScreen(); else view.show();

    if (p.isSet(geometry)) {
        const QString file = p.value(geometry);
        QTimer::singleShot(p.value(delay).toInt(), &view, [&view, file]() {
            QJsonObject out;
            std::function<void(QQuickItem *)> walk = [&](QQuickItem *it) {
                if (!it->objectName().isEmpty() && it->isVisible()) {
                    const QPointF c = it->mapToScene(QPointF(it->width() / 2, it->height() / 2));
                    out[it->objectName()] = QJsonObject{{"x", c.x()}, {"y", c.y()}};
                }
                for (QQuickItem *k : it->childItems()) walk(k);
            };
            walk(view.contentItem());
            QFile f(file);
            const bool ok = f.open(QIODevice::WriteOnly) && f.write(QJsonDocument(out).toJson()) > 0;
            qInfo("geometria %s: %s (%lld elementi)", ok ? "salvata" : "NON salvata", qPrintable(file), qint64(out.size()));
            QCoreApplication::exit(ok ? 0 : 2);
        });
    }

    if (p.isSet(record)) {
        QFile f(p.value(script));
        if (!f.open(QIODevice::ReadOnly)) { qCritical("script delle interazioni non leggibile: %s", qPrintable(p.value(script))); return 1; }
        const QJsonArray steps = QJsonDocument::fromJson(f.readAll()).array();
        auto *rec = new Recorder(&view, steps, p.value(record), 25, &app);
        QObject::connect(rec, &Recorder::done, &app, [](bool ok) { QCoreApplication::exit(ok ? 0 : 2); });
        QTimer::singleShot(p.value(delay).toInt(), rec, [rec]() { if (!rec->start()) QCoreApplication::exit(2); });
    }

    if (p.isSet(shot)) {
        const QString file = p.value(shot);
        QTimer::singleShot(p.value(delay).toInt(), &view, [&view, file]() {
            const QImage img = view.grabWindow();
            const bool ok = !img.isNull() && img.save(file);
            qInfo("schermata %s: %s (%dx%d)", ok ? "salvata" : "NON salvata", qPrintable(file), img.width(), img.height());
            QCoreApplication::exit(ok ? 0 : 2);
        });
    }
    return app.exec();
}
