#pragma once
#include <QAbstractListModel>
#include <QDateTime>
#include <QDBusAbstractAdaptor>
#include <QStringList>
#include <QVariantMap>
#include <QVector>

// Server REALE delle notifiche del desktop (specifica freedesktop "Desktop Notifications",
// servizio D-Bus org.freedesktop.Notifications). Nella sessione OMNI il pannello di Plasma
// non è attivo, quindi OMNI Shell riceve le notifiche di tutte le applicazioni:
// cronologia, eliminazione, "Non disturbare" (le notifiche critiche passano comunque).
// Nessuna notifica dimostrativa: il modello contiene solo ciò che arriva dalle applicazioni.
struct OmniNotification {
    uint id = 0;
    QString appName, appIcon, summary, body, desktopEntry;
    QStringList actions;          // coppie chiave, etichetta (come da specifica)
    int urgency = 1;              // 0 bassa, 1 normale, 2 critica
    int timeout = -1;             // ms; -1 = predefinito del server, 0 = non scade
    bool resident = false, transient = false;
    bool popup = false, expired = false, read = false;
    QDateTime created;
};

class NotificationServer : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QString status READ status NOTIFY availableChanged)
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb NOTIFY doNotDisturbChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY countChanged)
public:
    enum Roles { IdRole = Qt::UserRole + 1, AppNameRole, AppIconRole, SummaryRole, BodyRole, ActionsRole,
                 UrgencyRole, DesktopEntryRole, CreatedRole, PopupRole, ExpiredRole, ReadRole, TimeoutRole };
    explicit NotificationServer(QObject *parent = nullptr);

    // Registra il servizio sul bus di sessione. false se un altro programma lo possiede già.
    bool registerOnBus();

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool available() const { return m_available; }
    QString status() const { return m_status; }
    bool doNotDisturb() const { return m_dnd; }
    void setDoNotDisturb(bool on);
    int count() const { return int(m_items.size()); }
    int unreadCount() const;

    Q_INVOKABLE void dismiss(uint id);                         // l'utente elimina la notifica
    Q_INVOKABLE void invokeAction(uint id, const QString &key);
    Q_INVOKABLE void popupTimedOut(uint id);                   // il fumetto scade: resta in cronologia
    Q_INVOKABLE void hidePopup(uint id);
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE void markAllRead();
    Q_INVOKABLE int defaultTimeout() const { return 6000; }
    // messaggio di OMNI Shell stessa (es. un'azione di sistema non riuscita)
    Q_INVOKABLE uint postLocal(const QString &summary, const QString &body, int urgency = 1);

    // Interfaccia D-Bus (chiamata dall'adattatore)
    uint notify(const QString &appName, uint replacesId, const QString &appIcon, const QString &summary,
                const QString &body, const QStringList &actions, const QVariantMap &hints, int expireTimeout);
    void closeNotification(uint id);

signals:
    void availableChanged();
    void doNotDisturbChanged();
    void countChanged();
    void popupRequested(uint id);
    // segnali D-Bus (inoltrati dall'adattatore)
    void notificationClosed(uint id, uint reason);
    void actionInvoked(uint id, const QString &actionKey);

private:
    int indexOf(uint id) const;
    void removeAt(int row, uint reason);
    QVector<OmniNotification> m_items;   // più recente in testa
    uint m_nextId = 1;
    bool m_available = false, m_dnd = false;
    QString m_status;
};

class NotificationsAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
public:
    explicit NotificationsAdaptor(NotificationServer *server);
public slots:
    QStringList GetCapabilities();
    uint Notify(const QString &app_name, uint replaces_id, const QString &app_icon, const QString &summary,
                const QString &body, const QStringList &actions, const QVariantMap &hints, int expire_timeout);
    void CloseNotification(uint id);
    QString GetServerInformation(QString &vendor, QString &version, QString &spec_version);
signals:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &action_key);
private:
    NotificationServer *m_server;
};
