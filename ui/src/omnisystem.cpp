#include "omnisystem.h"
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>
#include <QDateTime>
#include <QMap>
#include <QDirIterator>

OmniSystem::OmniSystem(QObject *parent) : QObject(parent) {}

QStringList OmniSystem::allowedPrograms() {
    // Solo strumenti di sola lettura o che chiedono da soli l'autorizzazione (polkit) per le
    // modifiche di sistema. Nessun interprete di comandi, nessun pkexec/sudo.
    return {QStringLiteral("kreadconfig6"), QStringLiteral("kwriteconfig6"), QStringLiteral("timedatectl"),
            QStringLiteral("localectl"), QStringLiteral("xdg-mime"), QStringLiteral("flatpak"),
            QStringLiteral("rpm-ostree"), QStringLiteral("du"), QStringLiteral("df"), QStringLiteral("journalctl"),
            QStringLiteral("systemctl"), QStringLiteral("firewall-cmd"), QStringLiteral("plasma-apply-colorscheme"),
            QStringLiteral("plasma-apply-wallpaperimage"), QStringLiteral("kcmshell6"), QStringLiteral("systemsettings"),
            QStringLiteral("rsync"), QStringLiteral("loginctl"), QStringLiteral("lscpu"), QStringLiteral("uname"),
            QStringLiteral("hostnamectl"), QStringLiteral("kscreen-doctor"), QStringLiteral("coredumpctl"),
            QStringLiteral("lsblk"), QStringLiteral("findmnt"), QStringLiteral("ps"), QStringLiteral("gio"),
            QStringLiteral("kioclient"), QStringLiteral("ark")};
}

bool OmniSystem::available(const QString &program) const {
    return allowedPrograms().contains(program) && !QStandardPaths::findExecutable(program).isEmpty();
}

int OmniSystem::run(const QString &program, const QStringList &args, int timeoutMs, bool streamLines) {
    const int id = m_next++;
    if (!allowedPrograms().contains(program)) {
        qWarning("sistema: programma non consentito: %s", qPrintable(program));
        QTimer::singleShot(0, this, [this, id, program]() { emit finished(id, -2, {}, tr("Programma non consentito: %1").arg(program)); });
        return id;
    }
    const QString exe = QStandardPaths::findExecutable(program);
    if (exe.isEmpty()) {
        QTimer::singleShot(0, this, [this, id, program]() { emit finished(id, -1, {}, tr("Programma non installato: %1").arg(program)); });
        return id;
    }
    auto *p = new QProcess(this);
    m_procs.insert(id, p);
    p->setProgram(exe);
    p->setArguments(args);
    auto *outBuf = new QByteArray;
    if (streamLines) {
        connect(p, &QProcess::readyReadStandardOutput, this, [this, p, id, outBuf]() {
            outBuf->append(p->readAllStandardOutput());
            int nl;
            while ((nl = outBuf->indexOf('\n')) >= 0 || (nl = outBuf->indexOf('\r')) >= 0) {
                const QString l = QString::fromUtf8(outBuf->left(nl)).trimmed();
                outBuf->remove(0, nl + 1);
                if (!l.isEmpty()) emit line(id, l);
            }
        });
    }
    connect(p, &QProcess::finished, this, [this, p, id, outBuf, streamLines](int code, QProcess::ExitStatus st) {
        const QString out = streamLines ? QString::fromUtf8(*outBuf) : QString::fromUtf8(p->readAllStandardOutput());
        const QString err = QString::fromUtf8(p->readAllStandardError());
        delete outBuf;
        m_procs.remove(id);
        emit finished(id, st == QProcess::CrashExit ? -3 : code, out, err);
        p->deleteLater();
    });
    connect(p, &QProcess::errorOccurred, this, [this, p, id](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            m_procs.remove(id);
            emit finished(id, -1, {}, p->errorString());
            p->deleteLater();
        }
    });
    if (timeoutMs > 0) {
        QTimer::singleShot(timeoutMs, p, [p]() { if (p->state() != QProcess::NotRunning) p->kill(); });
    }
    p->start();
    return id;
}

void OmniSystem::cancel(int id) {
    if (auto p = m_procs.value(id)) {
        p->terminate();
        QTimer::singleShot(3000, p, [p]() { if (p->state() != QProcess::NotRunning) p->kill(); });
    }
}

bool OmniSystem::parseTyped(const QString &spec, QVariant *out) {
    const int c = spec.indexOf(':');
    if (c <= 0) return false;
    const QString t = spec.left(c), v = spec.mid(c + 1);
    bool ok = true;
    if (t == QLatin1String("s")) *out = v;
    else if (t == QLatin1String("o")) *out = QVariant::fromValue(QDBusObjectPath(v));
    else if (t == QLatin1String("b")) { if (v != QLatin1String("true") && v != QLatin1String("false")) return false; *out = v == QLatin1String("true"); }
    else if (t == QLatin1String("i")) *out = v.toInt(&ok);
    else if (t == QLatin1String("u")) *out = v.toUInt(&ok);
    else if (t == QLatin1String("x")) *out = v.toLongLong(&ok);
    else if (t == QLatin1String("t")) *out = v.toULongLong(&ok);
    else if (t == QLatin1String("d")) *out = v.toDouble(&ok);
    else if (t == QLatin1String("as")) *out = v.isEmpty() ? QStringList() : v.split(',');
    else if (t == QLatin1String("v")) { QVariant inner; if (!parseTyped(v, &inner)) return false; *out = QVariant::fromValue(QDBusVariant(inner)); }
    else return false;
    return ok;
}

namespace {
QVariant plain(const QVariant &v);
QVariant plainArg(const QDBusArgument &a) {
    switch (a.currentType()) {
    case QDBusArgument::BasicType: case QDBusArgument::VariantType: { QVariant x = a.asVariant(); return plain(x); }
    case QDBusArgument::ArrayType: {
        QVariantList l; a.beginArray();
        while (!a.atEnd()) { QVariant x = a.asVariant(); l << plain(x); }
        a.endArray(); return l;
    }
    case QDBusArgument::StructureType: {
        QVariantList l; a.beginStructure();
        while (!a.atEnd()) { QVariant x = a.asVariant(); l << plain(x); }
        a.endStructure(); return l;
    }
    case QDBusArgument::MapType: {
        QVariantMap m; a.beginMap();
        while (!a.atEnd()) { a.beginMapEntry(); QVariant k = a.asVariant(), v = a.asVariant(); a.endMapEntry(); m.insert(plain(k).toString(), plain(v)); }
        a.endMap(); return m;
    }
    default: return {};
    }
}
QVariant plain(const QVariant &v) {
    if (v.canConvert<QDBusVariant>() && v.userType() == qMetaTypeId<QDBusVariant>()) return plain(v.value<QDBusVariant>().variant());
    if (v.userType() == qMetaTypeId<QDBusArgument>()) return plainArg(v.value<QDBusArgument>());
    if (v.userType() == qMetaTypeId<QDBusObjectPath>()) return v.value<QDBusObjectPath>().path();
    return v;
}
}

int OmniSystem::dbus(const QString &bus, const QString &service, const QString &path, const QString &iface,
                     const QString &method, const QStringList &typedArgs, bool interactive, int timeoutMs) {
    const int id = m_next++;
    auto msg = QDBusMessage::createMethodCall(service, path, iface, method);
    for (const QString &a : typedArgs) {
        QVariant v;
        if (!parseTyped(a, &v)) {
            QTimer::singleShot(0, this, [this, id, a]() { emit dbusFinished(id, false, {}, tr("Argomento non valido: %1").arg(a)); });
            return id;
        }
        msg << v;
    }
    msg.setInteractiveAuthorizationAllowed(interactive);
    auto conn = bus == QLatin1String("system") ? QDBusConnection::systemBus() : QDBusConnection::sessionBus();
    auto *w = new QDBusPendingCallWatcher(conn.asyncCall(msg, timeoutMs), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w, id]() {
        const QDBusMessage r = w->reply();
        if (r.type() == QDBusMessage::ErrorMessage) emit dbusFinished(id, false, {}, r.errorMessage());
        else {
            QVariantList out;
            for (const QVariant &a : r.arguments()) out << plain(a);
            emit dbusFinished(id, true, out.size() == 1 ? out.first() : QVariant(out), {});
        }
        w->deleteLater();
    });
    return id;
}

int OmniSystem::dbusGet(const QString &bus, const QString &service, const QString &path, const QString &iface, const QString &prop) {
    return dbus(bus, service, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"),
                {QStringLiteral("s:") + iface, QStringLiteral("s:") + prop});
}

QString OmniSystem::readFile(const QString &path, int maxBytes) const {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    return QString::fromUtf8(f.read(maxBytes));
}

QString OmniSystem::homePath() const { return QDir::homePath(); }
QString OmniSystem::env(const QString &name) const { return qEnvironmentVariable(name.toUtf8().constData()); }

static QString autostartDir() { return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/autostart"); }

static QHash<QString, QString> readDesktop(const QString &path) {
    QHash<QString, QString> kv;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return kv;
    bool main = false;
    while (!f.atEnd()) {
        const QString l = QString::fromUtf8(f.readLine()).trimmed();
        if (l.startsWith(QLatin1Char('['))) { main = l == QLatin1String("[Desktop Entry]"); continue; }
        const int eq = l.indexOf(QLatin1Char('='));
        if (main && eq > 0) kv.insert(l.left(eq).trimmed(), l.mid(eq + 1).trimmed());
    }
    return kv;
}

QVariantList OmniSystem::autostartEntries() const {
    QMap<QString, QVariantMap> out;   // per id; la voce dell'utente prevale su quella di sistema
    const QStringList dirs = {QStringLiteral("/etc/xdg/autostart"), autostartDir()};
    for (const QString &d : dirs) {
        for (const QFileInfo &fi : QDir(d).entryInfoList({QStringLiteral("*.desktop")}, QDir::Files)) {
            const auto kv = readDesktop(fi.absoluteFilePath());
            const QString only = kv.value(QStringLiteral("OnlyShowIn")), notIn = kv.value(QStringLiteral("NotShowIn"));
            if ((!only.isEmpty() && !only.contains(QLatin1String("KDE"))) || notIn.contains(QLatin1String("KDE"))) continue;
            QVariantMap e = out.value(fi.fileName());
            e[QStringLiteral("id")] = fi.fileName();
            if (kv.contains(QStringLiteral("Name"))) e[QStringLiteral("name")] = kv.value(QStringLiteral("Name"));
            if (kv.contains(QStringLiteral("Comment"))) e[QStringLiteral("comment")] = kv.value(QStringLiteral("Comment"));
            e[QStringLiteral("enabled")] = kv.value(QStringLiteral("Hidden")) != QLatin1String("true")
                                         && kv.value(QStringLiteral("X-GNOME-Autostart-enabled")) != QLatin1String("false");
            e[QStringLiteral("user")] = d == autostartDir();
            out.insert(fi.fileName(), e);
        }
    }
    QVariantList l;
    for (const auto &e : out) l << e;
    return l;
}

bool OmniSystem::setAutostart(const QString &desktopId, bool enabled) {
    if (desktopId.contains(QLatin1Char('/')) || !desktopId.endsWith(QLatin1String(".desktop"))) return false;
    QDir().mkpath(autostartDir());
    const QString userFile = autostartDir() + QLatin1Char('/') + desktopId;
    const QString sysFile = QStringLiteral("/etc/xdg/autostart/") + desktopId;
    if (enabled) {
        // se la voce di sistema esiste, basta togliere la propria copia che la nasconde
        if (QFileInfo::exists(sysFile)) return !QFileInfo::exists(userFile) || QFile::remove(userFile);
        auto kv = readDesktop(userFile);
        if (kv.isEmpty()) return false;
        QFile f(userFile);
        QString text = QString::fromUtf8([&] { QFile r(userFile); r.open(QIODevice::ReadOnly); return r.readAll(); }());
        text.remove(QStringLiteral("Hidden=true\n"));
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
        f.write(text.toUtf8());
        return true;
    }
    QString text;
    if (QFileInfo::exists(userFile)) { QFile r(userFile); r.open(QIODevice::ReadOnly); text = QString::fromUtf8(r.readAll()); }
    else if (QFileInfo::exists(sysFile)) { QFile r(sysFile); r.open(QIODevice::ReadOnly); text = QString::fromUtf8(r.readAll()); }
    else return false;
    if (!text.contains(QStringLiteral("Hidden=true"))) {
        const int i = text.indexOf(QStringLiteral("[Desktop Entry]"));
        if (i < 0) return false;
        text.insert(i + 15, QStringLiteral("\nHidden=true"));
    }
    QFile f(userFile);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    f.write(text.toUtf8());
    return true;
}

void OmniSystem::reloadKeyboardConfig() {
    auto sig = QDBusMessage::createSignal(QStringLiteral("/Layouts"), QStringLiteral("org.kde.keyboard"), QStringLiteral("reloadConfig"));
    QDBusConnection::sessionBus().send(sig);
}

QString OmniSystem::resetShellPreferences(const QString &file) {
    const QString expected = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/omni-os/omni-shell.conf");
    if (QFileInfo(file).absoluteFilePath() != expected || !QFileInfo::exists(file)) return {};
    const QString keep = file + QStringLiteral(".precedente-") + QString::number(QDateTime::currentSecsSinceEpoch());
    return QFile::rename(file, keep) ? keep : QString();
}

QStringList OmniSystem::userDirs() const {
    QStringList l;
    for (auto t : {QStandardPaths::DesktopLocation, QStandardPaths::DocumentsLocation, QStandardPaths::DownloadLocation,
                   QStandardPaths::PicturesLocation, QStandardPaths::MusicLocation, QStandardPaths::MoviesLocation}) {
        const QString p = QStandardPaths::writableLocation(t);
        if (!p.isEmpty() && p != QDir::homePath() && !l.contains(p)) l << p;
    }
    return l;
}

bool OmniSystem::exists(const QString &path) const { return QFileInfo::exists(path); }

QStringList OmniSystem::listFiles(const QString &dir, const QStringList &suffixes, bool recursive, int max) const {
    QStringList out;
    QDirIterator it(dir, QDir::Files | QDir::Readable, recursive ? QDirIterator::Subdirectories : QDirIterator::NoIteratorFlags);
    while (it.hasNext() && out.size() < max) {
        const QString f = it.next();
        for (const QString &sfx : suffixes) if (f.endsWith(sfx, Qt::CaseInsensitive)) { out << f; break; }
    }
    out.sort();
    return out;
}
