#include "appstream.h"
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QPointer>
#include <QSysInfo>
#include <QThread>
#include <QXmlStreamReader>
#include <algorithm>
#ifdef OMNI_HAVE_KARCHIVE
#include <KCompressionDevice>
#endif

namespace {
const QHash<QString, QString> &categoryNames() {
    static const QHash<QString, QString> n = {
        {"Office", QObject::tr("Ufficio")}, {"Graphics", QObject::tr("Grafica")}, {"AudioVideo", QObject::tr("Audio e video")},
        {"Game", QObject::tr("Giochi")}, {"Development", QObject::tr("Sviluppo")}, {"Education", QObject::tr("Istruzione")},
        {"Network", QObject::tr("Internet")}, {"Science", QObject::tr("Scienza")}, {"System", QObject::tr("Sistema")},
        {"Utility", QObject::tr("Accessori")}};
    return n;
}
// punteggio della lingua: 2 = lingua completa (it_IT), 1 = lingua (it), 0 = predefinita
int langScore(const QString &attr, const QString &lang) {
    if (attr.isEmpty()) return 0;
    if (attr == lang) return 2;
    if (attr == lang.section(QLatin1Char('_'), 0, 0)) return 1;
    return -1;
}
QByteArray readMaybeGz(const QString &path) {
    if (path.endsWith(QLatin1String(".gz"))) {
#ifdef OMNI_HAVE_KARCHIVE
        KCompressionDevice dev(path, KCompressionDevice::GZip);
        if (dev.open(QIODevice::ReadOnly)) return dev.readAll();
#endif
        return {};
    }
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
}
}  // namespace

AppStreamCatalog::AppStreamCatalog(QObject *parent) : QAbstractListModel(parent) {
    m_roots = {QDir::homePath() + QStringLiteral("/.local/share/flatpak/appstream"), QStringLiteral("/var/lib/flatpak/appstream")};
}
AppStreamCatalog::~AppStreamCatalog() { m_gen.fetchAndAddRelaxed(1); }

QVector<StoreApp> AppStreamCatalog::parse(const QByteArray &xml, const QString &remote, const QString &iconDir, const QString &lang) {
    QVector<StoreApp> out;
    QXmlStreamReader r(xml);
    while (!r.atEnd()) {
        r.readNext();
        if (!r.isStartElement() || r.name() != QLatin1String("component")) continue;
        const QString type = r.attributes().value(QLatin1String("type")).toString();
        const bool app = type == QLatin1String("desktop-application") || type == QLatin1String("desktop");
        StoreApp a;
        a.remote = remote;
        int nameScore = -2, sumScore = -2, descScore = -2;
        QString descBuf;
        int depth = 1;
        while (!r.atEnd() && depth > 0) {
            r.readNext();
            if (r.isEndElement()) { --depth; continue; }
            if (!r.isStartElement()) continue;
            ++depth;
            const auto n = r.name();
            const QString l = r.attributes().value(QLatin1String("xml:lang")).toString();
            if (depth == 2 && n == QLatin1String("id")) { a.id = r.readElementText(); --depth; }
            else if (depth == 2 && n == QLatin1String("name")) {
                const int s = langScore(l, lang); const QString t = r.readElementText(); --depth;
                if (s > nameScore) { nameScore = s; a.name = t; }
            } else if (depth == 2 && n == QLatin1String("summary")) {
                const int s = langScore(l, lang); const QString t = r.readElementText(); --depth;
                if (s > sumScore) { sumScore = s; a.summary = t; }
            } else if (depth == 2 && n == QLatin1String("description")) {
                // descrizione: paragrafi ed elenchi in testo semplice, nella lingua migliore
                const int dl = langScore(l, lang);
                QHash<int, QString> byScore;
                int d2 = 1;
                while (!r.atEnd() && d2 > 0) {
                    r.readNext();
                    if (r.isEndElement()) { --d2; continue; }
                    if (!r.isStartElement()) continue;
                    ++d2;
                    if (r.name() == QLatin1String("p") || r.name() == QLatin1String("li")) {
                        const bool li = r.name() == QLatin1String("li");
                        const QString pl = r.attributes().value(QLatin1String("xml:lang")).toString();
                        const int s = pl.isEmpty() ? dl : langScore(pl, lang);
                        const QString t = r.readElementText(QXmlStreamReader::IncludeChildElements).simplified();
                        --d2;
                        if (s >= 0) byScore[s] += (li ? QStringLiteral("• ") : QString()) + t + QStringLiteral("\n");
                    }
                }
                --depth;
                for (int s = 2; s >= 0; --s)
                    if (byScore.contains(s) && s > descScore) { descScore = s; descBuf = byScore.value(s); break; }
            } else if (depth == 2 && n == QLatin1String("icon")) {
                const QString t = r.attributes().value(QLatin1String("type")).toString();
                const QString h = r.attributes().value(QLatin1String("height")).toString();
                const QString v = r.readElementText(); --depth;
                if (t == QLatin1String("cached") && (a.icon.isEmpty() || h == QLatin1String("128"))) {
                    for (const QString &size : {QStringLiteral("128x128"), QStringLiteral("64x64")}) {
                        const QString p = iconDir + QLatin1Char('/') + size + QLatin1Char('/') + v;
                        if (QFileInfo::exists(p)) { a.icon = p; break; }
                    }
                }
            } else if (depth == 3 && n == QLatin1String("category")) { a.categories << r.readElementText(); --depth; }
            else if (depth == 3 && n == QLatin1String("keyword") && (l.isEmpty() || langScore(l, lang) > 0)) { a.keywords << r.readElementText(); --depth; }
            else if (depth == 2 && n == QLatin1String("developer_name") && (l.isEmpty() || a.developer.isEmpty())) { a.developer = r.readElementText(); --depth; }
            else if (depth == 3 && n == QLatin1String("name") && a.developer.isEmpty()) { a.developer = r.readElementText(); --depth; }   // <developer><name>
            else if (depth == 2 && n == QLatin1String("project_license")) { a.license = r.readElementText(); --depth; }
            else if (depth == 2 && n == QLatin1String("url") && r.attributes().value(QLatin1String("type")) == QLatin1String("homepage")) { a.homepage = r.readElementText(); --depth; }
            else if (depth == 2 && n == QLatin1String("bundle") && r.attributes().value(QLatin1String("type")) == QLatin1String("flatpak")) { a.ref = r.readElementText(); --depth; }
            else if (depth == 4 && n == QLatin1String("image") && a.screenshot.isEmpty()) {
                const QString t = r.attributes().value(QLatin1String("type")).toString();
                const int w = r.attributes().value(QLatin1String("width")).toInt();
                const QString v = r.readElementText(); --depth;
                if (t == QLatin1String("source") || (t == QLatin1String("thumbnail") && w >= 600)) a.screenshot = v;
            } else if (depth == 3 && n == QLatin1String("release") && a.version.isEmpty()) {
                a.version = r.attributes().value(QLatin1String("version")).toString();
                a.released = r.attributes().value(QLatin1String("timestamp")).toLongLong();
                if (!a.released) {
                    const QString date = r.attributes().value(QLatin1String("date")).toString();
                    if (!date.isEmpty()) a.released = QDateTime::fromString(date, Qt::ISODate).toSecsSinceEpoch();
                }
            }
        }
        a.description = descBuf.trimmed();
        if (a.id.endsWith(QLatin1String(".desktop"))) a.id.chop(8);
        if (app && !a.id.isEmpty() && !a.name.isEmpty()) {
            if (a.ref.isEmpty()) a.ref = QStringLiteral("app/") + a.id;
            out << a;
        }
    }
    return out;
}

void AppStreamCatalog::reload() {
    const int gen = m_gen.fetchAndAddRelaxed(1) + 1;
    m_loading = true;
    emit loadingChanged();
    const QStringList roots = m_roots;
    const QString lang = QLocale::system().name();
    const QString arch = QSysInfo::currentCpuArchitecture();
    QPointer<AppStreamCatalog> self(this);
    QThread *t = QThread::create([=]() {
        QVector<StoreApp> all;
        QStringList sources, errors;
        QSet<QString> seen;
        for (const QString &root : roots) {
            for (const QString &remote : QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
                if (seen.contains(remote)) continue;   // stessa sorgente utente e di sistema: una volta sola
                const QString base = root + QLatin1Char('/') + remote + QLatin1Char('/') + arch + QStringLiteral("/active");
                QByteArray xml = readMaybeGz(base + QStringLiteral("/appstream.xml"));
                if (xml.isEmpty()) xml = readMaybeGz(base + QStringLiteral("/appstream.xml.gz"));
                if (xml.isEmpty()) { errors << remote; continue; }
                seen.insert(remote);
                sources << remote;
                all += parse(xml, remote, base + QStringLiteral("/icons"), lang);
            }
        }
        QMetaObject::invokeMethod(qApp, [self, gen, all, sources, errors]() {
            if (!self || self->m_gen.loadRelaxed() != gen) return;
            self->m_apps = all;
            self->m_index.clear();
            for (int i = 0; i < all.size(); ++i) if (!self->m_index.contains(all.at(i).id)) self->m_index.insert(all.at(i).id, i);
            self->m_sources = sources;
            self->m_error = all.isEmpty() ? (errors.isEmpty() ? tr("Nessun catalogo scaricato") : tr("Catalogo non leggibile: %1").arg(errors.join(QStringLiteral(", ")))) : QString();
            self->m_loading = false;
            self->applyView();
            emit self->loadingChanged();
        }, Qt::QueuedConnection);
    });
    connect(t, &QThread::finished, t, &QObject::deleteLater);
    t->start(QThread::LowPriority);
}

int AppStreamCatalog::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_view.size(); }
QHash<int, QByteArray> AppStreamCatalog::roleNames() const {
    return {{IdRole, "appId"}, {NameRole, "name"}, {SummaryRole, "summary"}, {IconRole, "icon"}, {CategoriesRole, "categories"},
            {DeveloperRole, "developer"}, {VersionRole, "version"}, {InstalledRole, "installed"}, {UpdateRole, "updateAvailable"}, {RemoteRole, "remote"}};
}
QVariant AppStreamCatalog::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_view.size()) return {};
    const StoreApp &a = m_apps.at(m_view.at(index.row()));
    switch (role) {
    case Qt::DisplayRole: case NameRole: return a.name;
    case IdRole: return a.id;
    case SummaryRole: return a.summary;
    case IconRole: return a.icon;
    case CategoriesRole: return a.categories;
    case DeveloperRole: return a.developer;
    case VersionRole: return a.version;
    case InstalledRole: return m_installed.contains(a.id);
    case UpdateRole: return m_updates.contains(a.id);
    case RemoteRole: return a.remote;
    }
    return {};
}

QVariantMap AppStreamCatalog::get(const QString &appId) const {
    const auto it = m_index.constFind(appId);
    QVariantMap m;
    if (it != m_index.constEnd()) {
        const StoreApp &a = m_apps.at(*it);
        m = {{"appId", a.id}, {"name", a.name}, {"summary", a.summary}, {"description", a.description}, {"icon", a.icon},
             {"developer", a.developer}, {"license", a.license}, {"homepage", a.homepage}, {"screenshot", a.screenshot},
             {"version", a.version}, {"released", a.released ? QDateTime::fromSecsSinceEpoch(a.released) : QVariant()},
             {"ref", a.ref}, {"remote", a.remote}, {"categories", a.categories}, {"inCatalog", true}};
    } else if (m_installed.contains(appId)) {
        m = m_installed.value(appId);   // installata ma non (più) nel catalogo
        m.insert("inCatalog", false);
    }
    if (!m.isEmpty()) {
        m.insert("installed", m_installed.contains(appId));
        m.insert("installation", m_installed.value(appId).value("installation"));
        m.insert("installedVersion", m_installed.value(appId).value("version"));
        m.insert("updateAvailable", m_updates.contains(appId));
    }
    return m;
}
QVariantMap AppStreamCatalog::at(int row) const {
    if (row < 0 || row >= m_view.size()) return {};
    return get(m_apps.at(m_view.at(row)).id);
}

void AppStreamCatalog::setInstalled(const QString &out) {
    m_installed.clear();
    for (const QString &line : out.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        const QStringList f = line.split(QLatin1Char('\t'));
        if (f.size() < 2 || f.at(0).isEmpty()) continue;
        m_installed.insert(f.at(0), QVariantMap{{"appId", f.at(0)}, {"name", f.value(1)}, {"version", f.value(2)}, {"remote", f.value(3)},
                                                {"installation", f.value(4)}, {"summary", QString()}, {"icon", QString()}});
    }
    if (!m_view.isEmpty()) emit dataChanged(index(0), index(m_view.size() - 1), {InstalledRole});
    emit installedChanged();
}
void AppStreamCatalog::setUpdates(const QString &out) {
    m_updates.clear();
    for (const QString &line : out.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        const QStringList f = line.split(QLatin1Char('\t'));
        if (!f.value(0).isEmpty() && f.value(0).contains(QLatin1Char('.'))) m_updates.insert(f.at(0), f.value(1));
    }
    if (!m_view.isEmpty()) emit dataChanged(index(0), index(m_view.size() - 1), {UpdateRole});
    emit installedChanged();
}
QVariantList AppStreamCatalog::installed() const {
    QVariantList out;
    QStringList ids = m_installed.keys();
    std::sort(ids.begin(), ids.end(), [this](const QString &a, const QString &b) {
        return get(a).value("name").toString().compare(get(b).value("name").toString(), Qt::CaseInsensitive) < 0; });
    for (const QString &id : ids) out << get(id);
    return out;
}
QVariantList AppStreamCatalog::updates() const {
    QVariantList out;
    for (auto it = m_updates.cbegin(); it != m_updates.cend(); ++it) { QVariantMap m = get(it.key()); if (m.isEmpty()) m = {{"appId", it.key()}, {"name", it.key()}}; m.insert("newVersion", it.value()); out << m; }
    return out;
}
QStringList AppStreamCatalog::categoryIds() const { return {"Office", "Graphics", "AudioVideo", "Game", "Development", "Education", "Network", "Science", "System", "Utility"}; }
QString AppStreamCatalog::categoryName(const QString &id) const { return categoryNames().value(id, id); }

void AppStreamCatalog::setSearch(const QString &s) { if (s == m_search) return; m_search = s; applyView(); }
void AppStreamCatalog::setCategory(const QString &c) { if (c == m_category) return; m_category = c; applyView(); }
void AppStreamCatalog::setSortKey(const QString &k) { if (k == m_sort) return; m_sort = k; applyView(); }

void AppStreamCatalog::applyView() {
    QVector<int> v;
    const QString q = m_search.trimmed();
    QSet<QString> once;
    for (int i = 0; i < m_apps.size(); ++i) {
        const StoreApp &a = m_apps.at(i);
        if (once.contains(a.id)) continue;
        if (!m_category.isEmpty() && !a.categories.contains(m_category)) continue;
        if (!q.isEmpty() && !a.name.contains(q, Qt::CaseInsensitive) && !a.summary.contains(q, Qt::CaseInsensitive)
            && !a.id.contains(q, Qt::CaseInsensitive) && !a.keywords.join(QLatin1Char(' ')).contains(q, Qt::CaseInsensitive)) continue;
        once.insert(a.id);
        v << i;
    }
    const QString key = m_sort;
    std::stable_sort(v.begin(), v.end(), [this, key, &q](int x, int y) {
        const StoreApp &a = m_apps.at(x), &b = m_apps.at(y);
        if (!q.isEmpty()) {   // con una ricerca, prima le corrispondenze nel nome
            const bool an = a.name.startsWith(q, Qt::CaseInsensitive), bn = b.name.startsWith(q, Qt::CaseInsensitive);
            if (an != bn) return an;
        }
        if (key == QLatin1String("recent") && a.released != b.released) return a.released > b.released;
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });
    beginResetModel();
    m_view = v;
    endResetModel();
    emit viewChanged();
}
