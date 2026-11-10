#include "applauncher.h"
#include "desktopentries.h"
#include <QDateTime>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>

AppLauncher::AppLauncher(DesktopEntryModel *model, bool enabled, QObject *parent)
    : QObject(parent), m_model(model), m_enabled(enabled) {}

QList<QStringList> AppLauncher::commandsFor(const QString &path) const {
    const QString override = qEnvironmentVariable("OMNI_LAUNCH_CMD");
    if (!override.isEmpty()) return {override.split(' ', Qt::SkipEmptyParts) << path};
    const QString id = QFileInfo(path).completeBaseName();
    return {{QStringLiteral("gio"), QStringLiteral("launch"), path},
            {QStringLiteral("kstart"), QStringLiteral("--application"), id}};
}

bool AppLauncher::launch(const QString &path) {
    if (!m_enabled) { emit launched(path, false, QStringLiteral("avvio reale disattivato")); return false; }
    if (!m_model || !m_model->containsPath(path)) {
        qWarning("avvio rifiutato: %s non è una voce .desktop letta dal sistema", qPrintable(path));
        emit launched(path, false, QStringLiteral("voce non riconosciuta"));
        return false;
    }
    for (const QStringList &cmd : commandsFor(path)) {
        if (QStandardPaths::findExecutable(cmd.first()).isEmpty()) continue;
        qint64 pid = 0;
        if (QProcess::startDetached(cmd.first(), cmd.mid(1), QString(), &pid)) {
            qInfo("avvio reale: %s (%s, pid %lld, t=%lld)", qPrintable(path), qPrintable(cmd.first()), pid, QDateTime::currentMSecsSinceEpoch());
            emit launched(path, true, cmd.first());
            return true;
        }
    }
    qWarning("avvio fallito: %s", qPrintable(path));
    emit launched(path, false, QStringLiteral("nessun comando di avvio disponibile"));
    return false;
}
