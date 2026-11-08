#!/usr/bin/env python3
"""Controlli statici sulla documentazione OMNI OS.

- le specifiche approvate v1.0 non sono cambiate (impronta SHA-256);
- le specifiche contengono le 55 decisioni numerate 1..55;
- la matrice di tracciabilità ha una riga per ciascuna decisione 1..55;
- i collegamenti relativi fra documenti Markdown puntano a file esistenti.
"""
import hashlib
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = ROOT / "docs/00-specifiche/specifiche-funzionali-v1.0.md"
TRACE = ROOT / "docs/01-architettura/tracciabilita-decisioni.md"
SPEC_HASH = ROOT / "tests/static/spec.sha256"
LINK_RE = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")
CODE_REF_RE = re.compile(r"`(\.\./[^`]+\.md)`")


def check_spec(errors):
    expected = SPEC_HASH.read_text().strip()
    actual = hashlib.sha256(SPEC.read_bytes()).hexdigest()
    if actual != expected:
        errors.append(f"specifiche modificate: sha256 {actual} != {expected}")
    numbers = [int(n) for n in re.findall(r"^(\d+)\. \*\*", SPEC.read_text(), re.M)]
    if numbers != list(range(1, 56)):
        errors.append(f"decisioni nelle specifiche: attese 1..55, trovate {numbers}")


def check_trace(errors):
    numbers = [int(n) for n in re.findall(r"^\| (\d+) \|", TRACE.read_text(), re.M)]
    if sorted(numbers) != list(range(1, 56)) or len(numbers) != 55:
        errors.append(f"tracciabilità: attese 55 righe 1..55, trovate {len(numbers)}")


def check_links(errors):
    for md in sorted(ROOT.rglob("*.md")):
        if ".git" in md.parts:
            continue
        text = md.read_text()
        for target in LINK_RE.findall(text) + CODE_REF_RE.findall(text):
            if re.match(r"^[a-z]+://", target):
                continue
            if not (md.parent / target).resolve().exists():
                errors.append(f"collegamento rotto in {md.relative_to(ROOT)}: {target}")


def main():
    errors = []
    check_spec(errors)
    check_trace(errors)
    check_links(errors)
    for e in errors:
        print(f"ERRORE: {e}")
    if errors:
        return 1
    print("check_docs: OK (specifiche invariate, 55 decisioni, 55 righe di tracciabilità, collegamenti validi)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
