#include "recorder.h"
#include <QCoreApplication>
#include <QFont>
#include <QGuiApplication>
#include <QImage>
#include <QJsonObject>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTimer>
#include <QKeySequence>
#include <cmath>

Recorder::Recorder(QQuickWindow *w, const QJsonArray &script, const QString &out, int fps, QObject *parent)
    : QObject(parent), m_w(w), m_script(script), m_out(out), m_fps(fps) {
    for (const auto &v : m_script) m_end = std::max<qint64>(m_end, v.toObject().value("t").toInteger() + v.toObject().value("dur").toInteger());
    m_end += 1200;
}

bool Recorder::start() {
    m_driver.install();
    const QSize s = m_w->size() * m_w->devicePixelRatio();
    m_ffmpeg.setProgram("ffmpeg");
    m_ffmpeg.setArguments({"-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba", "-s",
                           QString("%1x%2").arg(s.width()).arg(s.height()), "-r", QString::number(m_fps), "-i", "-",
                           "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
                           "-movflags", "+faststart", m_out});
    m_ffmpeg.setProcessChannelMode(QProcess::ForwardedChannels);
    m_ffmpeg.start();
    if (!m_ffmpeg.waitForStarted()) { qCritical("ffmpeg non disponibile"); return false; }
    QTimer::singleShot(0, this, &Recorder::tick);
    return true;
}

QQuickItem *Recorder::find(QQuickItem *root, const QString &name) const {
    if (!root) return nullptr;
    if (root->objectName() == name && root->isVisible()) return root;
    const auto kids = root->childItems();
    for (QQuickItem *c : kids) if (QQuickItem *r = find(c, name)) return r;
    return nullptr;
}

QPointF Recorder::centerOf(const QString &name, bool *ok) const {
    QQuickItem *it = find(m_w->contentItem(), name);
    *ok = it != nullptr;
    if (!it) { qWarning("registrazione: elemento non trovato: %s", qPrintable(name)); return m_pos; }
    return it->mapToScene(QPointF(it->width() / 2, it->height() / 2));
}

void Recorder::mouse(QEvent::Type t, const QPointF &p, Qt::MouseButton b, Qt::MouseButtons bs) {
    QMouseEvent ev(t, p, p, m_w->mapToGlobal(p), b, bs, Qt::NoModifier);
    QCoreApplication::sendEvent(m_w, &ev);
}

void Recorder::key(const QString &k, Qt::KeyboardModifiers mods, const QString &text) {
    static const QHash<QString, int> keys = {{"Escape", Qt::Key_Escape}, {"Return", Qt::Key_Return}, {"Down", Qt::Key_Down},
        {"Up", Qt::Key_Up}, {"Left", Qt::Key_Left}, {"Right", Qt::Key_Right}, {"Tab", Qt::Key_Tab}, {"Space", Qt::Key_Space},
        {"Backspace", Qt::Key_Backspace}, {"D", Qt::Key_D}};
    int code = keys.value(k, 0);
    if (!code && text.size() == 1) code = QKeySequence(text.toUpper())[0].key();
    QKeyEvent press(QEvent::KeyPress, code, mods, text), release(QEvent::KeyRelease, code, mods, text);
    QCoreApplication::sendEvent(m_w, &press);
    QCoreApplication::sendEvent(m_w, &release);
}

void Recorder::apply(const QJsonObject &a) {
    bool ok = true;
    const qint64 dur = a.value("dur").toInteger(400);
    if (a.contains("caption")) m_caption = a.value("caption").toString();
    if (a.contains("move") || a.contains("click") || a.contains("drag")) {
        const QString target = a.value(a.contains("move") ? "move" : a.contains("click") ? "click" : "drag").toString();
        QPointF to = centerOf(target, &ok);
        to += QPointF(a.value("dx0").toDouble(), a.value("dy0").toDouble());
        m_from = m_pos; m_to = to; m_moveStart = m_t; m_moveDur = std::max<qint64>(1, dur);
        if (a.contains("drag")) {   // premi sull'elemento, poi trascina di dx
            m_pos = to; mouse(QEvent::MouseMove, m_pos, Qt::NoButton, Qt::NoButton);
            mouse(QEvent::MouseButtonPress, m_pos, Qt::LeftButton, Qt::LeftButton);
            m_from = to; m_to = to + QPointF(a.value("dx").toDouble(), a.value("dy").toDouble()); m_dragging = true;
        }
    }
    if (a.contains("sweep")) {      // passaggio lento da un elemento all'altro (es. dock)
        const QJsonArray ab = a.value("sweep").toArray();
        bool ok2 = true; m_from = centerOf(ab.at(0).toString(), &ok); m_to = centerOf(ab.at(1).toString(), &ok2);
        m_pos = m_from; m_moveStart = m_t; m_moveDur = std::max<qint64>(1, dur);
    }
    if (a.contains("key")) {
        Qt::KeyboardModifiers mods;
        if (a.value("mods").toString() == "ctrl") mods |= Qt::ControlModifier;
        key(a.value("key").toString(), mods);
    }
    if (a.contains("text")) for (const QChar c : a.value("text").toString()) key(QString(), Qt::NoModifier, QString(c));
}

void Recorder::tick() {
    const qint64 frame = 1000 / m_fps;
    // azioni dovute in questo istante
    while (m_next < m_script.size() && m_script.at(m_next).toObject().value("t").toInteger() <= m_t) {
        const QJsonObject a = m_script.at(m_next++).toObject();
        apply(a);
        // il clic avviene alla fine dello spostamento
        if (a.contains("click")) {
            const qint64 d = a.value("dur").toInteger(400);
            QJsonObject c; c["t"] = m_t + d; c["press"] = true;
            m_script.insert(m_next, c);
        }
    }
    // spostamento in corso (curva morbida)
    if (m_moveDur > 0) {
        const double u = std::min(1.0, double(m_t - m_moveStart) / m_moveDur);
        const double e = u < 0.5 ? 4 * u * u * u : 1 - std::pow(-2 * u + 2, 3) / 2;
        m_pos = m_from + (m_to - m_from) * e;
        mouse(QEvent::MouseMove, m_pos, Qt::NoButton, m_dragging ? Qt::LeftButton : Qt::NoButton);
        if (u >= 1.0) {
            m_moveDur = 0;
            if (m_dragging) { mouse(QEvent::MouseButtonRelease, m_pos, Qt::LeftButton, Qt::NoButton); m_dragging = false; }
        }
    }
    // clic programmati
    if (m_next > 0) {
        const QJsonObject last = m_script.at(m_next - 1).toObject();
        if (last.value("press").toBool() && !last.value("_done").toBool()) {
            mouse(QEvent::MouseButtonPress, m_pos, Qt::LeftButton, Qt::LeftButton);
            mouse(QEvent::MouseButtonRelease, m_pos, Qt::LeftButton, Qt::NoButton);
            QJsonObject l = last; l["_done"] = true; m_script.replace(m_next - 1, l);
        }
    }
    QCoreApplication::processEvents();
    m_driver.step(frame);
    QImage img = m_w->grabWindow().convertToFormat(QImage::Format_RGBA8888);
    {
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing);
        const qreal k = m_w->devicePixelRatio();
        // puntatore (disegnato dal registratore)
        QPainterPath arrow;
        const QPointF o = m_pos * k;
        arrow.moveTo(o); arrow.lineTo(o + QPointF(0, 22 * k)); arrow.lineTo(o + QPointF(6 * k, 16.5 * k));
        arrow.lineTo(o + QPointF(10.5 * k, 26 * k)); arrow.lineTo(o + QPointF(14 * k, 24.5 * k));
        arrow.lineTo(o + QPointF(9.5 * k, 15 * k)); arrow.lineTo(o + QPointF(16.5 * k, 15 * k)); arrow.closeSubpath();
        p.setPen(QPen(Qt::black, 1.6 * k)); p.setBrush(Qt::white); p.drawPath(arrow);
        // didascalia e filigrana
        QFont f("Inter"); f.setPixelSize(int(15 * k)); f.setWeight(QFont::DemiBold); p.setFont(f);
        f.setPixelSize(int(13 * k)); p.setFont(f);
        const QString mark = QStringLiteral("Registrazione reale del prototipo OMNI Shell v2 · input automatizzato");
        const QRectF mr(img.width() - 500 * k, img.height() - 32 * k, 485 * k, 22 * k);
        p.setPen(Qt::NoPen); p.setBrush(QColor(0, 0, 0, 150)); p.drawRoundedRect(mr, 8 * k, 8 * k);
        p.setPen(QColor(255, 210, 120)); p.drawText(mr, Qt::AlignCenter, mark);
        if (!m_caption.isEmpty()) {
            f.setPixelSize(int(20 * k)); p.setFont(f);
            const QRectF cr(img.width() / 2.0 - 360 * k, 64 * k, 720 * k, 40 * k);
            p.setPen(Qt::NoPen); p.setBrush(QColor(6, 10, 22, 200)); p.drawRoundedRect(cr, 12 * k, 12 * k);
            p.setPen(Qt::white); p.drawText(cr, Qt::AlignCenter, m_caption);
        }
    }
    m_ffmpeg.write(reinterpret_cast<const char *>(img.constBits()), img.sizeInBytes());
    m_ffmpeg.waitForBytesWritten(-1);
    m_t += frame;
    if (m_t <= m_end) { QTimer::singleShot(0, this, &Recorder::tick); return; }
    m_ffmpeg.closeWriteChannel();
    m_ffmpeg.waitForFinished(-1);
    const bool ok = m_ffmpeg.exitStatus() == QProcess::NormalExit && m_ffmpeg.exitCode() == 0;
    qInfo("registrazione %s: %s (%lld fotogrammi)", ok ? "salvata" : "NON salvata", qPrintable(m_out), m_t / frame);
    m_driver.uninstall();
    emit done(ok);
}
