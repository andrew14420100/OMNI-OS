#!/usr/bin/env python3
"""AC-M1-08: verifica lo SBOM dell'immagine OMNI.

Uso: sbom_check.py <sbom.spdx.json> <sbom.cdx.json> <rpm-installati.tsv>
  rpm-installati.tsv: righe "NOME<TAB>VERSIONE-RILASCIO" da 'rpm -qa' nell'immagine.
Fallisce se il documento non è SPDX/CycloneDX valido nei campi essenziali o se un
pacchetto installato manca dallo SBOM (confronto per nome e versione-rilascio).
"""
import json
import sys

spdx_path, cdx_path, rpm_path = sys.argv[1:4]
errors = []


def norm(v):
    v = v or ""
    return v.split(":", 1)[1] if ":" in v and v.split(":", 1)[0].isdigit() else v


def is_rpm_purl(refs):
    return any(r.get("referenceType") == "purl" and r.get("referenceLocator", "").startswith("pkg:rpm/") for r in refs or [])


installed = set()
for ln in open(rpm_path):
    if ln.strip():
        name, vr = ln.rstrip("\n").split("\t")[:2]
        installed.add((name, vr))

spdx = json.load(open(spdx_path))
for field, ok in (("spdxVersion", str(spdx.get("spdxVersion", "")).startswith("SPDX-2.")),
                  ("dataLicense", spdx.get("dataLicense") == "CC0-1.0"),
                  ("documentNamespace", bool(spdx.get("documentNamespace"))),
                  ("creationInfo.created", bool(spdx.get("creationInfo", {}).get("created")))):
    if not ok:
        errors.append(f"SPDX: campo {field} mancante o non valido")
spdx_rpm = {(p["name"], norm(p.get("versionInfo"))) for p in spdx.get("packages", []) if is_rpm_purl(p.get("externalRefs"))}

cdx = json.load(open(cdx_path))
if cdx.get("bomFormat") != "CycloneDX" or not cdx.get("specVersion"):
    errors.append("CycloneDX: bomFormat/specVersion non validi")
cdx_rpm = {(c["name"], norm(c.get("version"))) for c in cdx.get("components", []) if str(c.get("purl", "")).startswith("pkg:rpm/")}

missing_spdx = sorted(installed - spdx_rpm)
missing_cdx = sorted(installed - cdx_rpm)
extra_spdx = sorted(spdx_rpm - installed)
if missing_spdx:
    errors.append(f"SPDX: {len(missing_spdx)} pacchetti installati mancanti")
if missing_cdx:
    errors.append(f"CycloneDX: {len(missing_cdx)} pacchetti installati mancanti")

print("| Verifica | Valore |\n|---|---|")
print(f"| Pacchetti RPM installati nell'immagine (`rpm -qa`) | {len(installed)} |")
print(f"| Pacchetti RPM nello SBOM SPDX ({spdx.get('spdxVersion')}) | {len(spdx_rpm)} |")
print(f"| Pacchetti RPM nello SBOM CycloneDX ({cdx.get('specVersion')}) | {len(cdx_rpm)} |")
print(f"| Pacchetti totali nello SBOM SPDX (tutti i tipi) | {len(spdx.get('packages', []))} |")
print(f"| Installati ma assenti in SPDX / CycloneDX | {len(missing_spdx)} / {len(missing_cdx)} |")
print(f"| In SPDX ma non installati (rpm) | {len(extra_spdx)} |")
print(f"| Generatore | {', '.join(spdx.get('creationInfo', {}).get('creators', []))} |")
for label, items in (("Mancanti in SPDX", missing_spdx), ("Mancanti in CycloneDX", missing_cdx), ("In più in SPDX", extra_spdx)):
    if items:
        print(f"\n{label} (primi 20): " + ", ".join(f"`{n}-{v}`" for n, v in items[:20]))
print()
if errors:
    for e in errors:
        print(f"- ERRORE: {e}")
    print("\nEsito: FALLITO")
    sys.exit(1)
print("Esito: SUPERATO (tutti i pacchetti installati sono presenti nello SBOM SPDX e CycloneDX)")
