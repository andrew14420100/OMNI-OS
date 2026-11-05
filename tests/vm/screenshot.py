#!/usr/bin/env python3
"""P7: cattura lo schermo della VM tramite il monitor QMP di QEMU (formato PNG)."""
import json
import socket
import sys

sock_path, out = sys.argv[1], sys.argv[2]
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


json.loads(f.readline())  # saluto QMP
cmd({"execute": "qmp_capabilities"})
r = cmd({"execute": "screendump", "arguments": {"filename": out, "format": "png"}})
print(r)
sys.exit(0 if "return" in r else 1)
