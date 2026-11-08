#include "desktopentries.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>
#include <algorithm>

DesktopEntryModel::DesktopEntryModel(QObject *parent) : QAbstractListModel(parent) {}

int DesktopEntryModel::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : count(); }

QVariant DesktopEntryModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= count()) return {};
    const auto &e = m_entries.at(index.row());
    switch (role) {
    case NameRole: return e.name;
    case CommentRole: return e.comment;
    case IconRole: return e.icon;
    case CategoriesRole: return e.categories;
    case IdRole: return e.id;
    }
    return {};
}

QHash<int, QByteArray> DesktopEntryModel::roleNames() const {
    return {{NameRole, "name"}, {CommentRole, "comment"}, {IconRole, "iconName"}, {CategoriesRole, "categories"}, {IdRole, "desktopId"}};
}

QVariantMap DesktopEntryModel::get(int row) const {
    if (row < 0 || row >= count()) return {};
    const auto &e = m_entries.at(row);
    return {{"name", e.name}, {"comment", e.comment}, {"iconName", e.icon}, {"categories", e.categories}, {"desktopId", e.id}};
}

static QString localized(const QHash<QString, QString> &kv, const QString &key, const QString &locale) {
    if (!locale.isEmpty()) {
        if (kv.contains(key + "[" + locale + "]")) return kv.value(key + "[" + locale + "]");
        const QString lang = locale.section('_', 0, 0);
        if (kv.contains(key + "[" + lang + "]")) return kv.value(key + "[" + lang + "]");
    }
    return kv.value(key);
}

bool DesktopEntryModel::parseFile(const QString &path, const QString &locale, DesktopEntry *out) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    QTextStream in(&f);
    QHash<QString, QString> kv;
    bool inMain = false;
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;
        if (line.startsWith('[')) { inMain = (line == QLatin1String("[Desktop Entry]")); continue; }
        if (!inMain) continue;
        const int eq = line.indexOf('=');
        if (eq <= 0) continue;
        kv.insert(line.left(eq).trimmed(), line.mid(eq + 1).trimmed());
    }
    auto isTrue = [&](const QString &k) { return kv.value(k).compare("true", Qt::CaseInsensitive) == 0; };
    if (kv.value("Type") != QLatin1String("Application")) return false;
    if (isTrue("NoDisplay") || isTrue("Hidden")) return false;
    const QString name = localized(kv, "Name", locale);
    if (name.isEmpty()) return false;
    out->id = QFileInfo(path).fileName();
    out->name = name;
    out->comment = localized(kv, "Comment", locale);
    out->icon = kv.value("Icon");
    out->categories = kv.value("Categories").split(';', Qt::SkipEmptyParts);
    return true;
}

int DesktopEntryModel::load(const QStringList &dirsIn, const QString &locale) {
    QStringList dirs = dirsIn;
    if (dirs.isEmpty()) dirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    QVector<DesktopEntry> entries;
    QSet<QString> seen;   // le cartelle con priorità più alta vengono prima (regola XDG)
    for (const QString &dir : dirs) {
        QDirIterator it(dir, {"*.desktop"}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            const QString id = QFileInfo(path).fileName();
            if (seen.contains(id)) continue;
            seen.insert(id);
            DesktopEntry e;
            if (parseFile(path, locale, &e)) entries.push_back(e);
        }
    }
    std::sort(entries.begin(), entries.end(), [](const DesktopEntry &a, const DesktopEntry &b) {
        return QString::localeAwareCompare(a.name, b.name) < 0;
    });
    beginResetModel();
    m_entries = entries;
    m_demo = false;
    endResetModel();
    emit countChanged();
    return count();
}

void DesktopEntryModel::loadDemo() {
    const QList<QPair<QString, QString>> demo = {
        {"OMNI File Manager", "Prototipo (decisione 12)"}, {"OMNI Terminal", "Prototipo (decisione 49)"},
        {"OMNI Store", "Prototipo (decisione 11)"}, {"OMNI Browser", "Prototipo (decisione 19)"},
        {"OMNI Update Center", "Prototipo (decisione 15)"}, {"OMNI Security Center", "Prototipo (decisione 14)"},
        {"OMNI Performance Center", "Prototipo (decisione 13)"}, {"OMNI Network Center", "Prototipo (decisione 27)"},
        {"OMNI Storage Center", "Prototipo (decisione 26)"}, {"OMNI Media Suite", "Prototipo (decisione 18)"},
        {"OMNI Office Suite", "Prototipo (decisione 34)"}, {"OMNI Gaming Hub", "Prototipo (decisione 32)"},
        {"OMNI Developer Studio", "Prototipo (decisione 25)"}, {"OMNI Display Center", "Prototipo (decisione 37)"},
        {"OMNI Audio Center", "Prototipo (decisione 31)"}, {"OMNI Accessibility", "Prototipo (decisione 39)"}};
    beginResetModel();
    m_entries.clear();
    for (const auto &p : demo) m_entries.push_back({p.first.toLower().replace(' ', '-') + ".desktop", p.first, p.second, {}, {}});
    m_demo = true;
    endResetModel();
    emit countChanged();
}
