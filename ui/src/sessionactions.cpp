#include "sessionactions.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusArgument>
#include <QDBusMetaType>

namespace {
const char *L1 = "org.freedesktop.login1";
const char *L1PATH = "/org/freedesktop/login1";
const char *L1IFACE = "org.freedesktop.login1.Manager";
}
// voce di login1.ListInhibitors: (what, who, why, mode, uid, pid)
struct Inhibitor { QString what, who, why, mode; uint uid = 0, pid = 0; };
Q_DECLARE_METATYPE(Inhibitor)
Q_DECLARE_METATYPE(QList<Inhibitor>)
static const QDBusArgument &operator>>(const QDBusArgument &a, Inhibitor &i) {
    a.beginStructure(); a >> i.what >> i.who >> i.why >> i.mode >> i.uid >> i.pid; a.endStructure(); return a;
}
static QDBusArgument &operator<<(QDBusArgument &a, const Inhibitor &i) {
    a.beginStructure(); a << i.what << i.who << i.why << i.mode << i.uid << i.pid; a.endStructure(); return a;
}

SessionActions::SessionActions(QObject *parent) : QObject(parent) {
    qDBusRegisterMetaType<Inhibitor>();
    qDBusRegisterMetaType<QList<Inhibitor>>();
    refresh();
}

void SessionActions::refresh() {
    auto sys = QDBusConnection::systemBus();
    const auto ask = [this, sys](const char *method, auto apply) {
        auto *w = new QDBusPendingCallWatcher(sys.asyncCall(QDBusMessage::createMethodCall(L1, L1PATH, L1IFACE, QString::fromLatin1(method))), this);
        connect(w, &QDBusPendingCallWatcher::finished, this, [this, w, apply]() {
            QDBusPendingReply<QString> r = *w;
            apply(r.isError() ? QStringLiteral("na") : r.value());
            emit capabilitiesChanged();
            w->deleteLater();
        });
    };
    // "yes" o "challenge" (serve autorizzazione): l'azione è possibile
    ask("CanPowerOff", [this](const QString &v) { m_canShutdown = v == QLatin1String("yes") || v == QLatin1String("challenge"); });
    ask("CanReboot", [this](const QString &v) { m_canReboot = v == QLatin1String("yes") || v == QLatin1String("challenge"); });
    ask("CanSuspend", [this](const QString &v) {
        m_canSuspend = v == QLatin1String("yes") || v == QLatin1String("challenge");
        m_suspendNote = m_canSuspend ? QString() : tr("Sospensione non supportata da questo sistema (risposta: %1)").arg(v);
    });
    auto *w = new QDBusPendingCallWatcher(sys.asyncCall(QDBusMessage::createMethodCall(L1, L1PATH, L1IFACE, QStringLiteral("ListInhibitors"))), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w]() {
        QDBusPendingReply<QList<Inhibitor>> r = *w;
        m_inhibitors.clear();
        if (!r.isError()) {
            for (const auto &i : r.value()) {
                if (i.mode == QLatin1String("block") && (i.what.contains(QLatin1String("shutdown")) || i.what.contains(QLatin1String("sleep"))))
                    m_inhibitors << QStringLiteral("%1: %2").arg(i.who, i.why);
            }
        }
        emit inhibitorsChanged();
        w->deleteLater();
    });
}

void SessionActions::ksmserver(const QString &method, const QString &what, const QString &login1Fallback) {
    qInfo("sessione: richiesto %s (org.kde.Shutdown.%s)", qPrintable(what), qPrintable(method));
    emit actionStarted(what);
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"),
                                              QStringLiteral("org.kde.Shutdown"), method);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 15000), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w, what, login1Fallback]() {
        QDBusPendingReply<> r = *w;
        if (r.isError()) {
            qWarning("sessione: org.kde.Shutdown non disponibile (%s)", qPrintable(r.error().message()));
            if (!login1Fallback.isEmpty()) login1(login1Fallback, what);
            else emit actionFailed(what, r.error().message());
        }
        w->deleteLater();
    });
}

void SessionActions::login1(const QString &method, const QString &what) {
    qInfo("sessione: richiesto %s (login1.%s)", qPrintable(what), qPrintable(method));
    auto msg = QDBusMessage::createMethodCall(L1, L1PATH, L1IFACE, method);
    msg << true;   // interattivo: polkit può chiedere l'autorizzazione
    msg.setInteractiveAuthorizationAllowed(true);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg, 60000), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w, what]() {
        QDBusPendingReply<> r = *w;
        if (r.isError()) {
            qWarning("sessione: %s non riuscito: %s", qPrintable(what), qPrintable(r.error().message()));
            emit actionFailed(what, r.error().message());
        }
        w->deleteLater();
    });
}

void SessionActions::shutdown() { ksmserver(QStringLiteral("logoutAndShutdown"), tr("spegnimento"), QStringLiteral("PowerOff")); }
void SessionActions::reboot() { ksmserver(QStringLiteral("logoutAndReboot"), tr("riavvio"), QStringLiteral("Reboot")); }
void SessionActions::logout() { ksmserver(QStringLiteral("logout"), tr("disconnessione"), QString()); }

void SessionActions::suspend() {
    if (!m_canSuspend) { emit actionFailed(tr("sospensione"), m_suspendNote); return; }
    emit actionStarted(tr("sospensione"));
    login1(QStringLiteral("Suspend"), tr("sospensione"));
}

void SessionActions::lock() {
    qInfo("sessione: richiesto blocco dello schermo");
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                                              QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("Lock"));
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w]() {
        QDBusPendingReply<> r = *w;
        if (r.isError()) emit actionFailed(tr("blocco"), r.error().message());
        w->deleteLater();
    });
}
