#!/usr/bin/env python3
"""Comandi QMP per la VM di prova.

  qmp.py SOCK screendump FILE.png
  qmp.py SOCK type TESTO        (solo lettere minuscole e cifre)
  qmp.py SOCK key TASTO...      (qcode QEMU, es. ret tab esc; più tasti = combinazione)
  qmp.py SOCK tap TASTO         (pressione e rilascio separati, es. meta_l)
  qmp.py SOCK move X Y W H      (puntatore assoluto in pixel su schermo W×H; richiede usb-tablet)
  qmp.py SOCK click X Y W H     (movimento e clic sinistro)
  qmp.py SOCK drag X1 Y1 X2 Y2 W H
"""
import json
import socket
import sys
import time

sock_path, action, args = sys.argv[1], sys.argv[2], sys.argv[3:]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
f = s.makefile("rw")


def cmd(obj):
    f.write(json.dumps(obj) + "\n")
    f.flush()
    while True:
        reply = json.loads(f.readline())
        if "return" in reply or "error" in reply:
            return reply


def send_keys(keys):
    r = cmd({"execute": "send-key",
             "arguments": {"keys": [{"type": "qcode", "data": k} for k in keys], "hold-time": 60}})
    if "error" in r:
        sys.exit(f"send-key fallito: {r['error']}")
    time.sleep(0.12)


json.loads(f.readline())  # saluto QMP
cmd({"execute": "qmp_capabilities"})
if action == "screendump":
    r = cmd({"execute": "screendump", "arguments": {"filename": args[0], "format": "png"}})
    sys.exit(0 if "return" in r else 1)
elif action == "type":
    text = args[0]
    if not all(c.isdigit() or ("a" <= c <= "z") for c in text):
        sys.exit("type: ammessi solo a-z e 0-9")
    for c in text:
        send_keys([c])
elif action == "key":
    send_keys(args)
elif action == "tap":
    # pressione e rilascio separati (come una tastiera reale), per i tasti modificatori da soli
    for down in (True, False):
        r = cmd({"execute": "input-send-event", "arguments": {"events": [
            {"type": "key", "data": {"down": down, "key": {"type": "qcode", "data": args[0]}}}]}})
        if "error" in r:
            sys.exit(f"input-send-event fallito: {r['error']}")
        time.sleep(0.25)
elif action in ("move", "click", "drag"):
    def absmove(x, y, w, h):
        ev = [{"type": "abs", "data": {"axis": "x", "value": int(float(x) * 32767 / float(w))}},
              {"type": "abs", "data": {"axis": "y", "value": int(float(y) * 32767 / float(h))}}]
        r = cmd({"execute": "input-send-event", "arguments": {"events": ev}})
        if "error" in r:
            sys.exit(f"input-send-event fallito: {r['error']}")

    def button(down):
        r = cmd({"execute": "input-send-event",
                 "arguments": {"events": [{"type": "btn", "data": {"button": "left", "down": down}}]}})
        if "error" in r:
            sys.exit(f"input-send-event fallito: {r['error']}")

    if action == "drag":
        x1, y1, x2, y2, w, h = args
        absmove(x1, y1, w, h); button(True)
        for i in range(1, 11):
            absmove(float(x1) + (float(x2) - float(x1)) * i / 10, float(y1) + (float(y2) - float(y1)) * i / 10, w, h)
            time.sleep(0.04)
        button(False)
    else:
        x, y, w, h = args
        absmove(x, y, w, h)
        if action == "click":
            time.sleep(0.08); button(True); time.sleep(0.08); button(False)
else:
    sys.exit(f"azione sconosciuta: {action}")
