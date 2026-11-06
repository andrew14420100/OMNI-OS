#!/usr/bin/env python3
"""AC-M1-07: confronta due raccolte di repro_collect.sh e produce un riepilogo Markdown.

Uso: repro_compare.py <dir-A> <dir-B> <titolo>
Distingue la riproducibilità funzionale (stessi pacchetti, stessi file con stesso
contenuto e metadati) dall'identità binaria (stessi layer e stesso ID dell'immagine).
"""
import sys
from pathlib import Path

a, b, title = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]


def lines(d, name):
    return (d / name).read_text().splitlines()


def kv(d, name, sep):
    out = {}
    for ln in lines(d, name):
        if sep == "sha":
            h, _, p = ln.partition("  ")
            out[p] = h
        else:
            p, _, rest = ln.partition("\t")
            out[p] = rest
    return out


def diff(x, y):
    only_a = sorted(set(x) - set(y))
    only_b = sorted(set(y) - set(x))
    changed = sorted(k for k in set(x) & set(y) if x[k] != y[k])
    return only_a, only_b, changed


print(f"### {title}\n")
ida, idb = lines(a, "image-id.txt")[0], lines(b, "image-id.txt")[0]
la, lb = lines(a, "layers.txt"), lines(b, "layers.txt")
same_layers = sum(1 for i, j in zip(la, lb) if i == j)
print("| Verifica | A | B | Esito |\n|---|---|---|---|")
print(f"| ID immagine | `{ida[:16]}…` | `{idb[:16]}…` | {'identico' if ida == idb else 'diverso'} |")
print(f"| Data di creazione | {lines(a, 'created.txt')[0]} | {lines(b, 'created.txt')[0]} | |")
print(f"| Layer (diff ID) | {len(la)} | {len(lb)} | {same_layers} identici, {max(len(la), len(lb)) - same_layers} diversi |")
ra, rb = lines(a, "rpm.txt"), lines(b, "rpm.txt")
print(f"| Pacchetti RPM (NEVRA) | {len(ra)} | {len(rb)} | {'identici' if ra == rb else 'diversi'} |")
ma, mb = kv(a, "meta.tsv", "tab"), kv(b, "meta.tsv", "tab")
oa, ob, ch = diff(ma, mb)
print(f"| Voci del filesystem (tipo, permessi, proprietario, dimensione, link) | {len(ma)} | {len(mb)} | "
      f"{len(oa)} solo in A, {len(ob)} solo in B, {len(ch)} diverse |")
ha, hb = kv(a, "sha256.txt", "sha"), kv(b, "sha256.txt", "sha")
hoa, hob, hch = diff(ha, hb)
print(f"| Contenuto dei file regolari (SHA-256) | {len(ha)} | {len(hb)} | "
      f"{len(hoa)} solo in A, {len(hob)} solo in B, {len(hch)} con contenuto diverso |")
ta, tb = kv(a, "mtime.tsv", "tab"), kv(b, "mtime.tsv", "tab")
_, _, tch = diff(ta, tb)
print(f"| Date di modifica dei file | | | {len(tch)} diverse |")

functional = ra == rb and not (oa or ob or ch or hoa or hob or hch)
binary = ida == idb and la == lb
print(f"\n- **Riproducibilità funzionale** (pacchetti, file, contenuti e metadati): **{'SÌ' if functional else 'NO'}**")
print(f"- **Identità binaria** (layer e ID immagine identici): **{'SÌ' if binary else 'NO'}**")
for label, items in (("Voci solo in A", oa), ("Voci solo in B", ob), ("Metadati diversi", ch),
                     ("Contenuto diverso", hch), ("Date di modifica diverse", tch)):
    if items:
        print(f"\n{label} ({len(items)}, primi 30):\n")
        for p in items[:30]:
            print(f"- `{p}`")
rpm_d = sorted(set(ra) ^ set(rb))
if rpm_d:
    print("\nPacchetti diversi:\n")
    for p in rpm_d[:30]:
        print(f"- `{p}`")
