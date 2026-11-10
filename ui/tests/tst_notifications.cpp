// Server delle notifiche sul bus D-Bus REALE (da eseguire in dbus-run-session):
// un client esterno (gdbus) invia, sostituisce e revoca notifiche come farebbe un'app.
#include "notificationserver.h"
#include <QProcess>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QtTest>

class TestNotifications : public QObject {
    Q_OBJECT
    NotificationServer server;
    static QString gdbus(const QStringList &args) {
        QProcess p;
        p.start(QStringLiteral("gdbus"), QStringList{"call", "--session", "--dest", "org.freedesktop.Notifications",
                                                     "--object-path", "/org/freedesktop/Notifications"} + args);
        // il server risponde dal ciclo di eventi di questo processo: si attende senza bloccarlo
        for (int i = 0; i < 100 && p.state() != QProcess::NotRunning; ++i) QTest::qWait(50);
        return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
    }
private slots:
    void initTestCase() {
        if (QStandardPaths::findExecutable("gdbus").isEmpty()) QSKIP("gdbus non disponibile");
        QVERIFY2(server.registerOnBus(), qPrintable(server.status()));
        QVERIFY(server.available());
    }
    void secondoServerNonRubaIlNome() {
        NotificationServer other;
        QVERIFY(!other.registerOnBus());          // il nome resta al primo server
        QVERIFY(!other.available());
        QVERIFY(server.available());
    }
    void informazioniDelServer() {
        QVERIFY(gdbus({"--method", "org.freedesktop.Notifications.GetServerInformation"}).contains("OMNI Shell"));
        QVERIFY(gdbus({"--method", "org.freedesktop.Notifications.GetCapabilities"}).contains("actions"));
    }
    void notificaDaUnApplicazione() {
        QSignalSpy popups(&server, &NotificationServer::popupRequested);
        const QString out = gdbus({"--method", "org.freedesktop.Notifications.Notify", "Prova", "0", "dialog-information",
                                   "Titolo reale", "Corpo", "['ok', 'Va bene']", "{'urgency': <byte 1>}", "5000"});
        QVERIFY2(out.startsWith("(uint32 "), qPrintable(out));
        QCOMPARE(server.count(), 1);
        QCOMPARE(popups.count(), 1);
        const QModelIndex i = server.index(0);
        QCOMPARE(server.data(i, NotificationServer::SummaryRole).toString(), QString("Titolo reale"));
        QCOMPARE(server.data(i, NotificationServer::AppNameRole).toString(), QString("Prova"));
        QCOMPARE(server.data(i, NotificationServer::ActionsRole).toList().size(), 1);
    }
    void sostituzioneERevoca() {
        const uint id = server.data(server.index(0), NotificationServer::IdRole).toUInt();
        gdbus({"--method", "org.freedesktop.Notifications.Notify", "Prova", QString::number(id), "''", "Aggiornata", "''", "[]", "{}", "int32 -1"});
        QCOMPARE(server.count(), 1);
        QCOMPARE(server.data(server.index(0), NotificationServer::SummaryRole).toString(), QString("Aggiornata"));
        QSignalSpy closed(&server, &NotificationServer::notificationClosed);
        gdbus({"--method", "org.freedesktop.Notifications.CloseNotification", QString::number(id)});
        QCOMPARE(server.count(), 0);
        QCOMPARE(closed.count(), 1);
        QCOMPARE(closed.at(0).at(1).toUInt(), 3u);   // revocata dall'applicazione
    }
    void nonDisturbareTieneLaCronologia() {
        server.setDoNotDisturb(true);
        QSignalSpy popups(&server, &NotificationServer::popupRequested);
        gdbus({"--method", "org.freedesktop.Notifications.Notify", "Prova", "0", "''", "Silenziosa", "''", "[]", "{}", "int32 -1"});
        QCOMPARE(server.count(), 1);
        QCOMPARE(popups.count(), 0);
        gdbus({"--method", "org.freedesktop.Notifications.Notify", "Prova", "0", "''", "Critica", "''", "[]", "{'urgency': <byte 2>}", "int32 -1"});
        QCOMPARE(popups.count(), 1);
        server.setDoNotDisturb(false);
        server.clearAll();
        QCOMPARE(server.count(), 0);
    }
};

QTEST_GUILESS_MAIN(TestNotifications)
#include "tst_notifications.moc"
