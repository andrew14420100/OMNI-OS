#pragma once
#include <QAbstractListModel>
#include <QAtomicInt>
#include <QHash>
#include <QSet>
#include <QStringList>
#include <QVariantMap>

// Catalogo REALE di OMNI Store: metadati AppStream che Flatpak scarica da ciascuna sorgente
// (es. Flathub) in ~/.local/share/flatpak/appstream o /var/lib/flatpak/appstream. Nessun
// elenco inventato: se il catalogo non è ancora stato scaricato, il modello resta vuoto e
// l'interfaccia lo dice. La lettura avviene in un thread separato.
struct StoreApp {
    QString id, name, summary, description, icon, developer, license, homepage, screenshot, version, ref, remote;
    QStringList categories, keywords;
    qint64 released = 0;
};

class AppStreamCatalog : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ count NOTIFY viewChanged)
    Q_PROPERTY(int total READ total NOTIFY loadingChanged)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY viewChanged)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY viewChanged)
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY viewChanged)
    Q_PROPERTY(QStringList sources READ sources NOTIFY loadingChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY loadingChanged)
    Q_PROPERTY(QStringList roots READ roots WRITE setRoots NOTIFY loadingChanged)
public:
    enum Roles { IdRole = Qt::UserRole + 1, NameRole, SummaryRole, IconRole, CategoriesRole, DeveloperRole, VersionRole, InstalledRole, UpdateRole, RemoteRole };
    explicit AppStreamCatalog(QObject *parent = nullptr);
    ~AppStreamCatalog() override;
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }
    int count() const { return m_view.size(); }
    int total() const { return m_apps.size(); }
    QString search() const { return m_search; }
    void setSearch(const QString &s);
    QString category() const { return m_category; }
    void setCategory(const QString &c);
    QString sortKey() const { return m_sort; }
    void setSortKey(const QString &k);
    QStringList sources() const { return m_sources; }
    QString lastError() const { return m_error; }

    // ricarica dai file AppStream presenti (dopo "flatpak update --appstream")
    Q_INVOKABLE void reload();
    Q_INVOKABLE QVariantMap get(const QString &appId) const;
    Q_INVOKABLE QVariantMap at(int row) const;
    // app installate e aggiornamenti: righe "id\tnome\tversione\torigine\tinstallazione" di flatpak list
    Q_INVOKABLE void setInstalled(const QString &flatpakListOutput);
    Q_INVOKABLE void setUpdates(const QString &remoteLsUpdatesOutput);
    Q_INVOKABLE QVariantList installed() const;
    Q_INVOKABLE QVariantList updates() const;
    Q_INVOKABLE QStringList categoryIds() const;
    Q_INVOKABLE QString categoryName(const QString &id) const;
    // cartelle di ricerca (sovrascrivibili nei test)
    void setRoots(const QStringList &roots) { m_roots = roots; }
    QStringList roots() const { return m_roots; }
    static QVector<StoreApp> parse(const QByteArray &xml, const QString &remote, const QString &iconDir, const QString &lang);

signals:
    void loadingChanged();
    void viewChanged();
    void installedChanged();

private:
    void applyView();
    QStringList m_roots;
    QVector<StoreApp> m_apps;
    QHash<QString, int> m_index;
    QVector<int> m_view;
    QHash<QString, QVariantMap> m_installed;
    QHash<QString, QString> m_updates;
    QString m_search, m_category, m_sort = QStringLiteral("name"), m_error;
    QStringList m_sources;
    bool m_loading = false;
    QAtomicInt m_gen;
};
