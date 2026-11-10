#pragma once
#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QHash>
#include <QTimer>
#include <QVariantList>

// Dati REALI per OMNI Task Manager, letti da /proc e /sys a ogni campionamento (1 s quando la
// finestra è visibile, fermo quando è nascosta): CPU totale e per core, memoria, disco, rete,
// processi con consumo per processo. La GPU viene descritta solo con ciò che il sistema
// espone davvero (driver, e carico solo se il driver lo pubblica): nessun dato inventato.
struct ProcInfo {
    int pid = 0, ppid = 0;
    uint uid = 0;
    QString name, cmd, user;
    char state = '?';
    bool kernel = false;
    qulonglong ticks = 0, rssKb = 0, readBytes = 0;
    double cpu = 0;
};

class SystemMonitor : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY sortKeyChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY sortKeyChanged)
    Q_PROPERTY(bool onlyMine READ onlyMine WRITE setOnlyMine NOTIFY sortKeyChanged)
    Q_PROPERTY(bool showKernel READ showKernel WRITE setShowKernel NOTIFY sortKeyChanged)
    Q_PROPERTY(double cpu READ cpu NOTIFY sampled)
    Q_PROPERTY(QVariantList cpuCores READ cpuCores NOTIFY sampled)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY sampled)
    Q_PROPERTY(QVariantList memHistory READ memHistory NOTIFY sampled)
    Q_PROPERTY(QVariantList diskHistory READ diskHistory NOTIFY sampled)
    Q_PROPERTY(QVariantList netHistory READ netHistory NOTIFY sampled)
    Q_PROPERTY(double memUsedMb READ memUsedMb NOTIFY sampled)
    Q_PROPERTY(double memTotalMb READ memTotalMb NOTIFY sampled)
    Q_PROPERTY(double swapUsedMb READ swapUsedMb NOTIFY sampled)
    Q_PROPERTY(double swapTotalMb READ swapTotalMb NOTIFY sampled)
    Q_PROPERTY(double diskReadKBs READ diskReadKBs NOTIFY sampled)
    Q_PROPERTY(double diskWriteKBs READ diskWriteKBs NOTIFY sampled)
    Q_PROPERTY(double netRxKBs READ netRxKBs NOTIFY sampled)
    Q_PROPERTY(double netTxKBs READ netTxKBs NOTIFY sampled)
    Q_PROPERTY(qulonglong uptimeSec READ uptimeSec NOTIFY sampled)
    Q_PROPERTY(int processCount READ processCount NOTIFY sampled)
    Q_PROPERTY(QVariantMap hardware READ hardware CONSTANT)
    Q_PROPERTY(QVariantMap gpu READ gpu NOTIFY sampled)
public:
    enum Roles { PidRole = Qt::UserRole + 1, NameRole, UserRole, CpuRole, MemRole, CmdRole, StateRole, MineRole };
    explicit SystemMonitor(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool active() const { return m_timer.isActive(); }
    void setActive(bool on);
    QString sortKey() const { return m_sort; }
    void setSortKey(const QString &k);
    QString filter() const { return m_filter; }
    void setFilter(const QString &f);
    bool onlyMine() const { return m_onlyMine; }
    void setOnlyMine(bool v);
    bool showKernel() const { return m_showKernel; }
    void setShowKernel(bool v);
    double cpu() const { return m_cpu; }
    QVariantList cpuCores() const { return m_cores; }
    QVariantList cpuHistory() const { return m_cpuHist; }
    QVariantList memHistory() const { return m_memHist; }
    QVariantList diskHistory() const { return m_diskHist; }
    QVariantList netHistory() const { return m_netHist; }
    double memUsedMb() const { return m_memUsed; }
    double memTotalMb() const { return m_memTotal; }
    double swapUsedMb() const { return m_swapUsed; }
    double swapTotalMb() const { return m_swapTotal; }
    double diskReadKBs() const { return m_dr; }
    double diskWriteKBs() const { return m_dw; }
    double netRxKBs() const { return m_rx; }
    double netTxKBs() const { return m_tx; }
    qulonglong uptimeSec() const { return m_uptime; }
    int processCount() const { return m_all.size(); }
    QVariantMap hardware() const { return m_hw; }
    QVariantMap gpu() const { return m_gpu; }

    Q_INVOKABLE void sample();
    // termina un processo dell'utente (SIGTERM; force = SIGKILL). Messaggio d'errore o stringa vuota.
    Q_INVOKABLE QString terminate(int pid, bool force = false);
    Q_INVOKABLE QVariantMap processDetails(int pid) const;

signals:
    void activeChanged();
    void sortKeyChanged();
    void sampled();

private:
    void readCpu();
    void readMem();
    void readDisk(double secs);
    void readNet(double secs);
    void readProcs(double secs);
    void readGpu();
    void rebuildView();
    static void push(QVariantList &h, double v);

    QTimer m_timer;
    QElapsedTimer m_clock;
    qint64 m_lastMs = 0;
    QString m_sort = QStringLiteral("cpu"), m_filter;
    bool m_onlyMine = false, m_showKernel = false;
    uint m_uid = 0;
    // CPU
    QVector<qulonglong> m_prevTotal, m_prevIdle;
    double m_cpu = 0;
    QVariantList m_cores, m_cpuHist, m_memHist, m_diskHist, m_netHist;
    double m_memUsed = 0, m_memTotal = 0, m_swapUsed = 0, m_swapTotal = 0;
    qulonglong m_prevSectR = 0, m_prevSectW = 0, m_prevRx = 0, m_prevTx = 0;
    double m_dr = 0, m_dw = 0, m_rx = 0, m_tx = 0;
    qulonglong m_uptime = 0, m_prevCpuTotalTicks = 0;
    QHash<int, ProcInfo> m_all;
    QHash<uint, QString> m_users;
    QVector<ProcInfo> m_view;
    QVariantMap m_hw, m_gpu;
};
