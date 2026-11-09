#pragma once
#include <QObject>
#include <QStringList>

class DesktopEntryModel;

// Avvio REALE delle applicazioni (solo con --real-launch, mai con l'elenco dimostrativo).
// Sicurezza:
//  - si avviano solo file .desktop letti dal modello (cartelle XDG), mai percorsi arbitrari;
//  - nessuna shell: l'avvio è delegato a "gio launch <file.desktop>" (o "kstart
//    --application <id>"), che interpretano Exec secondo la specifica freedesktop;
//  - stessi privilegi dell'utente che esegue OMNI Shell.
class AppLauncher : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled CONSTANT)
public:
    AppLauncher(DesktopEntryModel *model, bool enabled, QObject *parent = nullptr);
    bool enabled() const { return m_enabled; }
    // Avvia l'applicazione descritta dal file .desktop. Ritorna false se non consentito o fallito.
    Q_INVOKABLE bool launch(const QString &desktopFilePath);
    // Comandi provati, in ordine (sostituibili nei test con OMNI_LAUNCH_CMD="programma arg...").
    QList<QStringList> commandsFor(const QString &desktopFilePath) const;
signals:
    void launched(const QString &desktopFilePath, bool ok, const QString &detail);
private:
    DesktopEntryModel *m_model;
    bool m_enabled;
};
