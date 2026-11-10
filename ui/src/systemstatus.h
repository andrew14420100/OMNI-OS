#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

// Stato REALE del sistema per le Impostazioni rapide e la pagina "Sistema" di OMNI Shell.
// Ogni valore viene letto dal servizio responsabile; le modifiche sono confermate solo
// dopo aver riletto lo stato effettivo (nessun esito simulato).
//  - schermo: KScreen (kscreen-doctor), risoluzione, frequenza, scala
//  - profilo energetico: power-profiles-daemon / tuned-ppd (D-Bus)
//  - luminosità: PowerDevil (org.kde.ScreenBrightness), se lo schermo la supporta
//  - batteria: UPower (solo se presente)
//  - archiviazione: spazio della cartella personale
//  - sicurezza: SELinux, Secure Boot, firewalld (sola lettura)
class SystemStatus : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList outputs READ outputs NOTIFY displayChanged)
    Q_PROPERTY(QString displayStatus READ displayStatus NOTIFY displayChanged)
    Q_PROPERTY(QString powerProfile READ powerProfile NOTIFY powerChanged)
    Q_PROPERTY(QStringList powerProfiles READ powerProfiles NOTIFY powerChanged)
    Q_PROPERTY(bool brightnessAvailable READ brightnessAvailable NOTIFY brightnessChanged)
    Q_PROPERTY(int brightness READ brightness NOTIFY brightnessChanged)
    Q_PROPERTY(int maxBrightness READ maxBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(QString brightnessNote READ brightnessNote NOTIFY brightnessChanged)
    Q_PROPERTY(bool batteryPresent READ batteryPresent NOTIFY batteryChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY batteryChanged)
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY batteryChanged)
    Q_PROPERTY(QVariantMap storage READ storage NOTIFY storageChanged)
    Q_PROPERTY(QVariantMap security READ security NOTIFY securityChanged)
    // rete (NetworkManager): stato reale della connessione principale
    Q_PROPERTY(bool networkConnected READ networkConnected NOTIFY networkChanged)
    Q_PROPERTY(QString networkType READ networkType NOTIFY networkChanged)
    Q_PROPERTY(QString networkName READ networkName NOTIFY networkChanged)
    Q_PROPERTY(bool networkAvailable READ networkAvailable NOTIFY networkChanged)
public:
    explicit SystemStatus(QObject *parent = nullptr);

    QVariantList outputs() const { return m_outputs; }
    QString displayStatus() const { return m_displayStatus; }
    QString powerProfile() const { return m_profile; }
    QStringList powerProfiles() const { return m_profiles; }
    bool brightnessAvailable() const { return !m_brightnessPath.isEmpty(); }
    int brightness() const { return m_brightness; }
    int maxBrightness() const { return m_maxBrightness; }
    QString brightnessNote() const { return m_brightnessNote; }
    bool batteryPresent() const { return m_batteryPresent; }
    int batteryPercent() const { return m_batteryPercent; }
    bool batteryCharging() const { return m_batteryCharging; }
    QVariantMap storage() const { return m_storage; }
    QVariantMap security() const { return m_security; }

    bool networkConnected() const { return m_netConnected; }
    QString networkType() const { return m_netType; }
    QString networkName() const { return m_netName; }
    bool networkAvailable() const { return m_netAvailable; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshNetwork();
    Q_INVOKABLE void refreshDisplay();
    // Applica modo e scala; displayApplied(ok, messaggio) dopo aver riletto lo stato effettivo.
    Q_INVOKABLE void applyDisplay(const QString &output, const QString &mode, double scale);
    Q_INVOKABLE void setPowerProfile(const QString &profile);
    Q_INVOKABLE void setBrightness(int value);
    // apre un modulo delle Impostazioni di sistema di KDE (es. "kcm_kscreen")
    Q_INVOKABLE bool openSettings(const QString &module = QString());
    // app OMNI (stesso eseguibile): impostazioni, attivita, explorer, store; pagina facoltativa
    Q_INVOKABLE bool openOmniApp(const QString &app, const QString &page = QString());

signals:
    void displayChanged();
    void displayApplied(bool ok, const QString &message);
    void powerChanged();
    void brightnessChanged();
    void batteryChanged();
    void storageChanged();
    void securityChanged();
    void failed(const QString &what, const QString &reason);
    void networkChanged();

private slots:
    void onNmPropertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated);
private:
    void readPowerProfiles();
    void readBrightness();
    void readBattery();
    void readStorage();
    void readSecurity();
    QVariantList m_outputs;
    QString m_displayStatus, m_profile, m_profileService, m_profilePath, m_brightnessPath, m_brightnessNote;
    QStringList m_profiles;
    int m_brightness = 0, m_maxBrightness = 0, m_batteryPercent = 0;
    bool m_batteryPresent = false, m_batteryCharging = false;
    QVariantMap m_storage, m_security;
    bool m_netConnected = false, m_netAvailable = false, m_nmWatching = false;
    QString m_netType, m_netName;
};
