#include "systemmonitor.h"
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <algorithm>
#include <cerrno>
#include <cstring>
#include <pwd.h>
#include <signal.h>
#include <unistd.h>

namespace {
QByteArray slurp(const QString &path, qint64 max = 1 << 16) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    return f.read(max);
}
constexpr int HIST = 60;
}

SystemMonitor::SystemMonitor(QObject *parent) : QAbstractListModel(parent) {
    m_uid = getuid();
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &SystemMonitor::sample);
    m_clock.start();
    // hardware (una volta)
    const QString cpuinfo = QString::fromUtf8(slurp(QStringLiteral("/proc/cpuinfo"), 1 << 20));
    const auto m = QRegularExpression(QStringLiteral("model name\\s*:\\s*(.*)")).match(cpuinfo);
    m_hw[QStringLiteral("cpuModel")] = m.hasMatch() ? m.captured(1).trimmed() : QStringLiteral("?");
    m_hw[QStringLiteral("cpuCount")] = int(sysconf(_SC_NPROCESSORS_ONLN));
    const QString vendor = QString::fromUtf8(slurp(QStringLiteral("/sys/class/dmi/id/sys_vendor"))).trimmed();
    const QString product = QString::fromUtf8(slurp(QStringLiteral("/sys/class/dmi/id/product_name"))).trimmed();
    m_hw[QStringLiteral("machine")] = (vendor + QLatin1Char(' ') + product).trimmed();
    m_hw[QStringLiteral("virtual")] = QRegularExpression(QStringLiteral("QEMU|VirtualBox|VMware|innotek|KVM"), QRegularExpression::CaseInsensitiveOption).match(vendor + product).hasMatch();
    readGpu();
    sample();
}

void SystemMonitor::setActive(bool on) {
    if (on == m_timer.isActive()) return;
    if (on) { sample(); m_timer.start(); } else m_timer.stop();
    emit activeChanged();
}

void SystemMonitor::setSortKey(const QString &k) { if (k == m_sort) return; m_sort = k; rebuildView(); emit sortKeyChanged(); }
void SystemMonitor::setFilter(const QString &f) { if (f == m_filter) return; m_filter = f; rebuildView(); emit sortKeyChanged(); }
void SystemMonitor::setShowKernel(bool v) { if (v == m_showKernel) return; m_showKernel = v; rebuildView(); emit sortKeyChanged(); }
void SystemMonitor::setOnlyMine(bool v) { if (v == m_onlyMine) return; m_onlyMine = v; rebuildView(); emit sortKeyChanged(); }

void SystemMonitor::push(QVariantList &h, double v) {
    h.append(v);
    while (h.size() > HIST) h.removeFirst();
}

void SystemMonitor::sample() {
    const qint64 now = m_clock.elapsed();
    const double secs = m_lastMs ? qMax(0.05, (now - m_lastMs) / 1000.0) : 1.0;
    const bool first = m_lastMs == 0;
    m_lastMs = now;
    readCpu();
    readMem();
    readDisk(secs);
    readNet(secs);
    readProcs(secs);
    m_uptime = qulonglong(QString::fromUtf8(slurp(QStringLiteral("/proc/uptime"))).section(QLatin1Char(' '), 0, 0).toDouble());
    if (!first) {
        push(m_cpuHist, m_cpu);
        push(m_memHist, m_memTotal > 0 ? 100.0 * m_memUsed / m_memTotal : 0);
        push(m_diskHist, m_dr + m_dw);
        push(m_netHist, m_rx + m_tx);
    }
    readGpu();
    emit sampled();
}

void SystemMonitor::readCpu() {
    const QList<QByteArray> lines = slurp(QStringLiteral("/proc/stat")).split('\n');
    QVector<qulonglong> tot, idle;
    for (const QByteArray &l : lines) {
        if (!l.startsWith("cpu")) break;
        const QList<QByteArray> f = l.simplified().split(' ');
        qulonglong t = 0;
        for (int i = 1; i < f.size(); ++i) t += f.at(i).toULongLong();
        tot << t;
        idle << (f.value(4).toULongLong() + f.value(5).toULongLong());   // idle + iowait
    }
    if (m_prevTotal.size() == tot.size()) {
        m_cores.clear();
        for (int i = 0; i < tot.size(); ++i) {
            const double dt = double(tot[i] - m_prevTotal[i]), di = double(idle[i] - m_prevIdle[i]);
            const double u = dt > 0 ? qBound(0.0, 100.0 * (1.0 - di / dt), 100.0) : 0;
            if (i == 0) m_cpu = u; else m_cores << u;
        }
    }
    m_prevCpuTotalTicks = tot.isEmpty() ? 0 : tot.first();
    m_prevTotal = tot;
    m_prevIdle = idle;
}

void SystemMonitor::readMem() {
    QHash<QByteArray, double> v;
    for (const QByteArray &l : slurp(QStringLiteral("/proc/meminfo")).split('\n')) {
        const int c = l.indexOf(':');
        if (c > 0) v.insert(l.left(c), l.mid(c + 1).simplified().split(' ').value(0).toDouble() / 1024.0);
    }
    m_memTotal = v.value("MemTotal");
    m_memUsed = m_memTotal - v.value("MemAvailable");
    m_swapTotal = v.value("SwapTotal");
    m_swapUsed = m_swapTotal - v.value("SwapFree");
}

void SystemMonitor::readDisk(double secs) {
    qulonglong r = 0, w = 0;
    static const QRegularExpression skip(QStringLiteral("^(loop|ram|zram|dm-|sr|md)"));
    static const QRegularExpression part(QStringLiteral("^(sd[a-z]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+)\\d+$|^nvme\\d+n\\d+p\\d+$|^mmcblk\\d+p\\d+$"));
    for (const QByteArray &l : slurp(QStringLiteral("/proc/diskstats")).split('\n')) {
        const QList<QByteArray> f = l.simplified().split(' ');
        if (f.size() < 10) continue;
        const QString dev = QString::fromLatin1(f.at(2));
        if (skip.match(dev).hasMatch() || part.match(dev).hasMatch()) continue;   // solo dischi interi
        r += f.at(5).toULongLong();
        w += f.at(9).toULongLong();
    }
    if (m_prevSectR || m_prevSectW) {
        m_dr = (r - m_prevSectR) * 512.0 / 1024.0 / secs;
        m_dw = (w - m_prevSectW) * 512.0 / 1024.0 / secs;
    }
    m_prevSectR = r;
    m_prevSectW = w;
}

void SystemMonitor::readNet(double secs) {
    qulonglong rx = 0, tx = 0;
    for (const QByteArray &l : slurp(QStringLiteral("/proc/net/dev")).split('\n')) {
        const int c = l.indexOf(':');
        if (c < 0) continue;
        const QByteArray name = l.left(c).trimmed();
        if (name == "lo") continue;
        const QList<QByteArray> f = l.mid(c + 1).simplified().split(' ');
        rx += f.value(0).toULongLong();
        tx += f.value(8).toULongLong();
    }
    if (m_prevRx || m_prevTx) { m_rx = (rx - m_prevRx) / 1024.0 / secs; m_tx = (tx - m_prevTx) / 1024.0 / secs; }
    m_prevRx = rx;
    m_prevTx = tx;
}

void SystemMonitor::readProcs(double secs) {
    const long hz = sysconf(_SC_CLK_TCK);
    const long page = sysconf(_SC_PAGESIZE) / 1024;
    const int ncpu = qMax(1, int(sysconf(_SC_NPROCESSORS_ONLN)));
    QHash<int, ProcInfo> next;
    const QStringList pids = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &ps : pids) {
        bool ok = false;
        const int pid = ps.toInt(&ok);
        if (!ok) continue;
        const QByteArray stat = slurp(QStringLiteral("/proc/%1/stat").arg(pid), 4096);
        const int lp = stat.indexOf('('), rp = stat.lastIndexOf(')');
        if (lp < 0 || rp < 0) continue;
        ProcInfo p;
        p.pid = pid;
        p.name = QString::fromUtf8(stat.mid(lp + 1, rp - lp - 1));
        const QList<QByteArray> f = stat.mid(rp + 2).split(' ');
        if (f.size() < 22) continue;
        p.state = f.at(0).isEmpty() ? '?' : f.at(0).at(0);
        p.ppid = f.at(1).toInt();
        p.ticks = f.at(11).toULongLong() + f.at(12).toULongLong();
        p.rssKb = f.at(21).toULongLong() * page;
        const QByteArray status = slurp(QStringLiteral("/proc/%1/status").arg(pid), 4096);
        const int u = status.indexOf("Uid:");
        p.uid = u >= 0 ? status.mid(u + 4, 32).simplified().split(' ').value(0).toUInt() : 0;
        if (!m_users.contains(p.uid)) {
            const passwd *pw = getpwuid(p.uid);
            m_users.insert(p.uid, pw ? QString::fromLocal8Bit(pw->pw_name) : QString::number(p.uid));
        }
        p.user = m_users.value(p.uid);
        const auto prev = m_all.constFind(pid);
        if (prev != m_all.constEnd() && prev->name == p.name) {
            p.cmd = prev->cmd;
            p.cpu = qBound(0.0, 100.0 * double(p.ticks - prev->ticks) / double(hz) / secs / ncpu, 100.0);
        } else {
            QByteArray cmd = slurp(QStringLiteral("/proc/%1/cmdline").arg(pid), 2048);
            cmd.replace('\0', ' ');
            p.cmd = QString::fromUtf8(cmd).trimmed();
        }
        // il nome in /proc/<pid>/stat è troncato a 15 caratteri: si usa quello dell'eseguibile
        if (p.name.size() == 15 && !p.cmd.isEmpty()) {
            const QString exe = p.cmd.section(QLatin1Char(' '), 0, 0).section(QLatin1Char('/'), -1);
            if (exe.startsWith(p.name)) p.name = exe;
        }
        p.kernel = p.cmd.isEmpty() && (p.ppid == 2 || pid == 2);
        next.insert(pid, p);
    }
    m_all = next;
    rebuildView();
}

void SystemMonitor::rebuildView() {
    QVector<ProcInfo> v;
    v.reserve(m_all.size());
    const QString f = m_filter.trimmed().toLower();
    for (const ProcInfo &p : m_all) {
        if (m_onlyMine && p.uid != m_uid) continue;
        if (p.kernel && !m_showKernel) continue;   // thread del kernel: nascosti salvo richiesta
        if (!f.isEmpty() && !p.name.toLower().contains(f) && !p.cmd.toLower().contains(f) && QString::number(p.pid) != f) continue;
        v << p;
    }
    if (m_sort == QLatin1String("mem")) std::sort(v.begin(), v.end(), [](const ProcInfo &a, const ProcInfo &b) { return a.rssKb > b.rssKb; });
    else if (m_sort == QLatin1String("name")) std::sort(v.begin(), v.end(), [](const ProcInfo &a, const ProcInfo &b) { return a.name.compare(b.name, Qt::CaseInsensitive) < 0; });
    else if (m_sort == QLatin1String("pid")) std::sort(v.begin(), v.end(), [](const ProcInfo &a, const ProcInfo &b) { return a.pid < b.pid; });
    else std::sort(v.begin(), v.end(), [](const ProcInfo &a, const ProcInfo &b) { return a.cpu != b.cpu ? a.cpu > b.cpu : a.rssKb > b.rssKb; });
    // aggiornamento senza ricostruire le righe quando il numero non cambia (scorrimento stabile)
    if (v.size() == m_view.size()) {
        m_view = v;
        if (!m_view.isEmpty()) emit dataChanged(index(0), index(m_view.size() - 1));
    } else {
        beginResetModel();
        m_view = v;
        endResetModel();
    }
}

void SystemMonitor::readGpu() {
    QVariantMap g;
    for (int i = 0; i < 4; ++i) {
        const QString base = QStringLiteral("/sys/class/drm/card%1/device/").arg(i);
        const QString uevent = QString::fromUtf8(slurp(base + QStringLiteral("uevent")));
        if (uevent.isEmpty()) continue;
        const auto d = QRegularExpression(QStringLiteral("DRIVER=(\\S+)")).match(uevent);
        g[QStringLiteral("driver")] = d.hasMatch() ? d.captured(1) : QString();
        g[QStringLiteral("vendorId")] = QString::fromUtf8(slurp(base + QStringLiteral("vendor"))).trimmed();
        g[QStringLiteral("deviceId")] = QString::fromUtf8(slurp(base + QStringLiteral("device"))).trimmed();
        const QByteArray busy = slurp(base + QStringLiteral("gpu_busy_percent"));   // amdgpu e altri driver reali
        if (!busy.isEmpty()) g[QStringLiteral("busy")] = busy.trimmed().toInt();
        const QString drv = g.value(QStringLiteral("driver")).toString();
        g[QStringLiteral("virtual")] = drv == QLatin1String("vmwgfx") || drv.startsWith(QLatin1String("virtio")) || drv == QLatin1String("vboxvideo") || drv == QLatin1String("qxl") || drv == QLatin1String("bochs-drm");
        break;
    }
    m_gpu = g;
}

int SystemMonitor::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_view.size(); }

QVariant SystemMonitor::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_view.size()) return {};
    const ProcInfo &p = m_view.at(index.row());
    switch (role) {
    case PidRole: return p.pid;
    case NameRole: return p.name;
    case UserRole: return p.user;
    case CpuRole: return p.cpu;
    case MemRole: return double(p.rssKb) / 1024.0;
    case CmdRole: return p.cmd;
    case StateRole: return QString(QChar(p.state));
    case MineRole: return p.uid == m_uid;
    }
    return {};
}

QHash<int, QByteArray> SystemMonitor::roleNames() const {
    return {{PidRole, "pid"}, {NameRole, "name"}, {UserRole, "user"}, {CpuRole, "cpu"}, {MemRole, "memMb"},
            {CmdRole, "cmd"}, {StateRole, "procState"}, {MineRole, "mine"}};
}

QString SystemMonitor::terminate(int pid, bool force) {
    const auto it = m_all.constFind(pid);
    if (it == m_all.constEnd()) return tr("Processo non più in esecuzione");
    if (it->uid != m_uid) return tr("Il processo appartiene a un altro utente (%1): serve l'amministratore").arg(it->user);
    if (pid == getpid()) return tr("Non si può terminare Gestione attività da se stessa");
    if (::kill(pid, force ? SIGKILL : SIGTERM) != 0) return QString::fromLocal8Bit(strerror(errno));
    qInfo("gestione attività: %s al processo %d (%s)", force ? "SIGKILL" : "SIGTERM", pid, qPrintable(it->name));
    return {};
}

QVariantMap SystemMonitor::processDetails(int pid) const {
    const auto it = m_all.constFind(pid);
    if (it == m_all.constEnd()) return {};
    return {{"pid", it->pid}, {"ppid", it->ppid}, {"name", it->name}, {"user", it->user}, {"cmd", it->cmd},
            {"cpu", it->cpu}, {"memMb", double(it->rssKb) / 1024.0}, {"state", QString(QChar(it->state))}};
}
