#include "notificationserver.h"
#include <QDBusConnection>
#include <QDBusConnectionInterface>

NotificationServer::NotificationServer(QObject *parent) : QAbstractListModel(parent) {
    m_status = tr("Servizio delle notifiche non ancora registrato");
}

bool NotificationServer::registerOnBus() {
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        m_status = tr("Bus di sessione non disponibile");
        emit availableChanged();
        return false;
    }
    new NotificationsAdaptor(this);
    if (!bus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), this)) {
        m_status = tr("Oggetto D-Bus delle notifiche non registrabile");
        emit availableChanged();
        return false;
    }
    if (!bus.registerService(QStringLiteral("org.freedesktop.Notifications"))) {
        const QString owner = bus.interface()->serviceOwner(QStringLiteral("org.freedesktop.Notifications")).value();
        const uint pid = bus.interface()->servicePid(owner).value();
        m_status = tr("Le notifiche sono gestite da un altro programma (pid %1)").arg(pid);
        qWarning("notifiche: servizio org.freedesktop.Notifications già in uso (pid %u)", pid);
        emit availableChanged();
        return false;
    }
    m_available = true;
    m_status = tr("Notifiche delle applicazioni attive");
    qInfo("notifiche: server org.freedesktop.Notifications registrato");
    emit availableChanged();
    return true;
}

int NotificationServer::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : count(); }

QVariant NotificationServer::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= count()) return {};
    const auto &n = m_items.at(index.row());
    switch (role) {
    case IdRole: return n.id;
    case AppNameRole: return n.appName;
    case AppIconRole: return n.appIcon;
    case SummaryRole: return n.summary;
    case BodyRole: return n.body;
    case ActionsRole: {
        QVariantList out;
        for (int i = 0; i + 1 < n.actions.size(); i += 2) {
            if (n.actions.at(i) == QLatin1String("default")) continue;
            out.append(QVariantMap{{"key", n.actions.at(i)}, {"label", n.actions.at(i + 1)}});
        }
        return out;
    }
    case UrgencyRole: return n.urgency;
    case DesktopEntryRole: return n.desktopEntry;
    case CreatedRole: return n.created;
    case PopupRole: return n.popup;
    case ExpiredRole: return n.expired;
    case ReadRole: return n.read;
    case TimeoutRole: return n.timeout;
    }
    return {};
}

QHash<int, QByteArray> NotificationServer::roleNames() const {
    return {{IdRole, "notificationId"}, {AppNameRole, "appName"}, {AppIconRole, "appIcon"}, {SummaryRole, "summary"},
            {BodyRole, "body"}, {ActionsRole, "actions"}, {UrgencyRole, "urgency"}, {DesktopEntryRole, "desktopEntry"},
            {CreatedRole, "created"}, {PopupRole, "popup"}, {ExpiredRole, "expired"}, {ReadRole, "read"}, {TimeoutRole, "timeout"}};
}

int NotificationServer::unreadCount() const {
    int c = 0;
    for (const auto &n : m_items) if (!n.read) ++c;
    return c;
}

void NotificationServer::setDoNotDisturb(bool on) {
    if (on == m_dnd) return;
    m_dnd = on;
    qInfo("notifiche: non disturbare %s", on ? "attivo" : "disattivo");
    emit doNotDisturbChanged();
}

int NotificationServer::indexOf(uint id) const {
    for (int i = 0; i < m_items.size(); ++i) if (m_items.at(i).id == id) return i;
    return -1;
}

uint NotificationServer::notify(const QString &appName, uint replacesId, const QString &appIcon, const QString &summary,
                                const QString &body, const QStringList &actions, const QVariantMap &hints, int expireTimeout) {
    OmniNotification n;
    n.appName = appName;
    n.appIcon = appIcon.isEmpty() ? hints.value(QStringLiteral("desktop-entry")).toString() : appIcon;
    n.summary = summary;
    n.body = body;
    n.actions = actions;
    n.desktopEntry = hints.value(QStringLiteral("desktop-entry")).toString();
    n.urgency = hints.contains(QStringLiteral("urgency")) ? qBound(0, hints.value(QStringLiteral("urgency")).toInt(), 2) : 1;
    n.resident = hints.value(QStringLiteral("resident")).toBool();
    n.transient = hints.value(QStringLiteral("transient")).toBool();
    n.timeout = expireTimeout;
    n.created = QDateTime::currentDateTime();
    // "Non disturbare": nessun fumetto, ma la notifica resta in cronologia (le critiche passano).
    n.popup = !m_dnd || n.urgency == 2;

    const int existing = replacesId ? indexOf(replacesId) : -1;
    if (existing >= 0) {
        n.id = replacesId;
        m_items[existing] = n;
        emit dataChanged(index(existing), index(existing));
    } else {
        n.id = m_nextId++;
        if (m_nextId == 0) m_nextId = 1;
        beginInsertRows({}, 0, 0);
        m_items.prepend(n);
        endInsertRows();
        emit countChanged();
    }
    qInfo("notifiche: ricevuta #%u da \"%s\": %s%s", n.id, qPrintable(appName), qPrintable(summary), n.popup ? "" : " (non disturbare: senza fumetto)");
    if (n.popup) emit popupRequested(n.id);
    return n.id;
}

uint NotificationServer::postLocal(const QString &summary, const QString &body, int urgency) {
    return notify(QStringLiteral("OMNI Shell"), 0, QStringLiteral("preferences-system"), summary, body, {},
                  {{QStringLiteral("urgency"), urgency}}, -1);
}

void NotificationServer::removeAt(int row, uint reason) {
    const uint id = m_items.at(row).id;
    beginRemoveRows({}, row, row);
    m_items.removeAt(row);
    endRemoveRows();
    emit countChanged();
    emit notificationClosed(id, reason);
}

void NotificationServer::closeNotification(uint id) {
    const int row = indexOf(id);
    if (row >= 0) removeAt(row, 3);   // revocata dall'applicazione
}

void NotificationServer::dismiss(uint id) {
    const int row = indexOf(id);
    if (row >= 0) removeAt(row, 2);   // chiusa dall'utente
}

void NotificationServer::invokeAction(uint id, const QString &key) {
    const int row = indexOf(id);
    if (row < 0 || m_items.at(row).expired) return;
    emit actionInvoked(id, key);
    qInfo("notifiche: azione \"%s\" sulla notifica #%u", qPrintable(key), id);
    if (!m_items.at(row).resident) removeAt(row, 2);
}

void NotificationServer::popupTimedOut(uint id) {
    const int row = indexOf(id);
    if (row < 0) return;
    auto &n = m_items[row];
    if (n.transient) { removeAt(row, 1); return; }
    n.popup = false;
    n.expired = true;                 // in cronologia, ma le azioni non sono più invocabili
    emit dataChanged(index(row), index(row));
    emit notificationClosed(id, 1);
}

void NotificationServer::hidePopup(uint id) {
    const int row = indexOf(id);
    if (row < 0) return;
    m_items[row].popup = false;
    emit dataChanged(index(row), index(row));
}

void NotificationServer::clearAll() {
    while (!m_items.isEmpty()) removeAt(0, 2);
}

void NotificationServer::markAllRead() {
    for (int i = 0; i < m_items.size(); ++i) m_items[i].read = true;
    if (!m_items.isEmpty()) emit dataChanged(index(0), index(count() - 1));
    emit countChanged();
}

// --- adattatore D-Bus ---
NotificationsAdaptor::NotificationsAdaptor(NotificationServer *server) : QDBusAbstractAdaptor(server), m_server(server) {
    connect(server, &NotificationServer::notificationClosed, this, &NotificationsAdaptor::NotificationClosed);
    connect(server, &NotificationServer::actionInvoked, this, &NotificationsAdaptor::ActionInvoked);
}

QStringList NotificationsAdaptor::GetCapabilities() {
    return {QStringLiteral("body"), QStringLiteral("actions"), QStringLiteral("persistence"), QStringLiteral("icon-static")};
}

uint NotificationsAdaptor::Notify(const QString &app_name, uint replaces_id, const QString &app_icon, const QString &summary,
                                  const QString &body, const QStringList &actions, const QVariantMap &hints, int expire_timeout) {
    return m_server->notify(app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout);
}

void NotificationsAdaptor::CloseNotification(uint id) { m_server->closeNotification(id); }

QString NotificationsAdaptor::GetServerInformation(QString &vendor, QString &version, QString &spec_version) {
    vendor = QStringLiteral("OMNI OS");
    version = QStringLiteral("0.3");
    spec_version = QStringLiteral("1.2");
    return QStringLiteral("OMNI Shell");
}
