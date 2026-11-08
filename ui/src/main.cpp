// OMNI Shell — prototipo anticipato dell'interfaccia (non M4).
// Normale applicazione utente: nessun privilegio, nessuna modifica alla sessione KDE,
// nessun servizio di sistema. Opzioni utili per catturare schermate reali:
//   --scene desktop|launcher|notifications|quicksettings
//   --theme dark|light   --reduced-motion   --demo-apps   --apps-dir DIR
//   --size 1600x1000     --screenshot FILE.png [--delay MS]
#include "desktopentries.h"
#include "recorder.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <functional>
#include <QCommandLineParser>
#include <QDir>
#include <QFont>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QQuickWindow>
#include <QTimer>

#ifndef OMNI_QML_DIR
#define OMNI_QML_DIR "qml"
#endif

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("omni-shell-prototipo");
    QGuiApplication::setFont(QFont("Inter", 10));
    // I testi del prototipo sono in italiano: se la lingua di sistema non è disponibile
    // (es. "C" nella CI) si usa l'italiano anche per date e numeri.
    if (QLocale::system().language() == QLocale::C) QLocale::setDefault(QLocale(QLocale::Italian, QLocale::Italy));

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
    QCommandLineOption fullscreen("fullscreen", "Finestra a schermo intero (prova nella sessione Plasma)");
    QCommandLineOption geometry("dump-geometry", "Scrive in JSON il centro degli elementi con objectName e termina", "file");
    QCommandLineOption accent("accent", "Colore d'accento (0 Aurora, 1 Iris, 2 Corallo, 3 Giada)", "n", "0");
    p.addOptions({scene, theme, reduced, demo, appsDir, size, shot, delay, accent, record, script, fullscreen, geometry});
    p.process(app);

    // piattaforma grafica effettiva (es. "wayland" nella sessione Plasma) e versione di Qt in uso
    qInfo("piattaforma: %s; Qt in esecuzione: %s (compilato con %s)", qPrintable(QGuiApplication::platformName()), qVersion(), QT_VERSION_STR);

    DesktopEntryModel apps;
    int n = 0;
    if (!p.isSet(demo)) n = apps.load(p.values(appsDir), QLocale::system().name());
    if (n == 0) apps.loadDemo();
    qInfo("applicazioni: %d (%s)", apps.count(), apps.demo() ? "elenco dimostrativo" : "file .desktop del sistema, sola lettura");

    QQuickView view;
    const QString qmlDir = qEnvironmentVariableIsSet("OMNI_QML_DIR") ? qEnvironmentVariable("OMNI_QML_DIR") : QStringLiteral(OMNI_QML_DIR);
    view.engine()->addImportPath(qmlDir);
    view.rootContext()->setContextProperty("appModel", &apps);
    view.rootContext()->setContextProperty("initialScene", p.value(scene));
    view.rootContext()->setContextProperty("initialDark", p.value(theme) != QLatin1String("light"));
    view.rootContext()->setContextProperty("initialReducedMotion", p.isSet(reduced));
    view.rootContext()->setContextProperty("initialAccent", p.value(accent).toInt());
    // nome dell'utente della sessione (solo lettura, mostrato nelle Impostazioni rapide)
    view.rootContext()->setContextProperty("currentUser", qEnvironmentVariable("USER", qEnvironmentVariable("USERNAME")));
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
