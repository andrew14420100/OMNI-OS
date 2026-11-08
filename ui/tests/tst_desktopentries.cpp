#include "desktopentries.h"
#include <QTemporaryDir>
#include <QTest>
#include <QFile>

// Test del lettore di file .desktop (sola lettura).
class TestDesktopEntries : public QObject {
    Q_OBJECT
    QTemporaryDir dir;
    void write(const QString &rel, const QByteArray &content) {
        QFile f(dir.filePath(rel));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(content);
    }
private slots:
    void initTestCase() {
        QVERIFY(dir.isValid());
        write("visibile.desktop", "[Desktop Entry]\nType=Application\nName=Editor\nName[it]=Editor di testo\nComment=Edit\nComment[it]=Modifica testi\nIcon=editor\nCategories=Utility;TextEditor;\n");
        write("nascosta.desktop", "[Desktop Entry]\nType=Application\nName=Nascosta\nNoDisplay=true\n");
        write("hidden.desktop", "[Desktop Entry]\nType=Application\nName=Hidden\nHidden=true\n");
        write("link.desktop", "[Desktop Entry]\nType=Link\nName=Collegamento\nURL=https://example.org\n");
        write("senza-nome.desktop", "[Desktop Entry]\nType=Application\n");
        write("azioni.desktop", "[Desktop Entry]\nType=Application\nName=Browser\n\n[Desktop Action nuova]\nName=Nuova finestra\n");
        write("zeta.desktop", "# commento\n[Desktop Entry]\nType=Application\nName=Zeta\n");
    }
    void parseLocalized() {
        DesktopEntry e;
        QVERIFY(DesktopEntryModel::parseFile(dir.filePath("visibile.desktop"), "it_IT", &e));
        QCOMPARE(e.name, QString("Editor di testo"));
        QCOMPARE(e.comment, QString("Modifica testi"));
        QCOMPARE(e.icon, QString("editor"));
        QCOMPARE(e.categories, QStringList({"Utility", "TextEditor"}));
    }
    void parseFallbackLocale() {
        DesktopEntry e;
        QVERIFY(DesktopEntryModel::parseFile(dir.filePath("visibile.desktop"), "de_DE", &e));
        QCOMPARE(e.name, QString("Editor"));
    }
    void excluded_data() {
        QTest::addColumn<QString>("file");
        QTest::newRow("NoDisplay") << "nascosta.desktop";
        QTest::newRow("Hidden") << "hidden.desktop";
        QTest::newRow("Type=Link") << "link.desktop";
        QTest::newRow("senza Name") << "senza-nome.desktop";
    }
    void excluded() {
        QFETCH(QString, file);
        DesktopEntry e;
        QVERIFY(!DesktopEntryModel::parseFile(dir.filePath(file), "it_IT", &e));
    }
    void actionNameDoesNotOverrideMain() {
        DesktopEntry e;
        QVERIFY(DesktopEntryModel::parseFile(dir.filePath("azioni.desktop"), "it_IT", &e));
        QCOMPARE(e.name, QString("Browser"));
    }
    void modelLoadsSortedAndFiltered() {
        DesktopEntryModel m;
        QCOMPARE(m.load({dir.path()}, "it_IT"), 3);
        QCOMPARE(m.get(0).value("name").toString(), QString("Browser"));
        QCOMPARE(m.get(2).value("name").toString(), QString("Zeta"));
        QVERIFY(!m.demo());
    }
    void demoListIsMarked() {
        DesktopEntryModel m;
        m.loadDemo();
        QVERIFY(m.demo());
        QVERIFY(m.count() >= 10);
    }
};
QTEST_GUILESS_MAIN(TestDesktopEntries)
#include "tst_desktopentries.moc"
