// Funzioni comuni delle app OMNI sopra omniSystem (C++): ogni chiamata ha la sua risposta,
// nessun esito viene supposto prima della risposta del sistema.

// La risposta può arrivare dopo che la pagina che l'ha chiesta è stata chiusa: il suo
// contesto QML non esiste più ("omniSystem" non è più visibile da qui). In quel caso la
// risposta non ha più un destinatario e viene ignorata (nessun aggiornamento di una pagina
// distrutta). Le connessioni usano il riferimento preso alla chiamata.
function alive() { return typeof omniSystem !== "undefined" }

function run(program, args, cb, opts) {
    opts = opts || {}
    const sys = omniSystem
    const id = sys.run(program, args || [], opts.timeout === undefined ? 60000 : opts.timeout, !!opts.onLine)
    const lineH = function (rid, text) { if (rid === id && alive()) opts.onLine(text) }
    const done = function (rid, code, out, err) {
        if (rid !== id) return
        sys.finished.disconnect(done)
        if (opts.onLine) sys.line.disconnect(lineH)
        if (cb && alive()) cb(code, out, err)
    }
    sys.finished.connect(done)
    if (opts.onLine) sys.line.connect(lineH)
    return id
}

function dbus(bus, service, path, iface, method, args, cb, interactive) {
    const sys = omniSystem
    const id = sys.dbus(bus, service, path, iface, method, args || [], !!interactive, 120000)
    const done = function (rid, ok, result, error) {
        if (rid !== id) return
        sys.dbusFinished.disconnect(done)
        if (cb && alive()) cb(ok, result, error)
    }
    sys.dbusFinished.connect(done)
    return id
}

function prop(bus, service, path, iface, name, cb) {
    return dbus(bus, service, path, "org.freedesktop.DBus.Properties", "Get", ["s:" + iface, "s:" + name], cb)
}

// kreadconfig6 / kwriteconfig6: impostazioni KDE dell'utente (lette e scritte dal programma ufficiale)
function readKde(file, group, key, def, cb) {
    const args = ["--file", file]
    for (const g of [].concat(group)) args.push("--group", g)
    args.push("--key", key)
    if (def !== undefined) args.push("--default", String(def))
    return run("kreadconfig6", args, function (code, out) { cb(code === 0 ? out.trim() : String(def)) })
}
function writeKde(file, group, key, value, cb, type) {
    const args = ["--file", file]
    for (const g of [].concat(group)) args.push("--group", g)
    args.push("--key", key)
    if (type) args.push("--type", type)
    args.push(String(value))
    return run("kwriteconfig6", args, function (code, out, err) { if (cb) cb(code === 0, err) })
}

function humanBytes(b) {
    b = Number(b) || 0
    const u = ["B", "KB", "MB", "GB", "TB"]
    let i = 0
    while (b >= 1024 && i < u.length - 1) { b /= 1024; ++i }
    return (i === 0 ? b : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i]
}
