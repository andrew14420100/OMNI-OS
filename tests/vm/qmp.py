#!/usr/bin/env python3
"""Comandi QMP per la VM di prova.

  qmp.py SOCK screendump FILE.png
  qmp.py SOCK type TESTO        (solo lettere minuscole e cifre)
  qmp.py SOCK key TASTO...      (qcode QEMU, es. ret tab esc; più tasti = combinazione)
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
else:
    sys.exit(f"azione sconosciuta: {action}")
