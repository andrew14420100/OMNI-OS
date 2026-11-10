#!/usr/bin/env python3
"""Confronto prima/dopo delle misure di prestazioni (misure.tsv di prestazioni.sh).

Uso: confronto.py prima/misure.tsv dopo/misure.tsv > confronto.md
Le due misure vengono dalla stessa procedura, sullo stesso runner, nella stessa esecuzione.
"""
import csv
import re
import sys


def load(path):
    with open(path, newline="") as f:
        return {r["chiave"]: r for r in csv.DictReader(f, delimiter="\t")}


def num(v):
    m = re.fullmatch(r"\s*(-?[0-9]+(?:\.[0-9]+)?)\s*", v or "")
    return float(m.group(1)) if m else None


def cpu_total(v, names=("omni-shell-prot", "kwin_wayland", "plasmashell")):
    vals = dict(re.findall(r"([\w-]+)=([0-9.]+)%", v or ""))
    return sum(float(vals[n]) for n in names if n in vals) if vals else None


prima, dopo = load(sys.argv[1]), load(sys.argv[2])
print(f"| Misura | Prima ({sys.argv[3] if len(sys.argv) > 3 else 'prima'}) | Dopo ({sys.argv[4] if len(sys.argv) > 4 else 'dopo'}) | Variazione |")
print("|---|---|---|---|")
for k in list(prima) + [k for k in dopo if k not in prima]:
    a, b = prima.get(k, {}), dopo.get(k, {})
    va, vb = a.get("valore", "—"), b.get("valore", "—")
    u = a.get("unita") or b.get("unita") or ""
    delta = ""
    if k.startswith("cpu."):
        ta, tb = cpu_total(va), cpu_total(vb)
        if ta is not None and tb is not None:
            delta = f"totale shell+KWin: {ta:.1f}% → {tb:.1f}%"
    else:
        na, nb = num(va), num(vb)
        if na is not None and nb is not None and na != 0:
            delta = f"{(nb - na) / na * 100:+.0f}%"
    print(f"| {k} | {va} {u if num(va) is not None else ''} | {vb} {u if num(vb) is not None else ''} | {delta} |")
