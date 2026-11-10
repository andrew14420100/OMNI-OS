// Prova di caricamento delle app OMNI con gli oggetti C++ reali: ogni pagina di OMNI Settings
// (e le altre app) si carica senza errori QML; i servizi KDE assenti nell'ambiente di prova
// devono risultare "non disponibili" senza bloccare l'interfaccia.
#include "desktopentries.h"
#include "applauncher.h"
#include "omnisystem.h"
#include "sessionactions.h"
#include "shellservices.h"
#include "systemstatus.h"
#include "systemmonitor.h"
#include "filemanager.h"
#include <QtQml/qqml.h>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QtTest>

class TestApps : public QObject {
    Q_OBJECT
    QTemporaryDir tmp;
    DesktopEntryModel apps;
    AppLauncher *launcher = nullptr;
    SystemStatus system;
    SessionActions session;
    KWinActions kwin;
    ShellSettings *settings = nullptr;
    OmniSystem omni;
    ShellPerf perf;
    void setup(QQmlApplicationEngine &engine, QStringList &warnings) {
        engine.addImportPath(QStringLiteral(OMNI_QML_SRC));
        engine.addImageProvider(QStringLiteral("omniicon"), new ThemeIconProvider);
        auto *c = engine.rootContext();
        c->setContextProperty("appModel", &apps);
        c->setContextProperty("omniLauncher", launcher);
        c->setContextProperty("systemStatus", &system);
        c->setContextProperty("sessionActions", &session);
        c->setContextProperty("kwinActions", &kwin);
        c->setContextProperty("shellSettings", settings);
        c->setContextProperty("omniSystem", &omni);
        c->setContextProperty("shellPerf", &perf);
        c->setContextProperty("rendererName", QStringLiteral("test"));
        c->setContextProperty("softwareRendering", true);
        c->setContextProperty("currentUser", QStringLiteral("Prova"));
        connect(&engine, &QQmlEngine::warnings, this, [&warnings](const QList<QQmlError> &w) { for (const auto &e : w) warnings << e.toString(); });
    }
    static QStringList serious(const QStringList &w) {
        QStringList out;
        for (const auto &x : w)
            if (!x.contains(QLatin1String("servizio NON disponibile")) && !x.contains(QLatin1String("Failed to get image"))) out << x;
        return out;
    }
private slots:
    void initTestCase() {
        qputenv("XDG_DATA_HOME", tmp.filePath(QStringLiteral("dati")).toUtf8());   // cestino di prova
        qmlRegisterType<SystemMonitor>("OmniSystemMonitor", 1, 0, "SystemMonitor");
        qmlRegisterType<FolderModel>("OmniFiles", 1, 0, "FolderModel");
        qmlRegisterType<FileOps>("OmniFiles", 1, 0, "FileOps");
        apps.load({QStringLiteral(OMNI_TEST_APPS)}, QStringLiteral("it_IT"));
        launcher = new AppLauncher(&apps, false, this);
        settings = new ShellSettings(tmp.filePath("omni-shell.conf"), this);
    }
    void impostazioniTutteLePagine() {
        QQmlApplicationEngine engine;
        QStringList warnings;
        setup(engine, warnings);
        engine.load(QUrl::fromLocalFile(QStringLiteral(OMNI_QML_SRC "/apps/SettingsApp.qml")));
        QVERIFY2(!engine.rootObjects().isEmpty(), qPrintable(warnings.join('\n')));
        QObject *root = engine.rootObjects().first();
        const QVariantList sections = root->property("sections").toList();
        QVERIFY(sections.size() >= 15);
        for (const QVariant &s : sections) {
            const QString id = s.toMap().value("id").toString();
            root->setProperty("current", id);
            QTest::qWait(50);
            QObject *loader = root->findChild<QObject *>(QStringLiteral("app:pagina"));
            QVERIFY2(loader, qPrintable(id));
            QTRY_VERIFY2_WITH_TIMEOUT(loader->property("status").toInt() == 1, qPrintable(id + QLatin1Char(' ') + loader->property("source").toString() + QLatin1Char('\n') + serious(warnings).join('\n')), 3000);
        }
        // preferenze condivise: la pagina Notifiche scrive lo stesso valore letto dalla barra
        settings->setDoNotDisturb(true);
        QVERIFY(settings->doNotDisturb());
        const QStringList bad = serious(warnings);
        QVERIFY2(bad.isEmpty(), qPrintable(bad.join('\n')));
    }
    void altreApp_data() {
        QTest::addColumn<QString>("file");
        for (const char *f : {"TaskManagerApp.qml", "ExplorerApp.qml", "StoreApp.qml"}) QTest::newRow(f) << QString::fromLatin1(f);
    }
    void altreApp() {
        QFETCH(QString, file);
        const QString path = QStringLiteral(OMNI_QML_SRC "/apps/") + file;
        if (!QFile::exists(path)) QSKIP("app non ancora presente");
        QQmlApplicationEngine engine;
        QStringList warnings;
        setup(engine, warnings);
        engine.load(QUrl::fromLocalFile(path));
        QVERIFY2(!engine.rootObjects().isEmpty(), qPrintable(warnings.join('\n')));
        QObject *root = engine.rootObjects().first();
        for (const QVariant &s : root->property("sections").toList()) {
            const QString id = s.toMap().value("id").toString();
            root->setProperty("current", id);
            QTest::qWait(1200);   // almeno un campionamento reale per pagina
            QObject *loader = root->findChild<QObject *>(QStringLiteral("app:pagina"));
            QVERIFY2(loader, qPrintable(id));
            QTRY_VERIFY2_WITH_TIMEOUT(loader->property("status").toInt() == 1, qPrintable(id + QLatin1Char('\n') + serious(warnings).join('\n')), 3000);
        }
        if (file == QLatin1String("ExplorerApp.qml")) {   // operazioni reali in una cartella di prova
            const QString dir = tmp.filePath(QStringLiteral("esplora"));
            QDir().mkpath(dir + QStringLiteral("/Cartella"));
            QFile f(dir + QStringLiteral("/nota.txt")); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("ciao"); f.close();
            QMetaObject::invokeMethod(root, "navigate", Q_ARG(QVariant, dir), Q_ARG(QVariant, false));
            QObject *list = root->findChild<QObject *>(QStringLiteral("esplora:elenco"));
            QVERIFY(list);
            QTRY_COMPARE(list->property("count").toInt(), 2);
            root->setProperty("selection", QStringList{dir + QStringLiteral("/nota.txt")});
            QMetaObject::invokeMethod(root, "trashSel");
            QTRY_VERIFY_WITH_TIMEOUT(!QFile::exists(dir + QStringLiteral("/nota.txt")), 5000);
            QTRY_COMPARE(list->property("count").toInt(), 1);
            QMetaObject::invokeMethod(root, "openTrash");
            QTRY_VERIFY(root->property("trashList").toList().size() == 1);
            root->setProperty("selection", QStringList{root->property("trashList").toList().first().toMap().value("path").toString()});
            QMetaObject::invokeMethod(root, "restoreSel");
            QVERIFY(QFile::exists(dir + QStringLiteral("/nota.txt")));
            // eliminazione definitiva: solo dopo conferma esplicita
            QMetaObject::invokeMethod(root, "navigate", Q_ARG(QVariant, dir), Q_ARG(QVariant, false));
            root->setProperty("selection", QStringList{dir + QStringLiteral("/nota.txt")});
            QMetaObject::invokeMethod(root, "askDelete");
            QObject *confirm = root->findChild<QObject *>(QStringLiteral("esplora:conferma"));
            QVERIFY(confirm && confirm->property("visible").toBool());
            QTest::qWait(200);
            QVERIFY(QFile::exists(dir + QStringLiteral("/nota.txt")));
            confirm->setProperty("visible", false);
            QMetaObject::invokeMethod(root, "goBack");
        }
        if (file == QLatin1String("TaskManagerApp.qml")) {   // dati reali di /proc, non vuoti
            QObject *mon = root->property("mon").value<QObject *>();
            QVERIFY(mon);
            QVERIFY(mon->property("processCount").toInt() > 1);
            QVERIFY(mon->property("memTotalMb").toDouble() > 0);
            QVERIFY(mon->property("cpuHistory").toList().size() > 1);
        }
        const QStringList bad = serious(warnings);
        QVERIFY2(bad.isEmpty(), qPrintable(bad.join('\n')));
    }
};

QTEST_MAIN(TestApps)
#include "tst_apps.moc"
