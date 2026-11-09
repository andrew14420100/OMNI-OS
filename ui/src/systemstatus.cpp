#include "systemstatus.h"
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDBusObjectPath>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStorageInfo>
#include <QTimer>
#include <cmath>

namespace {
QDBusMessage getProp(const QString &svc, const QString &path, const QString &iface, const QString &prop) {
    auto m = QDBusMessage::createMethodCall(svc, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    m << iface << prop;
    return m;
}
}

SystemStatus::SystemStatus(QObject *parent) : QObject(parent) {
    qDBusRegisterMetaType<QList<QVariantMap>>();
    // nessuna lettura qui: refresh() viene chiamato dopo il primo fotogramma (avvio più rapido)
}

void SystemStatus::refresh() {
    refreshNetwork();
    refreshDisplay();
    readPowerProfiles();
    readBrightness();
    readBattery();
    readStorage();
    readSecurity();
}

// --- schermo (KScreen) ---
void SystemStatus::refreshDisplay() {
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p](int code, QProcess::ExitStatus) {
        const auto doc = QJsonDocument::fromJson(p->readAllStandardOutput());
        m_outputs.clear();
        for (const auto &ov : doc.object().value(QStringLiteral("outputs")).toArray()) {
            const auto o = ov.toObject();
            if (!o.value(QStringLiteral("connected")).toBool(true)) continue;
            const QString cur = o.value(QStringLiteral("currentModeId")).toVariant().toString();
            QVariantList modes;
            QString curName;
            for (const auto &mv : o.value(QStringLiteral("modes")).toArray()) {
                const auto m = mv.toObject();
                const auto sz = m.value(QStringLiteral("size")).toObject();
                const int w = sz.value(QStringLiteral("width")).toInt(), h = sz.value(QStringLiteral("height")).toInt();
                const double hz = m.value(QStringLiteral("refreshRate")).toDouble();
                const QString name = QStringLiteral("%1x%2@%3").arg(w).arg(h).arg(qRound(hz));
                const QString id = m.value(QStringLiteral("id")).toVariant().toString();
                modes.append(QVariantMap{{"id", id}, {"name", name}, {"width", w}, {"height", h}, {"refresh", hz}});
                if (id == cur) curName = name;
            }
            m_outputs.append(QVariantMap{{"name", o.value(QStringLiteral("name")).toString()},
                                         {"enabled", o.value(QStringLiteral("enabled")).toBool()},
                                         {"currentMode", curName}, {"currentModeId", cur},
                                         {"scale", o.value(QStringLiteral("scale")).toDouble(1.0)},
                                         {"modes", modes}});
        }
        m_displayStatus = m_outputs.isEmpty() ? tr("Configurazione dello schermo non leggibile (KScreen, codice %1)").arg(code) : QString();
        emit displayChanged();
        p->deleteLater();
    });
    connect(p, &QProcess::errorOccurred, this, [this, p](QProcess::ProcessError) {
        m_displayStatus = tr("kscreen-doctor non disponibile");
        emit displayChanged();
        p->deleteLater();
    });
    p->start(QStringLiteral("kscreen-doctor"), {QStringLiteral("-j")});
}

void SystemStatus::applyDisplay(const QString &output, const QString &mode, double scale) {
    QStringList args;
    if (!mode.isEmpty()) args << QStringLiteral("output.%1.mode.%2").arg(output, mode);
    if (scale > 0) args << QStringLiteral("output.%1.scale.%2").arg(output, QString::number(scale, 'g', 4));
    if (args.isEmpty()) return;
    qInfo("schermo: applico %s", qPrintable(args.join(' ')));
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, output, mode, scale](int code, QProcess::ExitStatus) {
        p->deleteLater();
        // verifica sullo stato effettivo, riletto da KScreen
        QTimer::singleShot(800, this, [this, output, mode, scale, code]() {
            connect(this, &SystemStatus::displayChanged, this, [this, output, mode, scale, code]() {
                for (const auto &v : m_outputs) {
                    const auto o = v.toMap();
                    if (o.value("name").toString() != output) continue;
                    const bool modeOk = mode.isEmpty() || o.value("currentMode").toString() == mode || o.value("currentModeId").toString() == mode;
                    const bool scaleOk = scale <= 0 || std::abs(o.value("scale").toDouble() - scale) < 0.01;
                    const bool ok = modeOk && scaleOk;
                    emit displayApplied(ok, ok ? tr("Applicato: %1, scala %2%").arg(o.value("currentMode").toString()).arg(qRound(o.value("scale").toDouble() * 100))
                                               : tr("Lo schermo non ha accettato la modifica (codice %1)").arg(code));
                    return;
                }
                emit displayApplied(false, tr("Schermo %1 non trovato").arg(output));
            }, Qt::SingleShotConnection);
            refreshDisplay();
        });
    });
    p->start(QStringLiteral("kscreen-doctor"), args);
}

// --- profilo energetico ---
void SystemStatus::readPowerProfiles() {
    const QList<QPair<QString, QString>> services = {
        {QStringLiteral("org.freedesktop.UPower.PowerProfiles"), QStringLiteral("/org/freedesktop/UPower/PowerProfiles")},
        {QStringLiteral("net.hadess.PowerProfiles"), QStringLiteral("/net/hadess/PowerProfiles")}};
    for (const auto &s : services) {
        auto reply = QDBusConnection::systemBus().call(getProp(s.first, s.second, s.first, QStringLiteral("ActiveProfile")), QDBus::Block, 1500);
        if (reply.type() != QDBusMessage::ReplyMessage) continue;
        m_profileService = s.first;
        m_profilePath = s.second;
        m_profile = reply.arguments().value(0).value<QDBusVariant>().variant().toString();
        auto list = QDBusConnection::systemBus().call(getProp(s.first, s.second, s.first, QStringLiteral("Profiles")), QDBus::Block, 1500);
        m_profiles.clear();
        if (list.type() == QDBusMessage::ReplyMessage) {
            const auto arg = list.arguments().value(0).value<QDBusVariant>().variant().value<QDBusArgument>();
            QList<QVariantMap> maps;
            arg >> maps;
            for (const auto &m : maps) m_profiles << m.value(QStringLiteral("Profile")).toString();
        }
        emit powerChanged();
        return;
    }
    m_profile.clear();
    m_profiles.clear();
    emit powerChanged();
}

void SystemStatus::setPowerProfile(const QString &profile) {
    if (m_profileService.isEmpty() || !m_profiles.contains(profile)) { emit failed(tr("profilo energetico"), tr("non disponibile")); return; }
    auto m = QDBusMessage::createMethodCall(m_profileService, m_profilePath, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Set"));
    m << m_profileService << QStringLiteral("ActiveProfile") << QVariant::fromValue(QDBusVariant(profile));
    m.setInteractiveAuthorizationAllowed(true);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(m), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w, profile]() {
        QDBusPendingReply<> r = *w;
        if (r.isError()) emit failed(tr("profilo energetico"), r.error().message());
        qInfo("energia: profilo %s %s", qPrintable(profile), r.isError() ? "NON applicato" : "richiesto");
        readPowerProfiles();   // stato effettivo
        w->deleteLater();
    });
}

// --- luminosità (PowerDevil) ---
void SystemStatus::readBrightness() {
    const QString svc = QStringLiteral("org.kde.ScreenBrightness");
    auto names = QDBusConnection::sessionBus().call(getProp(svc, QStringLiteral("/org/kde/ScreenBrightness"), svc, QStringLiteral("DisplaysDBusNames")), QDBus::Block, 1500);
    m_brightnessPath.clear();
    if (names.type() == QDBusMessage::ReplyMessage) {
        const QStringList list = names.arguments().value(0).value<QDBusVariant>().variant().toStringList();
        if (!list.isEmpty()) {
            const QString path = QStringLiteral("/org/kde/ScreenBrightness/") + list.first();
            const QString iface = QStringLiteral("org.kde.ScreenBrightness.Display");
            auto b = QDBusConnection::sessionBus().call(getProp(svc, path, iface, QStringLiteral("Brightness")), QDBus::Block, 1500);
            auto mx = QDBusConnection::sessionBus().call(getProp(svc, path, iface, QStringLiteral("MaxBrightness")), QDBus::Block, 1500);
            if (b.type() == QDBusMessage::ReplyMessage && mx.type() == QDBusMessage::ReplyMessage) {
                m_brightnessPath = path;
                m_brightness = b.arguments().value(0).value<QDBusVariant>().variant().toInt();
                m_maxBrightness = mx.arguments().value(0).value<QDBusVariant>().variant().toInt();
            }
        }
        m_brightnessNote = m_brightnessPath.isEmpty() ? tr("Luminosità non regolabile su questo schermo (monitor virtuale o esterno senza controllo)") : QString();
    } else {
        m_brightnessNote = tr("Servizio della luminosità non disponibile");
    }
    emit brightnessChanged();
}

void SystemStatus::setBrightness(int value) {
    if (m_brightnessPath.isEmpty()) return;
    auto m = QDBusMessage::createMethodCall(QStringLiteral("org.kde.ScreenBrightness"), m_brightnessPath,
                                            QStringLiteral("org.kde.ScreenBrightness.Display"), QStringLiteral("SetBrightness"));
    m << qBound(0, value, m_maxBrightness) << uint(0);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w]() {
        QDBusPendingReply<> r = *w;
        if (r.isError()) emit failed(tr("luminosità"), r.error().message());
        readBrightness();
        w->deleteLater();
    });
}

// --- batteria (UPower) ---
void SystemStatus::readBattery() {
    const QString svc = QStringLiteral("org.freedesktop.UPower"), path = QStringLiteral("/org/freedesktop/UPower/devices/DisplayDevice"),
                  iface = QStringLiteral("org.freedesktop.UPower.Device");
    auto present = QDBusConnection::systemBus().call(getProp(svc, path, iface, QStringLiteral("IsPresent")), QDBus::Block, 1500);
    m_batteryPresent = present.type() == QDBusMessage::ReplyMessage && present.arguments().value(0).value<QDBusVariant>().variant().toBool();
    if (m_batteryPresent) {
        auto pct = QDBusConnection::systemBus().call(getProp(svc, path, iface, QStringLiteral("Percentage")), QDBus::Block, 1500);
        auto st = QDBusConnection::systemBus().call(getProp(svc, path, iface, QStringLiteral("State")), QDBus::Block, 1500);
        m_batteryPercent = qRound(pct.arguments().value(0).value<QDBusVariant>().variant().toDouble());
        const uint state = st.arguments().value(0).value<QDBusVariant>().variant().toUInt();
        m_batteryCharging = state == 1 || state == 4;   // in carica / carica completa
    }
    emit batteryChanged();
}

// --- archiviazione ---
void SystemStatus::readStorage() {
    QStorageInfo home(QDir::homePath());
    m_storage = {{"path", home.rootPath()}, {"totalGb", double(home.bytesTotal()) / 1e9}, {"freeGb", double(home.bytesAvailable()) / 1e9},
                 {"usedPercent", home.bytesTotal() > 0 ? qRound(100.0 * double(home.bytesTotal() - home.bytesAvailable()) / double(home.bytesTotal())) : 0},
                 {"valid", home.isValid() && home.bytesTotal() > 0}};
    emit storageChanged();
}

// --- sicurezza (sola lettura) ---
void SystemStatus::readSecurity() {
    QFile se(QStringLiteral("/sys/fs/selinux/enforce"));
    QString selinux = tr("non attivo");
    if (se.open(QIODevice::ReadOnly)) selinux = se.readAll().trimmed() == "1" ? tr("attivo (enforcing)") : tr("permissivo");
    QString sb = tr("non rilevabile");
    QFile efi(QStringLiteral("/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"));
    if (efi.open(QIODevice::ReadOnly)) { const QByteArray d = efi.readAll(); if (d.size() >= 5) sb = d.at(4) == 1 ? tr("attivo") : tr("disattivo"); }
    m_security = {{"selinux", selinux}, {"secureBoot", sb}, {"firewall", tr("verifica in corso")}};
    emit securityChanged();
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p](int, QProcess::ExitStatus) {
        const QString s = QString::fromLatin1(p->readAllStandardOutput()).trimmed();
        m_security[QStringLiteral("firewall")] = s == QLatin1String("active") ? tr("attivo (firewalld)") : tr("non attivo (%1)").arg(s);
        emit securityChanged();
        p->deleteLater();
    });
    connect(p, &QProcess::errorOccurred, p, &QObject::deleteLater);
    p->start(QStringLiteral("systemctl"), {QStringLiteral("is-active"), QStringLiteral("firewalld")});
}

bool SystemStatus::openSettings(const QString &module) {
    const bool ok = module.isEmpty() ? QProcess::startDetached(QStringLiteral("systemsettings"), {})
                                     : QProcess::startDetached(QStringLiteral("systemsettings"), {module});
    qInfo("impostazioni: apro %s: %s", qPrintable(module.isEmpty() ? QStringLiteral("Impostazioni di sistema") : module), ok ? "ok" : "NON riuscito");
    if (!ok) emit failed(tr("impostazioni"), tr("Impostazioni di sistema non avviabili"));
    return ok;
}

// --- rete (NetworkManager, sola lettura; le azioni passano da plasma-nm) ---
void SystemStatus::refreshNetwork() {
    const QString svc = QStringLiteral("org.freedesktop.NetworkManager"), path = QStringLiteral("/org/freedesktop/NetworkManager");
    auto bus = QDBusConnection::systemBus();
    if (!m_nmWatching) {
        m_nmWatching = bus.connect(svc, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"),
                                   this, SLOT(onNmPropertiesChanged(QString,QVariantMap,QStringList)));
    }
    auto state = bus.call(getProp(svc, path, svc, QStringLiteral("State")), QDBus::Block, 1500);
    m_netAvailable = state.type() == QDBusMessage::ReplyMessage;
    const uint st = m_netAvailable ? state.arguments().value(0).value<QDBusVariant>().variant().toUInt() : 0;
    m_netConnected = st >= 60;   // NM_STATE_CONNECTED_SITE (60) o GLOBAL (70)
    m_netType.clear();
    m_netName.clear();
    auto prim = bus.call(getProp(svc, path, svc, QStringLiteral("PrimaryConnection")), QDBus::Block, 1500);
    const QString ac = prim.type() == QDBusMessage::ReplyMessage ? prim.arguments().value(0).value<QDBusVariant>().variant().value<QDBusObjectPath>().path() : QString();
    if (!ac.isEmpty() && ac != QLatin1String("/")) {
        const QString aiface = QStringLiteral("org.freedesktop.NetworkManager.Connection.Active");
        auto id = bus.call(getProp(svc, ac, aiface, QStringLiteral("Id")), QDBus::Block, 1500);
        auto type = bus.call(getProp(svc, ac, aiface, QStringLiteral("Type")), QDBus::Block, 1500);
        m_netName = id.arguments().value(0).value<QDBusVariant>().variant().toString();
        const QString t = type.arguments().value(0).value<QDBusVariant>().variant().toString();
        m_netType = t.contains(QLatin1String("wireless")) ? QStringLiteral("wifi") : t.contains(QLatin1String("ethernet")) ? QStringLiteral("ethernet") : t;
    }
    emit networkChanged();
}

void SystemStatus::onNmPropertiesChanged(const QString &, const QVariantMap &changed, const QStringList &) {
    if (changed.contains(QStringLiteral("State")) || changed.contains(QStringLiteral("PrimaryConnection")))
        QTimer::singleShot(200, this, &SystemStatus::refreshNetwork);
}
