#include "filemanager.h"
#include <QClipboard>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QMimeData>
#include <QMimeDatabase>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QThread>
#include <QUrl>
#include <grp.h>
#include <pwd.h>
#include <sys/stat.h>
#include <unistd.h>
#include <algorithm>
#include <functional>
#ifdef OMNI_HAVE_KIO
#include <KIO/CopyJob>
#include <KIO/DeleteJob>
#include <KJob>
#endif
#ifdef OMNI_HAVE_KARCHIVE
#include <KZip>
#endif

namespace {
QMimeDatabase &mimeDb() { static QMimeDatabase db; return db; }

FileEntry entryFor(const QFileInfo &fi) {
    FileEntry e;
    e.name = fi.fileName();
    e.path = fi.absoluteFilePath();
    e.dir = fi.isDir();
    e.hidden = e.name.startsWith(QLatin1Char('.'));
    e.link = fi.isSymLink();
    if (e.link) e.target = fi.symLinkTarget();
    e.readable = fi.isReadable();
    e.writable = fi.isWritable();
    e.size = e.dir ? 0 : fi.size();
    e.modified = fi.lastModified();
    if (e.dir) {
        e.mime = QStringLiteral("inode/directory");
        e.icon = QStringLiteral("folder");
        static const QHash<QString, QString> special = {
            {QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation), QStringLiteral("folder-documents")},
            {QStandardPaths::writableLocation(QStandardPaths::DownloadLocation), QStringLiteral("folder-download")},
            {QStandardPaths::writableLocation(QStandardPaths::PicturesLocation), QStringLiteral("folder-pictures")},
            {QStandardPaths::writableLocation(QStandardPaths::MusicLocation), QStringLiteral("folder-music")},
            {QStandardPaths::writableLocation(QStandardPaths::MoviesLocation), QStringLiteral("folder-videos")},
            {QStandardPaths::writableLocation(QStandardPaths::DesktopLocation), QStringLiteral("user-desktop")}};
        e.icon = special.value(e.path, e.icon);
        e.mimeComment = QObject::tr("Cartella");
    } else {
        const QMimeType m = mimeDb().mimeTypeForFile(fi, QMimeDatabase::MatchExtension);
        e.mime = m.name();
        e.icon = m.iconName().isEmpty() ? m.genericIconName() : m.iconName();
        e.generic = m.genericIconName();
        e.mimeComment = m.comment();
    }
    return e;
}

QString humanError(const QString &op, const QString &path) {
    return QObject::tr("%1 non riuscito: %2").arg(op, path);
}

// copia ricorsiva (fallback senza KIO) con avanzamento per byte e annullamento
bool copyRecursive(const QString &src, const QString &dst, qint64 &done, qint64 total, QAtomicInt *stop,
                   const std::function<void(double)> &report, QString *err) {
    QFileInfo fi(src);
    if (fi.isDir() && !fi.isSymLink()) {
        if (!QDir().mkpath(dst)) { *err = humanError(QObject::tr("Creazione della cartella"), dst); return false; }
        const auto entries = QDir(src).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
        for (const QFileInfo &c : entries)
            if (!copyRecursive(c.absoluteFilePath(), dst + QLatin1Char('/') + c.fileName(), done, total, stop, report, err)) return false;
        return true;
    }
    QFile in(src), out(dst);
    if (!in.open(QIODevice::ReadOnly)) { *err = humanError(QObject::tr("Lettura"), src); return false; }
    if (!out.open(QIODevice::WriteOnly | QIODevice::NewOnly)) { *err = humanError(QObject::tr("Scrittura"), dst); return false; }
    QByteArray buf;
    while (!(buf = in.read(1 << 20)).isEmpty()) {
        if (stop && stop->loadRelaxed()) { out.remove(); *err = QObject::tr("Annullato"); return false; }
        if (out.write(buf) != buf.size()) { out.remove(); *err = humanError(QObject::tr("Scrittura"), dst); return false; }
        done += buf.size();
        report(total > 0 ? double(done) / double(total) : 0);
    }
    out.setPermissions(in.permissions());
    return true;
}

qint64 treeSize(const QString &path, int *files = nullptr, QAtomicInt *stop = nullptr) {
    QFileInfo fi(path);
    if (!fi.isDir() || fi.isSymLink()) { if (files) ++*files; return fi.size(); }
    qint64 s = 0;
    QDirIterator it(path, QDir::Files | QDir::Hidden | QDir::System | QDir::NoSymLinks, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        if (stop && stop->loadRelaxed()) break;
        it.next();
        s += it.fileInfo().size();
        if (files) ++*files;
    }
    return s;
}

// confronto "naturale" (file2 prima di file10) indipendente da ICU e dalla lingua del sistema
int naturalCompare(const QString &a, const QString &b) {
    int i = 0, j = 0;
    while (i < a.size() && j < b.size()) {
        if (a.at(i).isDigit() && b.at(j).isDigit()) {
            int si = i, sj = j;
            while (si < a.size() && a.at(si) == QLatin1Char('0')) ++si;
            while (sj < b.size() && b.at(sj) == QLatin1Char('0')) ++sj;
            int ei = si, ej = sj;
            while (ei < a.size() && a.at(ei).isDigit()) ++ei;
            while (ej < b.size() && b.at(ej).isDigit()) ++ej;
            if (ei - si != ej - sj) return (ei - si) < (ej - sj) ? -1 : 1;
            const int c = QStringView(a).mid(si, ei - si).compare(QStringView(b).mid(sj, ej - sj));
            if (c) return c;
            i = ei; j = ej;
            continue;
        }
        const int c = QString::localeAwareCompare(a.at(i).toLower(), b.at(j).toLower());
        if (c) return c;
        ++i; ++j;
    }
    return (a.size() - i) - (b.size() - j);
}

QString trashRoot() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/Trash");
}
}  // namespace

// ---------------------------------------------------------------------------------- FolderModel
FolderModel::FolderModel(QObject *parent) : QAbstractListModel(parent) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(250);
    connect(&m_debounce, &QTimer::timeout, this, [this]() { if (m_search.isEmpty()) reload(); });
    connect(&m_watch, &QFileSystemWatcher::directoryChanged, this, [this]() { m_debounce.start(); });
}
FolderModel::~FolderModel() { m_searchGen.fetchAndAddRelaxed(1); }

int FolderModel::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_view.size(); }
QHash<int, QByteArray> FolderModel::roleNames() const {
    return {{NameRole, "name"}, {PathRole, "path"}, {IsDirRole, "isDir"}, {SizeRole, "size"}, {ModifiedRole, "modified"},
            {MimeRole, "mime"}, {IconRole, "iconName"}, {TypeRole, "typeName"}, {HiddenRole, "hidden"}, {LinkRole, "isLink"},
            {WritableRole, "writable"}};
}
QVariant FolderModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_view.size()) return {};
    const FileEntry &e = m_view.at(index.row());
    switch (role) {
    case Qt::DisplayRole: case NameRole: return e.name;
    case PathRole: return e.path;
    case IsDirRole: return e.dir;
    case SizeRole: return double(e.size);
    case ModifiedRole: return e.modified;
    case MimeRole: return e.mime;
    case IconRole: return (e.generic.isEmpty() || QIcon::hasThemeIcon(e.icon)) ? e.icon : e.generic;
    case TypeRole: return e.mimeComment;
    case HiddenRole: return e.hidden;
    case LinkRole: return e.link;
    case WritableRole: return e.writable;
    }
    return {};
}
QVariantMap FolderModel::get(int row) const {
    if (row < 0 || row >= m_view.size()) return {};
    QVariantMap m;
    const auto names = roleNames();
    for (auto it = names.cbegin(); it != names.cend(); ++it) m.insert(QString::fromLatin1(it.value()), data(index(row), it.key()));
    return m;
}
int FolderModel::indexOfPath(const QString &p) const {
    for (int i = 0; i < m_view.size(); ++i) if (m_view.at(i).path == p) return i;
    return -1;
}
QString FolderModel::parentPath() const {
    QDir d(m_path);
    return d.cdUp() ? d.absolutePath() : QString();
}
qint64 FolderModel::totalSize() const {
    qint64 s = 0;
    for (const auto &e : m_view) s += e.size;
    return s;
}

void FolderModel::setPath(const QString &p) {
    const QString clean = QDir::cleanPath(p.startsWith(QLatin1Char('~')) ? QDir::homePath() + p.mid(1) : p);
    if (clean == m_path) return;
    m_path = clean;
    if (!m_watch.directories().isEmpty()) m_watch.removePaths(m_watch.directories());
    if (!m_search.isEmpty()) { m_search.clear(); m_searchGen.fetchAndAddRelaxed(1); m_searching = false; emit searchChanged(); }
    reload();
    if (QFileInfo(m_path).isDir()) m_watch.addPath(m_path);
}
void FolderModel::setSortKey(const QString &k) { if (k == m_sort) return; m_sort = k; applyView(); emit optionsChanged(); }
void FolderModel::setDescending(bool d) { if (d == m_desc) return; m_desc = d; applyView(); emit optionsChanged(); }
void FolderModel::setShowHidden(bool h) { if (h == m_hidden) return; m_hidden = h; applyView(); emit optionsChanged(); }
void FolderModel::setFilter(const QString &f) { if (f == m_filter) return; m_filter = f; applyView(); emit optionsChanged(); }
void FolderModel::setSearchText(const QString &s) {
    if (s == m_search) return;
    m_search = s;
    if (s.trimmed().isEmpty()) { m_searchGen.fetchAndAddRelaxed(1); m_searching = false; emit searchChanged(); reload(); return; }
    startSearch();
}
void FolderModel::refresh() { if (m_search.isEmpty()) reload(); else startSearch(); }

void FolderModel::reload() {
    QVector<FileEntry> all;
    const QFileInfo dirInfo(m_path);
    m_error.clear();
    if (!dirInfo.exists()) m_error = tr("La cartella non esiste");
    else if (!dirInfo.isDir()) m_error = tr("Non è una cartella");
    else if (!dirInfo.isReadable() || !dirInfo.isExecutable()) m_error = tr("Accesso negato: non hai i permessi per aprire questa cartella");
    else {
        const auto list = QDir(m_path).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
        all.reserve(list.size());
        for (const QFileInfo &fi : list) all << entryFor(fi);
    }
    m_all = all;
    applyView();
    emit pathChanged();
}

void FolderModel::startSearch() {
    const int gen = m_searchGen.fetchAndAddRelaxed(1) + 1;
    m_searching = true;
    emit searchChanged();
    const QString root = m_path, needle = m_search.trimmed();
    const bool hidden = m_hidden;
    QAtomicInt *genPtr = &m_searchGen;
    QPointer<FolderModel> self(this);
    QThread *t = QThread::create([root, needle, hidden, gen, genPtr, self]() {
        QVector<FileEntry> found;
        QDirIterator it(root, QDir::AllEntries | QDir::NoDotAndDotDot | (hidden ? QDir::Hidden : QDir::Filters()), QDirIterator::Subdirectories);
        while (it.hasNext() && found.size() < 5000) {
            if (genPtr->loadRelaxed() != gen) return;   // ricerca superata da una nuova o annullata
            it.next();
            if (it.fileName().contains(needle, Qt::CaseInsensitive)) found << entryFor(it.fileInfo());
        }
        QMetaObject::invokeMethod(qApp, [found, gen, self]() {
            if (!self || self->m_searchGen.loadRelaxed() != gen) return;
            self->m_all = found;
            self->m_searching = false;
            self->applyView();
            emit self->searchChanged();
        }, Qt::QueuedConnection);
    });
    connect(t, &QThread::finished, t, &QObject::deleteLater);
    t->start(QThread::LowPriority);
}

void FolderModel::applyView() {
    QVector<FileEntry> v;
    v.reserve(m_all.size());
    const QString f = m_filter.trimmed();
    for (const auto &e : m_all) {
        if (e.hidden && !m_hidden) continue;
        if (!f.isEmpty() && !e.name.contains(f, Qt::CaseInsensitive)) continue;
        v << e;
    }
    const QString key = m_sort;
    const bool desc = m_desc;
    std::stable_sort(v.begin(), v.end(), [&](const FileEntry &a, const FileEntry &b) {
        if (a.dir != b.dir) return a.dir;   // cartelle sempre prima, come in Esplora file
        int c = 0;
        if (key == QLatin1String("size")) c = a.size < b.size ? -1 : (a.size > b.size ? 1 : 0);
        else if (key == QLatin1String("date")) c = a.modified < b.modified ? -1 : (a.modified > b.modified ? 1 : 0);
        else if (key == QLatin1String("type")) c = naturalCompare(a.mimeComment, b.mimeComment);
        if (c == 0) c = naturalCompare(a.name, b.name);
        return desc ? c > 0 : c < 0;
    });
    beginResetModel();
    m_view = v;
    endResetModel();
    emit countChanged();
}

// --------------------------------------------------------------------------------------- FileOps
FileOps::FileOps(QObject *parent) : QObject(parent) {
    if (auto *cb = QGuiApplication::clipboard()) connect(cb, &QClipboard::dataChanged, this, &FileOps::clipboardChanged);
}
bool FileOps::kio() const {
#ifdef OMNI_HAVE_KIO
    return true;
#else
    return false;
#endif
}
bool FileOps::zip() const {
#ifdef OMNI_HAVE_KARCHIVE
    return true;
#else
    return false;
#endif
}
QVariantList FileOps::jobs() const {
    QVariantList out;
    for (auto it = m_jobs.cbegin(); it != m_jobs.cend(); ++it)
        out << QVariantMap{{"id", it.key()}, {"kind", it->kind}, {"label", it->label}, {"fraction", it->fraction}};
    return out;
}

int FileOps::copy(const QStringList &s, const QString &d) { return startJob(QStringLiteral("copy"), s, d); }
int FileOps::move(const QStringList &s, const QString &d) { return startJob(QStringLiteral("move"), s, d); }
int FileOps::trash(const QStringList &p) { return startJob(QStringLiteral("trash"), p, {}); }
int FileOps::remove(const QStringList &p) { return startJob(QStringLiteral("remove"), p, {}); }
int FileOps::compress(const QStringList &p, const QString &zipPath) { return startJob(QStringLiteral("compress"), p, zipPath); }
int FileOps::extract(const QString &zipPath, const QString &destDir) { return startJob(QStringLiteral("extract"), {zipPath}, destDir); }

int FileOps::startJob(const QString &kind, const QStringList &sources, const QString &dest) {
    const int id = m_next++;
    static const QHash<QString, QString> labels = {{"copy", tr("Copia")}, {"move", tr("Spostamento")}, {"trash", tr("Spostamento nel cestino")},
                                                   {"remove", tr("Eliminazione definitiva")}, {"compress", tr("Compressione ZIP")}, {"extract", tr("Estrazione")}};
    Job j;
    j.kind = kind;
    j.label = labels.value(kind) + QStringLiteral(": ") + (sources.size() == 1 ? QFileInfo(sources.first()).fileName() : tr("%n elementi", nullptr, int(sources.size())));
    m_jobs.insert(id, j);
    emit jobsChanged();
    if (sources.isEmpty()) { QMetaObject::invokeMethod(this, [this, id]() { done(id, false, tr("Nessun elemento selezionato")); }, Qt::QueuedConnection); return id; }
#ifdef OMNI_HAVE_KIO
    if (kind == QLatin1String("copy") || kind == QLatin1String("move") || kind == QLatin1String("trash") || kind == QLatin1String("remove")) {
        QList<QUrl> urls;
        for (const QString &s : sources) urls << QUrl::fromLocalFile(s);
        KJob *job = nullptr;
        if (kind == QLatin1String("copy") || kind == QLatin1String("move")) {
            KIO::CopyJob *cj = kind == QLatin1String("copy") ? KIO::copy(urls, QUrl::fromLocalFile(dest), KIO::HideProgressInfo)
                                                             : KIO::move(urls, QUrl::fromLocalFile(dest), KIO::HideProgressInfo);
            cj->setAutoRename(true);   // nessuna sovrascrittura: "nome (1)" come in Esplora file
            job = cj;
        } else if (kind == QLatin1String("trash")) {
            job = KIO::trash(urls, KIO::HideProgressInfo);
        } else {
            job = KIO::del(urls, KIO::HideProgressInfo);
        }
        m_jobs[id].handle = job;
        connect(job, &KJob::percentChanged, this, [this, id](KJob *, unsigned long pct) {
            if (!m_jobs.contains(id)) return;
            m_jobs[id].fraction = pct / 100.0;
            emit progress(id, pct / 100.0, m_jobs[id].label);
            emit jobsChanged();
        });
        connect(job, &KJob::result, this, [this, id](KJob *j) {
            // esito sempre asincrono: KIO lo emette in modo sincrono dentro kill(), cioè prima
            // che chi ha chiesto l'annullamento possa riceverlo
            const bool ok = j->error() == 0;
            const QString err = j->error() == KJob::KilledJobError ? tr("Annullato") : j->errorString();
            QMetaObject::invokeMethod(this, [this, id, ok, err]() { done(id, ok, err); }, Qt::QueuedConnection);
        });
        return id;
    }
#endif
    m_jobs[id].stop = new QAtomicInt(0);
    runQt(id, kind, sources, dest);
    return id;
}

void FileOps::runQt(int id, const QString &kind, const QStringList &sources, const QString &dest) {
    QAtomicInt *stop = m_jobs[id].stop;
    QPointer<FileOps> self(this);
    auto report = [self, id](double f) {
        QMetaObject::invokeMethod(qApp, [self, id, f]() {
            if (!self || !self->m_jobs.contains(id)) return;
            self->m_jobs[id].fraction = f;
            emit self->progress(id, f, self->m_jobs[id].label);
            emit self->jobsChanged();
        }, Qt::QueuedConnection);
    };
    const QString trashName = trashRoot();
    QThread *t = QThread::create([=]() {
        QString err;
        bool ok = true;
        if (kind == QLatin1String("copy") || kind == QLatin1String("move")) {
            qint64 total = 0, doneBytes = 0;
            for (const QString &s : sources) total += treeSize(s);
            for (const QString &s : sources) {
                QFileInfo fi(s);
                QString target = dest + QLatin1Char('/') + fi.fileName();
                if (QFileInfo::exists(target)) {   // stesso comportamento di KIO con rinomina automatica
                    const QString base = fi.isDir() ? fi.fileName() : fi.completeBaseName(), suf = fi.isDir() ? QString() : fi.suffix();
                    for (int n = 1; QFileInfo::exists(target); ++n)
                        target = dest + QLatin1Char('/') + base + QStringLiteral(" (%1)").arg(n) + (suf.isEmpty() ? QString() : QLatin1Char('.') + suf);
                }
                if (kind == QLatin1String("move") && QFile::rename(s, target)) { doneBytes += treeSize(target); report(total ? double(doneBytes) / total : 1); continue; }
                if (QDir(target).absolutePath().startsWith(QDir(s).absolutePath() + QLatin1Char('/'))) { ok = false; err = tr("Impossibile copiare una cartella dentro sé stessa"); break; }
                if (!copyRecursive(s, target, doneBytes, total, stop, report, &err)) { ok = false; break; }
                if (kind == QLatin1String("move")) {
                    const bool rm = fi.isDir() ? QDir(s).removeRecursively() : QFile::remove(s);
                    if (!rm) { ok = false; err = humanError(tr("Rimozione dell'originale"), s); break; }
                }
            }
        } else if (kind == QLatin1String("trash")) {
            // cestino personale presente prima dello spostamento (altrimenti Qt sceglierebbe
            // un cestino sulla radice del disco, non elencato dalla pagina Cestino)
            QDir().mkpath(trashName + QStringLiteral("/files"));
            QDir().mkpath(trashName + QStringLiteral("/info"));
            int i = 0;
            for (const QString &s : sources) {
                if (!QFile::moveToTrash(s)) { ok = false; err = humanError(tr("Spostamento nel cestino"), s); break; }
                report(double(++i) / sources.size());
            }
        } else if (kind == QLatin1String("remove")) {
            int i = 0;
            for (const QString &s : sources) {
                QFileInfo fi(s);
                const bool rm = fi.isDir() && !fi.isSymLink() ? QDir(s).removeRecursively() : QFile::remove(s);
                if (!rm) { ok = false; err = humanError(tr("Eliminazione"), s); break; }
                report(double(++i) / sources.size());
            }
        } else if (kind == QLatin1String("compress") || kind == QLatin1String("extract")) {
#ifdef OMNI_HAVE_KARCHIVE
            if (kind == QLatin1String("compress")) {
                KZip z(dest);
                if (QFileInfo::exists(dest) || !z.open(QIODevice::WriteOnly)) { ok = false; err = humanError(tr("Creazione dell'archivio"), dest); }
                else {
                    int i = 0;
                    for (const QString &s : sources) {
                        if (stop->loadRelaxed()) { ok = false; err = tr("Annullato"); break; }
                        QFileInfo fi(s);
                        const bool r = fi.isDir() ? z.addLocalDirectory(s, fi.fileName()) : z.addLocalFile(s, fi.fileName());
                        if (!r) { ok = false; err = humanError(tr("Aggiunta all'archivio"), s); break; }
                        report(double(++i) / sources.size());
                    }
                    z.close();
                    if (!ok) QFile::remove(dest);
                }
            } else {
                KZip z(sources.first());
                if (!z.open(QIODevice::ReadOnly)) { ok = false; err = humanError(tr("Apertura dell'archivio"), sources.first()); }
                else if (!QDir().mkpath(dest) || !z.directory()->copyTo(dest, true)) { ok = false; err = humanError(tr("Estrazione"), dest); }
                report(1);
            }
#else
            ok = false;
            err = tr("Archivi ZIP non disponibili in questa versione");
            Q_UNUSED(stop)
#endif
        }
        QMetaObject::invokeMethod(qApp, [self, id, ok, err]() { if (self) self->done(id, ok, err); }, Qt::QueuedConnection);
    });
    connect(t, &QThread::finished, t, &QObject::deleteLater);
    m_jobs[id].handle = t;
    t->start();
}

void FileOps::cancel(int id) {
    auto it = m_jobs.find(id);
    if (it == m_jobs.end()) return;
    if (it->stop) it->stop->storeRelaxed(1);
#ifdef OMNI_HAVE_KIO
    else if (auto *j = qobject_cast<KJob *>(it->handle.data())) j->kill(KJob::EmitResult);
#endif
}

void FileOps::done(int id, bool ok, const QString &error) {
    auto it = m_jobs.find(id);
    if (it == m_jobs.end()) return;
    QAtomicInt *stop = it->stop;
    m_jobs.erase(it);
    emit finished(id, ok, ok ? QString() : error);
    emit jobsChanged();
    // il thread può ancora leggere il flag fino alla sua chiusura: rilascio differito
    if (stop) QTimer::singleShot(5000, [stop]() { delete stop; });
}

QString FileOps::mkdir(const QString &parentDir, const QString &name) {
    if (name.isEmpty() || name.contains(QLatin1Char('/')) || name == QLatin1String(".") || name == QLatin1String("..")) return tr("Nome non valido");
    const QString p = parentDir + QLatin1Char('/') + name;
    if (QFileInfo::exists(p)) return tr("Esiste già un elemento con questo nome");
    return QDir(parentDir).mkdir(name) ? QString() : humanError(tr("Creazione della cartella"), p);
}
QString FileOps::rename(const QString &path, const QString &newName) {
    if (newName.isEmpty() || newName.contains(QLatin1Char('/')) || newName == QLatin1String(".") || newName == QLatin1String("..")) return tr("Nome non valido");
    const QFileInfo fi(path);
    const QString target = fi.absolutePath() + QLatin1Char('/') + newName;
    if (target == fi.absoluteFilePath()) return {};
    if (QFileInfo::exists(target)) return tr("Esiste già un elemento con questo nome");
    return QFile::rename(path, target) ? QString() : humanError(tr("Rinomina"), path);
}
QString FileOps::setPermissions(const QString &path, int mode) {
    struct stat st {};
    if (::lstat(QFile::encodeName(path).constData(), &st) != 0) return tr("Elemento non trovato");
    if (st.st_uid != ::getuid()) return tr("Solo il proprietario può cambiare i permessi");
    // solo lettura/scrittura/esecuzione: nessun setuid/setgid concesso da qui
    return ::chmod(QFile::encodeName(path).constData(), mode_t(mode & 0777)) == 0 ? QString() : humanError(tr("Modifica dei permessi"), path);
}
QString FileOps::uniqueName(const QString &dir, const QString &name) const {
    QString n = name;
    const QFileInfo fi(name);
    for (int i = 2; QFileInfo::exists(dir + QLatin1Char('/') + n); ++i)
        n = fi.completeBaseName() + QStringLiteral(" (%1)").arg(i) + (fi.suffix().isEmpty() ? QString() : QLatin1Char('.') + fi.suffix());
    return n;
}
bool FileOps::open(const QString &path) { return QDesktopServices::openUrl(QUrl::fromLocalFile(path)); }

QVariantMap FileOps::properties(const QString &path) const {
    QVariantMap m;
    struct stat st {};
    if (::lstat(QFile::encodeName(path).constData(), &st) != 0) return m;
    const QFileInfo fi(path);
    const FileEntry e = entryFor(fi);
    const passwd *pw = getpwuid(st.st_uid);
    const group *gr = getgrgid(st.st_gid);
    m.insert("name", e.name);
    m.insert("path", e.path);
    m.insert("folder", fi.absolutePath());
    m.insert("isDir", e.dir);
    m.insert("isLink", e.link);
    m.insert("target", e.target);
    m.insert("type", e.mimeComment);
    m.insert("mime", e.mime);
    m.insert("icon", e.icon);
    m.insert("size", double(e.size));
    m.insert("modified", fi.lastModified());
    m.insert("accessed", fi.lastRead());
    m.insert("created", fi.birthTime().isValid() ? fi.birthTime() : QVariant());
    m.insert("owner", pw ? QString::fromLocal8Bit(pw->pw_name) : QString::number(st.st_uid));
    m.insert("group", gr ? QString::fromLocal8Bit(gr->gr_name) : QString::number(st.st_gid));
    m.insert("mode", int(st.st_mode & 07777));
    m.insert("mine", st.st_uid == ::getuid());
    m.insert("writable", fi.isWritable());
    const QStorageInfo si(fi.absolutePath());
    m.insert("volume", si.displayName());
    m.insert("free", double(si.bytesAvailable()));
    return m;
}

int FileOps::folderSize(const QString &path) {
    const int id = m_next++;
    QPointer<FileOps> self(this);
    QThread *t = QThread::create([self, id, path]() {
        int files = 0;
        const qint64 s = treeSize(path, &files);
        QMetaObject::invokeMethod(qApp, [self, id, s, files]() { if (self) emit self->sizeReady(id, s, files); }, Qt::QueuedConnection);
    });
    connect(t, &QThread::finished, t, &QObject::deleteLater);
    t->start(QThread::LowPriority);
    return id;
}

QVariantList FileOps::volumes() const {
    QVariantList out;
    static const QStringList pseudo = {"tmpfs", "devtmpfs", "proc", "sysfs", "overlay", "squashfs", "cgroup2", "devpts", "efivarfs", "composefs", "fuse.portal"};
    for (const QStorageInfo &v : QStorageInfo::mountedVolumes()) {
        if (!v.isValid() || !v.isReady() || pseudo.contains(QString::fromLatin1(v.fileSystemType()))) continue;
        const QString root = v.rootPath();
        const bool removable = root.startsWith(QLatin1String("/run/media/")) || root.startsWith(QLatin1String("/media/"));
        if (!removable && root != QLatin1String("/") && !root.startsWith(QLatin1String("/var/home")) && !root.startsWith(QLatin1String("/home"))) continue;
        out << QVariantMap{{"path", root == QLatin1String("/") ? QStringLiteral("/") : root},
                           {"name", root == QLatin1String("/") ? tr("Sistema") : (removable ? v.displayName() : tr("Dati personali"))},
                           {"removable", removable}, {"total", double(v.bytesTotal())}, {"free", double(v.bytesAvailable())},
                           {"fs", QString::fromLatin1(v.fileSystemType())}, {"readOnly", v.isReadOnly()}};
    }
    return out;
}

QVariantList FileOps::places() const {
    QVariantList out;
    const QString home = QDir::homePath();
    out << QVariantMap{{"id", "home"}, {"label", tr("Home")}, {"glyph", "home"}, {"path", home}};
    const struct { QStandardPaths::StandardLocation loc; const char *id, *glyph; QString label; } list[] = {
        {QStandardPaths::DesktopLocation, "desktop", "display", tr("Desktop")},
        {QStandardPaths::DocumentsLocation, "documenti", "briefcase", tr("Documenti")},
        {QStandardPaths::DownloadLocation, "download", "arrow-up", tr("Download")},
        {QStandardPaths::PicturesLocation, "immagini", "image", tr("Immagini")},
        {QStandardPaths::MusicLocation, "musica", "music", tr("Musica")},
        {QStandardPaths::MoviesLocation, "video", "eye", tr("Video")}};
    for (const auto &e : list) {
        const QString p = QStandardPaths::writableLocation(e.loc);
        if (p.isEmpty() || p == home || !QFileInfo(p).isDir()) continue;
        out << QVariantMap{{"id", QString::fromLatin1(e.id)}, {"label", e.label}, {"glyph", QString::fromLatin1(e.glyph)}, {"path", p}};
    }
    return out;
}

QString FileOps::readText(const QString &path, int maxBytes) const {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    const QByteArray b = f.read(qBound(0, maxBytes, 65536));
    if (b.contains('\0')) return {};   // non è testo
    return QString::fromUtf8(b);
}

void FileOps::setClipboard(const QStringList &paths, bool cut) {
    auto *md = new QMimeData;
    QList<QUrl> urls;
    for (const QString &p : paths) urls << QUrl::fromLocalFile(p);
    md->setUrls(urls);
    md->setData(QStringLiteral("application/x-kde-cutselection"), cut ? "1" : "0");
    QGuiApplication::clipboard()->setMimeData(md);
}
QVariantMap FileOps::clipboard() const {
    const QMimeData *md = QGuiApplication::clipboard()->mimeData();
    QStringList paths;
    bool cut = false;
    if (md) {
        for (const QUrl &u : md->urls()) if (u.isLocalFile()) paths << u.toLocalFile();
        cut = md->data(QStringLiteral("application/x-kde-cutselection")) == "1";
    }
    return {{"paths", paths}, {"cut", cut}};
}
bool FileOps::hasClipboard() const {
    const QMimeData *md = QGuiApplication::clipboard()->mimeData();
    return md && md->hasUrls();
}

QString FileOps::trashDir() const { return trashRoot(); }
QVariantList FileOps::trashItems() const {
    QVariantList out;
    const QString root = trashRoot();
    const auto infos = QDir(root + QStringLiteral("/info")).entryInfoList({QStringLiteral("*.trashinfo")}, QDir::Files | QDir::Hidden, QDir::Time);
    for (const QFileInfo &fi : infos) {
        QSettings s(fi.absoluteFilePath(), QSettings::IniFormat);
        const QString orig = QUrl::fromPercentEncoding(s.value(QStringLiteral("Trash Info/Path")).toByteArray());
        const QString name = fi.completeBaseName();   // nome dentro files/ (senza .trashinfo)
        const QString stored = root + QStringLiteral("/files/") + name;
        const QFileInfo sf(stored);
        if (!sf.exists() && !sf.isSymLink()) continue;
        const FileEntry e = entryFor(sf);
        out << QVariantMap{{"trashName", name}, {"name", QFileInfo(orig).fileName()}, {"originalPath", orig}, {"path", stored},
                           {"deleted", QDateTime::fromString(s.value(QStringLiteral("Trash Info/DeletionDate")).toString(), Qt::ISODate)},
                           {"isDir", e.dir}, {"size", double(e.dir ? 0 : e.size)}, {"iconName", e.icon}, {"typeName", e.mimeComment}};
    }
    return out;
}
QString FileOps::restore(const QStringList &trashNames) {
    const QString root = trashRoot();
    QStringList errors;
    for (const QString &n : trashNames) {
        if (n.contains(QLatin1Char('/'))) continue;
        const QString info = root + QStringLiteral("/info/") + n + QStringLiteral(".trashinfo");
        QSettings s(info, QSettings::IniFormat);
        QString orig = QUrl::fromPercentEncoding(s.value(QStringLiteral("Trash Info/Path")).toByteArray());
        if (orig.isEmpty()) { errors << n; continue; }
        if (!orig.startsWith(QLatin1Char('/'))) orig = QDir::homePath() + QLatin1Char('/') + orig;
        const QFileInfo of(orig);
        QDir().mkpath(of.absolutePath());
        const QString target = of.absolutePath() + QLatin1Char('/') + uniqueName(of.absolutePath(), of.fileName());
        if (!QFile::rename(root + QStringLiteral("/files/") + n, target)) { errors << of.fileName(); continue; }
        QFile::remove(info);
    }
    return errors.isEmpty() ? QString() : tr("Non ripristinati: %1").arg(errors.join(QStringLiteral(", ")));
}
QString FileOps::removeFromTrash(const QStringList &trashNames) {
    const QString root = trashRoot();
    QStringList errors;
    for (const QString &n : trashNames) {
        if (n.contains(QLatin1Char('/')) || n.isEmpty()) continue;
        const QString f = root + QStringLiteral("/files/") + n;
        const QFileInfo fi(f);
        const bool ok = fi.isDir() && !fi.isSymLink() ? QDir(f).removeRecursively() : QFile::remove(f);
        if (!ok) { errors << n; continue; }
        QFile::remove(root + QStringLiteral("/info/") + n + QStringLiteral(".trashinfo"));
    }
    return errors.isEmpty() ? QString() : tr("Non eliminati: %1").arg(errors.join(QStringLiteral(", ")));
}
