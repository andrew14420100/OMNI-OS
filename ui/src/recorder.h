#pragma once
#include <QAnimationDriver>
#include <QEvent>
#include <QJsonArray>
#include <QObject>
#include <QPointF>
#include <QProcess>
#include <QString>

class QQuickWindow;
class QQuickItem;

// Driver di animazione a passo fisso: il tempo delle animazioni avanza di un
// fotogramma alla volta, quindi il video è fedele anche se la cattura è lenta.
class StepAnimationDriver : public QAnimationDriver {
public:
    qint64 elapsed() const override { return m_t; }
    void step(qint64 ms) { m_t += ms; advance(); }
private:
    qint64 m_t = 0;
};

// Registratore di interazioni REALI con il prototipo: legge uno script JSON di azioni
// (spostamenti, clic, tasti, testo, trascinamenti), invia alla finestra veri eventi di
// input Qt, cattura ogni fotogramma con grabWindow e lo passa a ffmpeg.
// Il puntatore e la didascalia sono disegnati dal registratore sopra il fotogramma.
class Recorder : public QObject {
    Q_OBJECT
public:
    Recorder(QQuickWindow *w, const QJsonArray &script, const QString &out, int fps, QObject *parent = nullptr);
    bool start();
signals:
    void done(bool ok);
private:
    void tick();
    void apply(const QJsonObject &a);
    QQuickItem *find(QQuickItem *root, const QString &name) const;
    QPointF centerOf(const QString &name, bool *ok) const;
    void mouse(QEvent::Type t, const QPointF &p, Qt::MouseButton b, Qt::MouseButtons bs);
    void key(const QString &k, Qt::KeyboardModifiers mods, const QString &text = {});

    QQuickWindow *m_w;
    QJsonArray m_script;
    QString m_out;
    int m_fps;
    int m_next = 0;
    qint64 m_t = 0;
    qint64 m_end = 0;
    StepAnimationDriver m_driver;
    QProcess m_ffmpeg;
    QPointF m_pos{800, 980};
    // movimento in corso
    QPointF m_from, m_to; qint64 m_moveStart = 0, m_moveDur = 0; bool m_dragging = false;
    QString m_caption;
};
