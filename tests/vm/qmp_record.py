#!/usr/bin/env python3
"""Registrazione reale dello schermo della VM con input reali, su UNA connessione QMP.

  qmp_record.py SOCK DIR-FOTOGRAMMI W H SCRIPT.json GEOMETRIA.json

SCRIPT.json: elenco di azioni con istante in ms, ad esempio
  {"t": 1000, "move": "dock:files"}   {"t": 2000, "click": "dock:launcher"}
  {"t": 3000, "keys": ["k","o"]}      {"t": 4000, "key": "esc"}
  {"t": 5000, "sweep": ["dock:launcher", "dock:settings"], "dur": 2500}
  {"t": 6000, "drag": "nc:card:x:0", "dx": 300}
GEOMETRIA.json: centro (x, y) di ogni elemento con objectName, misurato nella VM.
Fra un'azione e l'altra cattura fotogrammi con 'screendump' (PPM, convertiti dopo).
Scrive DIR/tempi.txt con l'istante reale di ogni fotogramma.
"""
import json
import os
import socket
import sys
import time

sock, out, W, H, script_path, geo_path = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5], sys.argv[6]
script = sorted(json.load(open(script_path)), key=lambda a: a["t"])
geo = json.load(open(geo_path))
os.makedirs(out, exist_ok=True)
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock)
f = s.makefile("rw")


def cmd(obj):
    f.write(json.dumps(obj) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            return r


json.loads(f.readline()); cmd({"execute": "qmp_capabilities"})
pos = [W / 2, H - 20]


def at(name):
    if name not in geo:
        print(f"AVVISO: elemento '{name}' non trovato nella geometria", file=sys.stderr)
        return None
    return [geo[name]["x"], geo[name]["y"]]


def move(x, y):
    pos[0], pos[1] = x, y
    cmd({"execute": "input-send-event", "arguments": {"events": [
        {"type": "abs", "data": {"axis": "x", "value": int(x * 32767 / W)}},
        {"type": "abs", "data": {"axis": "y", "value": int(y * 32767 / H)}}]}})


def btn(down):
    cmd({"execute": "input-send-event", "arguments": {"events": [{"type": "btn", "data": {"button": "left", "down": down}}]}})


def key(keys):
    cmd({"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": k} for k in keys], "hold-time": 50}})


frames = []
t0 = time.monotonic()


def shot():
    # al massimo 20 fotogrammi al secondo (screendump è molto veloce: evita migliaia di file uguali)
    if frames and (time.monotonic() - t0) - frames[-1] < 0.05:
        time.sleep(0.05 - ((time.monotonic() - t0) - frames[-1]))
    n = len(frames)
    p = os.path.join(out, f"f{n:05d}.ppm")
    cmd({"execute": "screendump", "arguments": {"filename": p}})
    frames.append(time.monotonic() - t0)


def wait_until(ms):
    while (time.monotonic() - t0) * 1000 < ms:
        shot()


def glide(target, dur):
    x0, y0 = pos; steps = max(1, int(dur / 60))
    for i in range(1, steps + 1):
        e = i / steps; e = e * e * (3 - 2 * e)
        move(x0 + (target[0] - x0) * e, y0 + (target[1] - y0) * e)
        shot()


for a in script:
    wait_until(a["t"])
    if "move" in a or "click" in a:
        p = at(a.get("move") or a.get("click"))
        if p:
            glide(p, a.get("dur", 500))
            if "click" in a:
                btn(True); time.sleep(0.06); btn(False)
    elif "sweep" in a:
        p1, p2 = at(a["sweep"][0]), at(a["sweep"][1])
        if p1 and p2:
            glide(p1, 400); glide(p2, a.get("dur", 2000))
    elif "drag" in a:
        p = at(a["drag"])
        if p:
            glide(p, 400); btn(True)
            glide([p[0] + a.get("dx", 0), p[1] + a.get("dy", 0)], a.get("dur", 600)); btn(False)
    elif "keys" in a:
        for k in a["keys"]:
            key([k]); shot()
    elif "key" in a:
        key(a["key"] if isinstance(a["key"], list) else [a["key"]])
wait_until(script[-1]["t"] + 1500)
with open(os.path.join(out, "tempi.txt"), "w") as fh:
    fh.write("\n".join(f"{t:.3f}" for t in frames))
print(f"fotogrammi: {len(frames)} in {frames[-1]:.1f} s ({len(frames) / max(frames[-1], 0.1):.1f} al secondo)")
