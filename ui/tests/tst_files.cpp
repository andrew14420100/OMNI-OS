// Operazioni REALI sui file di OMNI Explorer in una cartella temporanea (anche il cestino è
// temporaneo: XDG_DATA_HOME punta alla cartella di prova). Con KIO nel sistema OMNI, con Qt
// nelle prove locali: stesso comportamento verificato.
#include "filemanager.h"
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

class TestFiles : public QObject {
    Q_OBJECT
    QTemporaryDir tmp;
    QString root;
    static void write(const QString &p, const QByteArray &b) { QFile f(p); QVERIFY(f.open(QIODevice::WriteOnly)); f.write(b); }
    static QByteArray read(const QString &p) { QFile f(p); return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray(); }
    static bool wait(FileOps &ops, int id, QString *err = nullptr) {
        QSignalSpy spy(&ops, &FileOps::finished);
        for (int i = 0; i < 200; ++i) {
            for (const auto &a : spy)
                if (a.at(0).toInt() == id) { if (err) *err = a.at(2).toString(); return a.at(1).toBool(); }
            spy.wait(100);
        }
        if (err) *err = QStringLiteral("timeout");
        return false;
    }
private slots:
    void initTestCase() {
        root = tmp.path() + QStringLiteral("/dati");
        QDir().mkpath(root + QStringLiteral("/A/sotto"));
        QDir().mkpath(root + QStringLiteral("/B"));
        write(root + QStringLiteral("/A/uno.txt"), "uno");
        write(root + QStringLiteral("/A/sotto/due.txt"), QByteArray(300000, 'x'));
        write(root + QStringLiteral("/A/.nascosto"), "h");
        write(root + QStringLiteral("/file10.txt"), "10");
        write(root + QStringLiteral("/file2.txt"), "2");
        qInfo("backend: %s", FileOps().kio() ? "KIO" : "Qt");
    }
    void elencoOrdinatoEFiltrato() {
        FolderModel m;
        m.setPath(root);
        QCOMPARE(m.error(), QString());
        QCOMPARE(m.count(), 4);
        QCOMPARE(m.get(0).value("name").toString(), QStringLiteral("A"));          // cartelle prima
        QCOMPARE(m.get(2).value("name").toString(), QStringLiteral("file2.txt"));  // ordine naturale
        QCOMPARE(m.get(3).value("name").toString(), QStringLiteral("file10.txt"));
        m.setDescending(true);
        QCOMPARE(m.get(2).value("name").toString(), QStringLiteral("file10.txt"));
        m.setFilter(QStringLiteral("file1"));
        QCOMPARE(m.count(), 1);
        m.setFilter({});
        m.setPath(root + QStringLiteral("/A"));
        QCOMPARE(m.count(), 2);
        m.setShowHidden(true);
        QCOMPARE(m.count(), 3);
        m.setPath(tmp.path() + QStringLiteral("/manca"));
        QVERIFY(!m.error().isEmpty());
    }
    void ricercaRicorsiva() {
        FolderModel m;
        m.setPath(root);
        m.setSearchText(QStringLiteral("due"));
        QTRY_VERIFY_WITH_TIMEOUT(!m.searching(), 5000);
        QCOMPARE(m.count(), 1);
        QCOMPARE(m.get(0).value("path").toString(), root + QStringLiteral("/A/sotto/due.txt"));
    }
    void aggiornamentoAutomatico() {
        FolderModel m;
        m.setPath(root + QStringLiteral("/B"));
        QCOMPARE(m.count(), 0);
        write(root + QStringLiteral("/B/nuovo.txt"), "n");
        QTRY_COMPARE_WITH_TIMEOUT(m.count(), 1, 5000);
        QFile::remove(root + QStringLiteral("/B/nuovo.txt"));
        QTRY_COMPARE_WITH_TIMEOUT(m.count(), 0, 5000);
    }
    void copiaSpostaRinomina() {
        FileOps ops;
        QString err;
        QVERIFY2(wait(ops, ops.copy({root + QStringLiteral("/A")}, root + QStringLiteral("/B")), &err), qPrintable(err));
        QCOMPARE(read(root + QStringLiteral("/B/A/sotto/due.txt")).size(), 300000);
        // seconda copia: nessuna sovrascrittura, nome nuovo
        QVERIFY2(wait(ops, ops.copy({root + QStringLiteral("/file2.txt")}, root + QStringLiteral("/B")), &err), qPrintable(err));
        QVERIFY2(wait(ops, ops.copy({root + QStringLiteral("/file2.txt")}, root + QStringLiteral("/B")), &err), qPrintable(err));
        QCOMPARE(QDir(root + QStringLiteral("/B")).entryList({QStringLiteral("file2*")}, QDir::Files).size(), 2);
        QCOMPARE(read(root + QStringLiteral("/file2.txt")), QByteArray("2"));
        QVERIFY2(wait(ops, ops.move({root + QStringLiteral("/B/A")}, root), &err), qPrintable(err));   // esiste già "A": rinomina automatica
        QVERIFY(!QFileInfo::exists(root + QStringLiteral("/B/A")));
        QVERIFY(QFileInfo::exists(root + QStringLiteral("/A/uno.txt")));
        QCOMPARE(ops.mkdir(root, QStringLiteral("Nuova")), QString());
        QVERIFY(!ops.mkdir(root, QStringLiteral("Nuova")).isEmpty());
        QVERIFY(!ops.mkdir(root, QStringLiteral("../fuori")).isEmpty());
        QCOMPARE(ops.rename(root + QStringLiteral("/Nuova"), QStringLiteral("Rinominata")), QString());
        QVERIFY(QFileInfo(root + QStringLiteral("/Rinominata")).isDir());
        QVERIFY(!ops.rename(root + QStringLiteral("/Rinominata"), QStringLiteral("A")).isEmpty());   // esiste già
        QCOMPARE(ops.uniqueName(root, QStringLiteral("file2.txt")), QStringLiteral("file2 (2).txt"));
    }
    void cestinoERipristino() {
        FileOps ops;
        QString err;
        write(root + QStringLiteral("/da-cestinare.txt"), "c");
        QVERIFY2(wait(ops, ops.trash({root + QStringLiteral("/da-cestinare.txt")}), &err), qPrintable(err));
        QVERIFY(!QFileInfo::exists(root + QStringLiteral("/da-cestinare.txt")));
        QVariantList items = ops.trashItems();
        QString name;
        for (const auto &v : items) if (v.toMap().value("originalPath").toString() == root + QStringLiteral("/da-cestinare.txt")) name = v.toMap().value("trashName").toString();
        QVERIFY2(!name.isEmpty(), qPrintable(ops.trashDir()));
        QCOMPARE(ops.restore({name}), QString());
        QCOMPARE(read(root + QStringLiteral("/da-cestinare.txt")), QByteArray("c"));
        // eliminazione dal cestino
        QVERIFY2(wait(ops, ops.trash({root + QStringLiteral("/da-cestinare.txt")}), &err), qPrintable(err));
        items = ops.trashItems();
        QVERIFY(!items.isEmpty());
        QCOMPARE(ops.removeFromTrash({items.first().toMap().value("trashName").toString()}), QString());
        QCOMPARE(ops.trashItems().size(), items.size() - 1);
        ops.removeFromTrash({QStringLiteral("../../dati")});   // nomi con percorso ignorati: nessuna uscita dal cestino
        QVERIFY(QFileInfo::exists(root));
    }
    void eliminazioneDefinitivaEPermessi() {
        FileOps ops;
        QString err;
        QVERIFY2(wait(ops, ops.remove({root + QStringLiteral("/Rinominata")}), &err), qPrintable(err));
        QVERIFY(!QFileInfo::exists(root + QStringLiteral("/Rinominata")));
        QCOMPARE(ops.setPermissions(root + QStringLiteral("/file2.txt"), 0600), QString());
        QCOMPARE(ops.properties(root + QStringLiteral("/file2.txt")).value("mode").toInt(), 0600);
        QCOMPARE(ops.setPermissions(root + QStringLiteral("/file2.txt"), 04755), QString());   // setuid ignorato
        QCOMPARE(ops.properties(root + QStringLiteral("/file2.txt")).value("mode").toInt(), 0755);
        const QVariantMap p = ops.properties(root + QStringLiteral("/A"));
        QVERIFY(p.value("isDir").toBool());
        QVERIFY(p.value("mine").toBool());
        QSignalSpy size(&ops, &FileOps::sizeReady);
        const int id = ops.folderSize(root + QStringLiteral("/A"));
        QVERIFY(size.wait(5000));
        QCOMPARE(size.first().at(0).toInt(), id);
        QCOMPARE(size.first().at(1).toLongLong(), qint64(300000 + 3 + 1));
    }
    void zip() {
        FileOps ops;
        if (!ops.zip()) QSKIP("KArchive non presente in questo ambiente (presente nel sistema OMNI)");
        QString err;
        QVERIFY2(wait(ops, ops.compress({root + QStringLiteral("/A")}, root + QStringLiteral("/a.zip")), &err), qPrintable(err));
        QVERIFY(QFileInfo(root + QStringLiteral("/a.zip")).size() > 0);
        QVERIFY2(wait(ops, ops.extract(root + QStringLiteral("/a.zip"), root + QStringLiteral("/estratto")), &err), qPrintable(err));
        QCOMPARE(read(root + QStringLiteral("/estratto/A/sotto/due.txt")).size(), 300000);
    }
    void annullamento() {
        FileOps ops;
        write(root + QStringLiteral("/grande.bin"), QByteArray(64 << 20, 'g'));
        const int id = ops.copy({root + QStringLiteral("/grande.bin")}, root + QStringLiteral("/B"));
        ops.cancel(id);
        QString err;
        const bool ok = wait(ops, id, &err);
        // annullata prima della fine, oppure (macchina molto veloce) già completata per intero
        if (!ok) QCOMPARE(err, QStringLiteral("Annullato"));   // mai dichiarata riuscita
        else QCOMPARE(QFileInfo(root + QStringLiteral("/B/grande.bin")).size(), qint64(64 << 20));
        QVERIFY(ops.jobs().isEmpty());
    }
};

int main(int argc, char **argv) {
    QTemporaryDir data;
    qputenv("XDG_DATA_HOME", data.path().toUtf8());   // cestino di prova, mai quello reale
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    TestFiles t;
    return QTest::qExec(&t, argc, argv);
}
#include "tst_files.moc"
