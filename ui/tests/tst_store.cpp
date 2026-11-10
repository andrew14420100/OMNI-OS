// Catalogo di OMNI Store: lettura del formato AppStream di Flatpak (dati di prova nello
// stesso formato di Flathub), lingua, ricerca, categorie, app installate e aggiornamenti.
#include "appstream.h"
#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QSysInfo>
#include <QTemporaryDir>
#include <QtTest>

class TestStore : public QObject {
    Q_OBJECT
    QByteArray xml() { QFile f(QStringLiteral(OMNI_APPSTREAM_DIR "/appstream.xml")); return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray(); }
private slots:
    void lettura() {
        const auto apps = AppStreamCatalog::parse(xml(), QStringLiteral("flathub"), QStringLiteral(OMNI_APPSTREAM_DIR "/icons"), QStringLiteral("it_IT"));
        QCOMPARE(apps.size(), 2);   // il runtime non è un'applicazione
        const StoreApp &e = apps.at(0);
        QCOMPARE(e.id, QStringLiteral("org.esempio.Editor"));
        QCOMPARE(e.name, QStringLiteral("Editor di prova IT"));
        QCOMPARE(e.summary, QStringLiteral("Modifica testi"));
        QVERIFY(e.description.contains(QStringLiteral("Paragrafo italiano")));
        QVERIFY(e.description.contains(QStringLiteral("• Funzione")));
        QVERIFY(!e.description.contains(QStringLiteral("Default paragraph")));
        QVERIFY(e.icon.endsWith(QStringLiteral("128x128/org.esempio.Editor.png")));
        QCOMPARE(e.version, QStringLiteral("2.1"));
        QCOMPARE(e.released, qint64(1700000000));
        QCOMPARE(e.license, QStringLiteral("GPL-3.0-or-later"));
        QCOMPARE(e.ref, QStringLiteral("app/org.esempio.Editor/x86_64/stable"));
        QCOMPARE(e.screenshot, QStringLiteral("https://example.org/s.png"));
        QCOMPARE(e.categories, (QStringList{QStringLiteral("Utility"), QStringLiteral("Office")}));
        const StoreApp &g = apps.at(1);
        QCOMPARE(g.id, QStringLiteral("org.esempio.Gioco"));
        QCOMPARE(g.developer, QStringLiteral("Studio"));
        QVERIFY(g.released > 0);
        QVERIFY(g.icon.isEmpty());
        // lingua senza traduzioni: testi predefiniti
        const auto en = AppStreamCatalog::parse(xml(), QStringLiteral("flathub"), QString(), QStringLiteral("de_DE"));
        QCOMPARE(en.at(0).name, QStringLiteral("Editor di prova"));
        QVERIFY(en.at(0).description.contains(QStringLiteral("Default paragraph")));
    }
    void catalogo() {
        QTemporaryDir root;
        const QString active = root.path() + QStringLiteral("/flathub/") + QSysInfo::currentCpuArchitecture() + QStringLiteral("/active");
        QDir().mkpath(active);
        QVERIFY(QFile::copy(QStringLiteral(OMNI_APPSTREAM_DIR "/appstream.xml"), active + QStringLiteral("/appstream.xml")));
        AppStreamCatalog c;
        c.setRoots({root.path(), root.path() + QStringLiteral("/manca")});
        QSignalSpy spy(&c, &AppStreamCatalog::loadingChanged);
        c.reload();
        QTRY_VERIFY_WITH_TIMEOUT(!c.loading(), 5000);
        QCOMPARE(c.total(), 2);
        QCOMPARE(c.sources(), QStringList{QStringLiteral("flathub")});
        QCOMPARE(c.lastError(), QString());
        c.setCategory(QStringLiteral("Game"));
        QCOMPARE(c.count(), 1);
        c.setCategory({});
        c.setSearch(QStringLiteral("gioc"));   // nome, senza distinzione di maiuscole
        QCOMPARE(c.count(), 1);
        c.setSearch({});
        c.setSortKey(QStringLiteral("recent"));
        QCOMPARE(c.at(0).value("appId").toString(), QStringLiteral("org.esempio.Gioco"));   // 2025 > 2023
        c.setInstalled(QStringLiteral("org.esempio.Editor\tEditor\t2.0\tflathub\tuser\norg.altro.App\tAltra\t1\tfedora\tsystem\n"));
        QCOMPARE(c.installed().size(), 2);
        QVERIFY(c.get(QStringLiteral("org.esempio.Editor")).value("installed").toBool());
        QCOMPARE(c.get(QStringLiteral("org.altro.App")).value("inCatalog").toBool(), false);
        c.setUpdates(QStringLiteral("org.esempio.Editor\t2.1\n"));
        QCOMPARE(c.updates().size(), 1);
        QVERIFY(c.get(QStringLiteral("org.esempio.Editor")).value("updateAvailable").toBool());
        // nessun catalogo scaricato: modello vuoto e messaggio, mai dati inventati
        AppStreamCatalog vuoto;
        vuoto.setRoots({root.path() + QStringLiteral("/manca")});
        vuoto.reload();
        QTRY_VERIFY_WITH_TIMEOUT(!vuoto.loading(), 5000);
        QCOMPARE(vuoto.total(), 0);
        QVERIFY(!vuoto.lastError().isEmpty());
    }
};
QTEST_GUILESS_MAIN(TestStore)
#include "tst_store.moc"
