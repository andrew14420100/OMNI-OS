#include "shellservices.h"
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QFileInfo>
#include <QIcon>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <QQuickWindow>
#include <functional>
#include <QUrl>

void ShellPerf::mark(const QString &event) {
    if (m_done.contains(event)) return;
    m_done << event;
    qInfo("OMNI Shell: %s dopo %lld ms dall'avvio del processo", qPrintable(event), m_t.elapsed());
}

qint64 ShellPerf::epochMs() const { return QDateTime::currentMSecsSinceEpoch(); }

PlasmaShellProxy::PlasmaShellProxy(QObject *parent) : QObject(parent) {}

bool PlasmaShellProxy::registerOnBus() {
    auto bus = QDBusConnection::sessionBus();
    // Solo se il pannello di Plasma non è in esecuzione (sessione OMNI): mai sottrarre il nome.
    m_registered = bus.registerObject(QStringLiteral("/PlasmaShell"), this, QDBusConnection::ExportScriptableSlots)
                && bus.registerService(QStringLiteral("org.kde.plasmashell"));
    qInfo("tasto Meta: %s", m_registered ? "collegato al menu Start di OMNI" : "non collegato (org.kde.plasmashell già in uso)");
    return m_registered;
}

void PlasmaShellProxy::activateLauncherMenu() { emit startRequested(); }
void PlasmaShellProxy::toggleDashboard() { emit showDesktopRequested(); }

QPixmap ThemeIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) {
    const QSize s = requestedSize.isValid() && requestedSize.width() > 0 ? requestedSize : QSize(64, 64);
    const QString name = QUrl::fromPercentEncoding(id.toUtf8());
    QIcon icon;
    if (name.startsWith(QLatin1Char('/')) && QFileInfo::exists(name)) icon = QIcon(name);
    else icon = QIcon::fromTheme(name);
    if (icon.isNull()) icon = QIcon::fromTheme(QStringLiteral("application-x-executable"));
    QPixmap px = icon.pixmap(s);
    if (px.isNull()) { px = QPixmap(s); px.fill(Qt::transparent); }   // nessun tema di icone: spazio vuoto
    if (size) *size = px.size();
    return px;
}

namespace {
void kwinCall(KWinActions *self, QDBusMessage msg, const QString &what) {
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), self);
    QObject::connect(w, &QDBusPendingCallWatcher::finished, self, [self, w, what]() {
        QDBusPendingReply<> r = *w;
        if (r.isError()) {
            qWarning("kwin: %s non riuscito: %s", qPrintable(what), qPrintable(r.error().message()));
            emit self->failed(what, r.error().message());
        }
        w->deleteLater();
    });
}
const QString VDM_SVC = QStringLiteral("org.kde.KWin"), VDM_PATH = QStringLiteral("/VirtualDesktopManager"),
              VDM_IFACE = QStringLiteral("org.kde.KWin.VirtualDesktopManager");
}

void KWinActions::invokeShortcut(const QString &name) {
    auto m = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kglobalaccel"), QStringLiteral("/component/kwin"),
                                            QStringLiteral("org.kde.kglobalaccel.Component"), QStringLiteral("invokeShortcut"));
    m << name;
    qInfo("kwin: scorciatoia \"%s\"", qPrintable(name));
    kwinCall(this, m, name);
}

void KWinActions::setCurrentDesktop(const QString &id) {
    auto m = QDBusMessage::createMethodCall(VDM_SVC, VDM_PATH, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Set"));
    m << VDM_IFACE << QStringLiteral("current") << QVariant::fromValue(QDBusVariant(id));
    qInfo("kwin: desktop virtuale corrente -> %s", qPrintable(id));
    kwinCall(this, m, QStringLiteral("cambio di desktop virtuale"));
}

void KWinActions::createDesktop(int position, const QString &name) {
    auto m = QDBusMessage::createMethodCall(VDM_SVC, VDM_PATH, VDM_IFACE, QStringLiteral("createDesktop"));
    m << uint(qMax(0, position)) << name;
    qInfo("kwin: nuovo desktop virtuale \"%s\"", qPrintable(name));
    kwinCall(this, m, QStringLiteral("nuovo desktop virtuale"));
}

void KWinActions::removeDesktop(const QString &id) {
    auto m = QDBusMessage::createMethodCall(VDM_SVC, VDM_PATH, VDM_IFACE, QStringLiteral("removeDesktop"));
    m << id;
    kwinCall(this, m, QStringLiteral("rimozione del desktop virtuale"));
}

void KWinActions::krunnerQuery(const QString &text) {
    auto m = QDBusMessage::createMethodCall(QStringLiteral("org.kde.krunner"), QStringLiteral("/App"),
                                            QStringLiteral("org.kde.krunner.App"), QStringLiteral("query"));
    m << text;
    kwinCall(this, m, QStringLiteral("ricerca di sistema"));
}

bool ShellControl::registerOnBus() {
    auto bus = QDBusConnection::sessionBus();
    const bool ok = bus.registerObject(QStringLiteral("/Shell"), this, QDBusConnection::ExportScriptableSlots)
                 && bus.registerService(QStringLiteral("org.omnios.Shell"));
    qInfo("controllo della shell (org.omnios.Shell): %s", ok ? "registrato" : "non registrato");
    return ok;
}

void ShellControl::Probe(const QString &text) { qInfo("sonda: %s", qPrintable(text.left(200))); }

void ShellControl::ShowPopup(const QString &name) { emit popupRequested(name); }

bool ShellControl::DumpGeometry(const QString &file) {
    QJsonObject windows, items;
    for (QWindow *w : QGuiApplication::topLevelWindows()) {
        auto *qw = qobject_cast<QQuickWindow *>(w);
        if (!qw || !qw->isVisible()) continue;
        const QString win = qw->objectName();
        windows[win] = QJsonObject{{"w", qw->width()}, {"h", qw->height()}};
        std::function<void(QQuickItem *)> walk = [&](QQuickItem *it) {
            if (!it->isVisible() || it->opacity() <= 0.01) return;
            if (!it->objectName().isEmpty() && it->width() > 0 && it->height() > 0) {
                const QPointF c = it->mapToScene(QPointF(it->width() / 2, it->height() / 2));
                items[it->objectName()] = QJsonObject{{"x", c.x()}, {"y", c.y()}, {"win", win}};
            }
            for (QQuickItem *k : it->childItems()) walk(k);
        };
        walk(qw->contentItem());
    }
    QFile f(file);
    const bool ok = f.open(QIODevice::WriteOnly) && f.write(QJsonDocument(QJsonObject{{"windows", windows}, {"items", items}}).toJson()) > 0;
    qInfo("geometria %s: %s (%lld elementi)", ok ? "salvata" : "NON salvata", qPrintable(file), qint64(items.size()));
    return ok;
}

ShellSettings::ShellSettings(const QString &file, QObject *parent) : QObject(parent), m_file(file) {
    if (m_file.isEmpty()) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/omni-os");
        QDir().mkpath(dir);
        m_file = dir + QStringLiteral("/omni-shell.conf");
    }
}
#define OMNI_GET(type, key, def) QSettings(m_file, QSettings::IniFormat).value(QStringLiteral(key), def).value<type>()
bool ShellSettings::dark() const { return OMNI_GET(bool, "dark", true); }
int ShellSettings::accent() const { return OMNI_GET(int, "accent", 0); }
bool ShellSettings::reducedMotion() const { return OMNI_GET(bool, "reducedMotion", false); }
QStringList ShellSettings::startPins() const { return OMNI_GET(QStringList, "startPins", QStringList()); }
QStringList ShellSettings::barPins() const { return OMNI_GET(QStringList, "barPins", QStringList()); }
bool ShellSettings::pinsInitialized() const { return OMNI_GET(bool, "pinsInitialized", false); }
#undef OMNI_GET
void ShellSettings::set(const char *key, const QVariant &v) {
    QSettings st(m_file, QSettings::IniFormat);
    if (st.value(QLatin1String(key)) == v) return;
    st.setValue(QLatin1String(key), v);
    st.sync();
    emit changed();
}

void KWinActions::setSystemReducedMotion(bool reduced) {
    const QStringList args{QStringLiteral("--file"), QStringLiteral("kdeglobals"), QStringLiteral("--group"), QStringLiteral("KDE"),
                           QStringLiteral("--key"), QStringLiteral("AnimationDurationFactor"), reduced ? QStringLiteral("0") : QStringLiteral("1")};
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, reduced](int code, QProcess::ExitStatus) {
        p->deleteLater();
        if (code != 0) { emit failed(QStringLiteral("movimento ridotto"), QStringLiteral("kwriteconfig6 non riuscito")); return; }
        // KWin rilegge la configurazione
        kwinCall(this, QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
                                                      QStringLiteral("org.kde.KWin"), QStringLiteral("reconfigure")), QStringLiteral("riconfigurazione di KWin"));
        qInfo("movimento ridotto di sistema: %s", reduced ? "attivo (animazioni di KWin disattivate)" : "disattivo");
    });
    connect(p, &QProcess::errorOccurred, this, [this, p](QProcess::ProcessError) { p->deleteLater(); emit failed(QStringLiteral("movimento ridotto"), QStringLiteral("kwriteconfig6 non disponibile")); });
    p->start(QStringLiteral("kwriteconfig6"), args);
}

void KWinActions::optimizeForSoftwareRendering() {
    for (const QString &effect : {QStringLiteral("blur"), QStringLiteral("contrast")}) {
        auto m = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
                                                QStringLiteral("org.kde.kwin.Effects"), QStringLiteral("unloadEffect"));
        m << effect;
        kwinCall(this, m, QStringLiteral("effetto ") + effect);
    }
    qInfo("kwin: rendering software, effetti sfocatura e contrasto disattivati per questa sessione");
}
