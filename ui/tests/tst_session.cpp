// Prova di caricamento della sessione OMNI completa (DesktopSession.qml) con gli oggetti C++
// reali. Il modulo org.kde.layershell (presente nel sistema, non nell'ambiente di prova) è
// sostituito da un modulo di prova con la stessa interfaccia: qui si verificano la creazione
// delle superfici, il primo fotogramma, la creazione differita dei pannelli e l'apertura di Start.
#include "desktopentries.h"
#include "applauncher.h"
#include "notificationserver.h"
#include "sessionactions.h"
#include "shellservices.h"
#include "omnisystem.h"
#include "systemstatus.h"
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QtTest>
#include <qqml.h>

namespace Stub {
class LayerWindow : public QObject {
    Q_OBJECT
    Q_PROPERTY(int anchors MEMBER m_anchors)
    Q_PROPERTY(QString scope MEMBER m_scope)
    Q_PROPERTY(int layer MEMBER m_layer)
    Q_PROPERTY(int exclusionZone MEMBER m_zone)
    Q_PROPERTY(int keyboardInteractivity MEMBER m_kb)
public:
    enum Anchor { AnchorNone = 0, AnchorTop = 1, AnchorBottom = 2, AnchorLeft = 4, AnchorRight = 8 };
    Q_ENUM(Anchor)
    enum Layer { LayerBackground = 0, LayerBottom = 1, LayerTop = 2, LayerOverlay = 3 };
    Q_ENUM(Layer)
    enum KeyboardInteractivity { KeyboardInteractivityNone = 0, KeyboardInteractivityExclusive = 1, KeyboardInteractivityOnDemand = 2 };
    Q_ENUM(KeyboardInteractivity)
    using QObject::QObject;
    static LayerWindow *qmlAttachedProperties(QObject *o) { return new LayerWindow(o); }
    int m_anchors = 0, m_layer = 0, m_zone = 0, m_kb = 0;
    QString m_scope;
};
}
QML_DECLARE_TYPEINFO(Stub::LayerWindow, QML_HAS_ATTACHED_PROPERTIES)

class TestSession : public QObject {
    Q_OBJECT
    QTemporaryDir tmp;
private slots:
    void sessioneCompleta() {
        qmlRegisterUncreatableType<Stub::LayerWindow>("org.kde.layershell", 1, 0, "Window", "solo proprietà associate");
        DesktopEntryModel apps;
        apps.load({QStringLiteral(OMNI_TEST_APPS)}, QStringLiteral("it_IT"));
        AppLauncher launcher(&apps, false);
        NotificationServer notes;
        SessionActions session;
        SystemStatus system;
        KWinActions kwin;
        PlasmaShellProxy plasma;
        ShellControl control;
        ShellPerf perf;
        ShellSettings settings(tmp.filePath("omni-shell.conf"));
        QQmlApplicationEngine engine;
        engine.addImportPath(QStringLiteral(OMNI_QML_SRC));
        engine.addImageProvider(QStringLiteral("omniicon"), new ThemeIconProvider);
        auto *c = engine.rootContext();
        c->setContextProperty("appModel", &apps);
        c->setContextProperty("omniLauncher", &launcher);
        c->setContextProperty("notificationServer", &notes);
        c->setContextProperty("sessionActions", &session);
        c->setContextProperty("systemStatus", &system);
        c->setContextProperty("kwinActions", &kwin);
        static OmniSystem omniSys;
        c->setContextProperty("omniSystem", &omniSys);
        c->setContextProperty("plasmaShell", &plasma);
        c->setContextProperty("shellControl", &control);
        c->setContextProperty("shellSettings", &settings);
        c->setContextProperty("shellPerf", &perf);
        c->setContextProperty("rendererName", QStringLiteral("test"));
        c->setContextProperty("softwareRendering", true);
        c->setContextProperty("initialReducedMotion", false);
        c->setContextProperty("currentUser", QStringLiteral("Prova"));
        QStringList warnings;
        connect(&engine, &QQmlEngine::warnings, this, [&](const QList<QQmlError> &w) { for (const auto &e : w) warnings << e.toString(); });
        engine.load(QUrl::fromLocalFile(QStringLiteral(OMNI_QML_SRC "/DesktopSession.qml")));
        QVERIFY2(!engine.rootObjects().isEmpty(), qPrintable(warnings.join('\n')));
        QObject *root = engine.rootObjects().first();

        // superfici create: sfondo, barra (visibili), pannelli e fumetti (nascosti)
        QStringList names;
        for (QWindow *w : QGuiApplication::topLevelWindows()) names << w->objectName();
        for (const char *n : {"sfondo", "barra", "pannelli", "notifiche"}) QVERIFY2(names.contains(QLatin1String(n)), qPrintable(names.join(',')));

        // primo fotogramma -> pannelli creati in background
        QTRY_VERIFY_WITH_TIMEOUT(root->property("panelsReady").toBool(), 10000);
        // preferenze iniziali: solo le app installate fra quelle proposte
        QTRY_VERIFY_WITH_TIMEOUT(settings.pinsInitialized(), 5000);
        QVERIFY(settings.startPins().contains(QStringLiteral("org.kde.konsole.desktop")));
        QVERIFY(settings.barPins().contains(QStringLiteral("applications:org.kde.dolphin.desktop")));

        // tasto Meta (org.kde.plasmashell activateLauncherMenu) -> Start aperto, di nuovo -> chiuso
        emit plasma.startRequested();
        QCOMPARE(root->property("popup").toString(), QStringLiteral("start"));
        QQuickWindow *pop = nullptr;
        for (QWindow *w : QGuiApplication::topLevelWindows()) if (w->objectName() == QLatin1String("pannelli")) pop = qobject_cast<QQuickWindow *>(w);
        QVERIFY(pop);
        QTRY_VERIFY(pop->isVisible());
        emit plasma.startRequested();
        QCOMPARE(root->property("popup").toString(), QString());

        // clic reale sul pulsante Start della barra
        QQuickWindow *bar = nullptr;
        for (QWindow *w : QGuiApplication::topLevelWindows()) if (w->objectName() == QLatin1String("barra")) bar = qobject_cast<QQuickWindow *>(w);
        QVERIFY(bar);
        QQuickItem *startBtn = bar->findChild<QQuickItem *>(QStringLiteral("bar:start"));
        QVERIFY(startBtn);
        const QPointF p = startBtn->mapToScene(QPointF(startBtn->width() / 2, startBtn->height() / 2));
        QTest::mouseClick(bar, Qt::LeftButton, Qt::NoModifier, p.toPoint());
        QTRY_COMPARE(root->property("popup").toString(), QStringLiteral("start"));
        QQuickItem *search = pop->findChild<QQuickItem *>(QStringLiteral("start:search"));
        QTRY_VERIFY(search && search->isVisible());
        pop->requestActivate();
        QTRY_VERIFY(pop->isActive());
        QTest::keyClick(pop, Qt::Key_Escape);
        QTRY_COMPARE(root->property("popup").toString(), QString());
        // orologio -> centro notifiche
        QQuickItem *clock = bar->findChild<QQuickItem *>(QStringLiteral("bar:clock"));
        QVERIFY(clock);
        QTest::mouseClick(bar, Qt::LeftButton, Qt::NoModifier, clock->mapToScene(QPointF(clock->width() / 2, clock->height() / 2)).toPoint());
        QTRY_COMPARE(root->property("popup").toString(), QStringLiteral("notifications"));
        root->setProperty("popup", QString());

        // notifica -> finestra dei fumetti visibile
        notes.postLocal(QStringLiteral("Prova"), QStringLiteral("corpo"));
        QQuickWindow *toast = nullptr;
        for (QWindow *w : QGuiApplication::topLevelWindows()) if (w->objectName() == QLatin1String("notifiche")) toast = qobject_cast<QQuickWindow *>(w);
        QTRY_VERIFY(toast && toast->isVisible());

        // geometria per le prove in VM
        const QString geo = tmp.filePath("geo.json");
        QVERIFY(control.DumpGeometry(geo));
        QFile f(geo);
        QVERIFY(f.open(QIODevice::ReadOnly));
        const QByteArray j = f.readAll();
        QVERIFY(j.contains("\"bar:start\""));
        QVERIFY(j.contains("\"bar:clock\""));

        // personalizzazione da OMNI Settings (altro processo, stesso file): applicata dal vivo
        {
            ShellSettings altroProcesso(tmp.filePath("omni-shell.conf"));
            altroProcesso.setBarSize(56);
            altroProcesso.setDark(false);
        }
        QQuickWindow *barra = nullptr;
        for (QWindow *w : QGuiApplication::topLevelWindows()) if (w->objectName() == QLatin1String("barra")) barra = qobject_cast<QQuickWindow *>(w);
        QVERIFY(barra);
        QTRY_COMPARE_WITH_TIMEOUT(barra->height(), 56, 5000);
        QTRY_VERIFY_WITH_TIMEOUT(!settings.dark(), 5000);

        // nessun errore QML durante il caricamento
        QStringList serious;
        for (const auto &w : warnings) if (!w.contains(QLatin1String("servizio NON disponibile")) && !w.contains(QLatin1String("Failed to get image"))) serious << w;
        QVERIFY2(serious.isEmpty(), qPrintable(serious.join('\n')));
    }
};

QTEST_MAIN(TestSession)
#include "tst_session.moc"
