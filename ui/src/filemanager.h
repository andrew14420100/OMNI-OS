#pragma once
#include <QAbstractListModel>
#include <QAtomicInt>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QHash>
#include <QPointer>
#include <QTimer>
#include <QVariantList>

// Backend di OMNI Explorer.
//  - FolderModel: contenuto REALE di una cartella (QDir + tipi MIME), aggiornato da solo quando
//    la cartella cambia; ordinamento, file nascosti, filtro e ricerca ricorsiva asincrona.
//  - FileOps: operazioni sui file con avanzamento e annullamento. Nel sistema OMNI usa KIO
//    (le stesse operazioni di Dolphin: copia, spostamento, cestino, eliminazione, rinomina),
//    ZIP con KArchive; senza KDE (prove locali) usa Qt. Nessuna operazione è dichiarata
//    riuscita prima della risposta del sistema; le eliminazioni definitive richiedono
//    conferma nell'interfaccia. Cestino secondo la specifica freedesktop ($XDG_DATA_HOME/Trash).
struct FileEntry {
    QString name, path, mime, icon, generic, mimeComment, target;
    bool dir = false, hidden = false, link = false, readable = true, writable = false;
    qint64 size = 0;
    QDateTime modified;
};

class FolderModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY optionsChanged)
    Q_PROPERTY(bool descending READ descending WRITE setDescending NOTIFY optionsChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY optionsChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY optionsChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY searchChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString error READ error NOTIFY pathChanged)
    Q_PROPERTY(qint64 totalSize READ totalSize NOTIFY countChanged)
public:
    enum Roles { NameRole = Qt::UserRole + 1, PathRole, IsDirRole, SizeRole, ModifiedRole, MimeRole, IconRole, TypeRole, HiddenRole, LinkRole, WritableRole };
    explicit FolderModel(QObject *parent = nullptr);
    ~FolderModel() override;
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString path() const { return m_path; }
    void setPath(const QString &p);
    QString sortKey() const { return m_sort; }
    void setSortKey(const QString &k);
    bool descending() const { return m_desc; }
    void setDescending(bool d);
    bool showHidden() const { return m_hidden; }
    void setShowHidden(bool h);
    QString filter() const { return m_filter; }
    void setFilter(const QString &f);
    QString searchText() const { return m_search; }
    void setSearchText(const QString &s);
    bool searching() const { return m_searching; }
    int count() const { return m_view.size(); }
    QString error() const { return m_error; }
    qint64 totalSize() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int indexOfPath(const QString &path) const;
    Q_INVOKABLE QString parentPath() const;

signals:
    void pathChanged();
    void optionsChanged();
    void countChanged();
    void searchChanged();

private:
    void reload();
    void applyView();
    void startSearch();
    QString m_path, m_sort = QStringLiteral("name"), m_filter, m_search, m_error;
    bool m_desc = false, m_hidden = false, m_searching = false;
    QVector<FileEntry> m_all, m_view;
    QFileSystemWatcher m_watch;
    QTimer m_debounce;
    QAtomicInt m_searchGen;
};

class FileOps : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool kio READ kio CONSTANT)
    Q_PROPERTY(bool zip READ zip CONSTANT)
    Q_PROPERTY(QVariantList jobs READ jobs NOTIFY jobsChanged)
    Q_PROPERTY(bool hasClipboard READ hasClipboard NOTIFY clipboardChanged)
public:
    explicit FileOps(QObject *parent = nullptr);
    bool kio() const;
    bool zip() const;
    QVariantList jobs() const;

    // operazioni asincrone: restituiscono l'identificativo del lavoro; esito con finished()
    Q_INVOKABLE int copy(const QStringList &sources, const QString &destDir);
    Q_INVOKABLE int move(const QStringList &sources, const QString &destDir);
    Q_INVOKABLE int trash(const QStringList &paths);
    Q_INVOKABLE int remove(const QStringList &paths);           // definitiva: l'interfaccia chiede conferma
    Q_INVOKABLE int compress(const QStringList &paths, const QString &zipPath);
    Q_INVOKABLE int extract(const QString &zipPath, const QString &destDir);
    Q_INVOKABLE void cancel(int id);
    // operazioni immediate: stringa vuota se riuscite, altrimenti il messaggio d'errore
    Q_INVOKABLE QString mkdir(const QString &parentDir, const QString &name);
    Q_INVOKABLE QString rename(const QString &path, const QString &newName);
    Q_INVOKABLE QString setPermissions(const QString &path, int unixMode);
    Q_INVOKABLE QString uniqueName(const QString &dir, const QString &name) const;
    Q_INVOKABLE bool open(const QString &path);                 // applicazione predefinita (xdg-open)
    Q_INVOKABLE QVariantMap properties(const QString &path) const;
    Q_INVOKABLE int folderSize(const QString &path);             // asincrono: sizeReady(id, bytes, files)
    Q_INVOKABLE QVariantList volumes() const;
    Q_INVOKABLE QVariantList places() const;                   // cartelle personali esistenti
    Q_INVOKABLE QString readText(const QString &path, int maxBytes = 8192) const;
    // appunti di sistema (text/uri-list, compatibili con Dolphin e le altre app)
    Q_INVOKABLE void setClipboard(const QStringList &paths, bool cut);
    Q_INVOKABLE QVariantMap clipboard() const;                   // { paths, cut }
    bool hasClipboard() const;
    // cestino (specifica freedesktop, cestino della cartella personale)
    Q_INVOKABLE QVariantList trashItems() const;
    Q_INVOKABLE QString restore(const QStringList &trashNames);
    Q_INVOKABLE QString removeFromTrash(const QStringList &trashNames);
    Q_INVOKABLE QString trashDir() const;

signals:
    void progress(int id, double fraction, const QString &text);
    void finished(int id, bool ok, const QString &error);
    void sizeReady(int id, qint64 bytes, int files);
    void jobsChanged();
    void clipboardChanged();

private:
    int startJob(const QString &kind, const QStringList &sources, const QString &dest);
    void runQt(int id, const QString &kind, const QStringList &sources, const QString &dest);
    void done(int id, bool ok, const QString &error);
    struct Job { QString kind, label; double fraction = 0; QPointer<QObject> handle; QAtomicInt *stop = nullptr; };
    QHash<int, Job> m_jobs;
    int m_next = 1;
};
