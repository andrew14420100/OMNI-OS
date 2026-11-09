// AppLauncher: avvio reale solo se abilitato e solo per voci .desktop lette dal modello.
#include "applauncher.h"
#include "desktopentries.h"
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class TestAppLauncher : public QObject {
    Q_OBJECT
    QTemporaryDir dir;
    QString desktopFile;
    void write(const QString &name, const QByteArray &content) {
        QFile f(dir.filePath(name)); QVERIFY(f.open(QIODevice::WriteOnly)); f.write(content);
    }
private slots:
    void initTestCase() {
        QVERIFY(dir.isValid());
        write("prova.desktop", "[Desktop Entry]\nType=Application\nName=Prova\nExec=/bin/true\n");
        desktopFile = QFileInfo(dir.filePath("prova.desktop")).absoluteFilePath();
    }
    void cleanup() { qunsetenv("OMNI_LAUNCH_CMD"); }
    void disabledNeverLaunches() {
        DesktopEntryModel m; m.load({dir.path()});
        AppLauncher l(&m, false);
        QSignalSpy spy(&l, &AppLauncher::launched);
        QVERIFY(!l.launch(desktopFile));
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(1).toBool(), false);
    }
    void rejectsPathsNotInModel() {
        DesktopEntryModel m; m.load({dir.path()});
        AppLauncher l(&m, true);
        qputenv("OMNI_LAUNCH_CMD", "/bin/true");
        QVERIFY(!l.launch("/etc/passwd"));
        QVERIFY(!l.launch(dir.filePath("inesistente.desktop")));
        QVERIFY(!l.launch(QString()));
    }
    void demoModelNeverLaunches() {
        DesktopEntryModel m; m.loadDemo();
        AppLauncher l(&m, true);
        qputenv("OMNI_LAUNCH_CMD", "/bin/true");
        QVERIFY(!l.launch(m.get(0).value("filePath").toString()));
    }
    void launchesKnownEntry() {
        DesktopEntryModel m; m.load({dir.path()});
        QCOMPARE(m.get(0).value("filePath").toString(), desktopFile);
        AppLauncher l(&m, true);
        qputenv("OMNI_LAUNCH_CMD", "/bin/true");
        QSignalSpy spy(&l, &AppLauncher::launched);
        QVERIFY(l.launch(desktopFile));
        QCOMPARE(spy.at(0).at(1).toBool(), true);
    }
    void missingCommandFails() {
        DesktopEntryModel m; m.load({dir.path()});
        AppLauncher l(&m, true);
        qputenv("OMNI_LAUNCH_CMD", "/percorso/inesistente/comando");
        QVERIFY(!l.launch(desktopFile));
    }
    void defaultCommandsUseNoShell() {
        DesktopEntryModel m; m.load({dir.path()});
        AppLauncher l(&m, true);
        const auto cmds = l.commandsFor(desktopFile);
        QCOMPARE(cmds.at(0), (QStringList{"gio", "launch", desktopFile}));
        QCOMPARE(cmds.at(1), (QStringList{"kstart", "--application", "prova"}));
        for (const auto &c : cmds) { QVERIFY(c.first() != "sh"); QVERIFY(c.first() != "bash"); }
    }
};
QTEST_GUILESS_MAIN(TestAppLauncher)
#include "tst_applauncher.moc"
