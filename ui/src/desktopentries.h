#pragma once
#include <QAbstractListModel>
#include <QStringList>
#include <QVector>

// Modello delle applicazioni installate, letto IN SOLA LETTURA dai file .desktop
// (specifica freedesktop Desktop Entry) nelle cartelle XDG "applications".
// Non avvia nulla e non scrive nulla.
struct DesktopEntry {
    QString id;
    QString name;
    QString comment;
    QString icon;
    QStringList categories;
    QString path;          // percorso del file .desktop (vuoto per l'elenco dimostrativo)
    QStringList mimeTypes;
    QString flatpakId;     // X-Flatpak: app installata con Flatpak (disinstallabile dallo Store)
};

class DesktopEntryModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool demo READ demo NOTIFY countChanged)
public:
    enum Roles { NameRole = Qt::UserRole + 1, CommentRole, IconRole, CategoriesRole, IdRole, PathRole, MimeRole, FlatpakRole };
    explicit DesktopEntryModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return int(m_entries.size()); }
    bool demo() const { return m_demo; }
    Q_INVOKABLE QVariantMap get(int row) const;
    // true se il percorso è quello di una voce letta dal modello (usato da AppLauncher)
    bool containsPath(const QString &path) const;

    // Carica dalle cartelle indicate (vuoto = cartelle XDG standard). Ritorna il numero di voci.
    int load(const QStringList &dirs = {}, const QString &locale = {});
    // Elenco dimostrativo, usato solo se non si trovano applicazioni (segnalato da demo=true).
    void loadDemo();

    // Analisi di un singolo file .desktop (pubblica per i test).
    static bool parseFile(const QString &path, const QString &locale, DesktopEntry *out);

signals:
    void countChanged();

private:
    QVector<DesktopEntry> m_entries;
    bool m_demo = false;
};
