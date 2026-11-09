#include "shellservices.h"
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QFileInfo>
#include <QIcon>
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
