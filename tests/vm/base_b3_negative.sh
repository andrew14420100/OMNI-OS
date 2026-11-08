#!/usr/bin/env bash
# Prove negative della base B3: il caricamento DEVE rifiutare
#   N1. l'archivio reale se base.lock fissa un digest diverso;
#   N2. un archivio con digest diverso da quello fissato in base.lock;
#   N3. un archivio il cui index.json dichiara il digest fissato ma con il manifest alterato.
# Uso: base_b3_negative.sh [<cartella con l'archivio reale>]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
real=${1:-}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pinned=$(sed -n 's/^DERIVED_OCI_DIGEST=//p' image/base.lock)
[ -n "$pinned" ] || { echo "ERRORE: DERIVED_OCI_DIGEST non fissato"; exit 1; }
pass=0
expect_fail() {   # expect_fail <nome> <messaggio atteso> <comando...>
  local name=$1 want=$2; shift 2
  if out=$("$@" 2>&1); then echo "NEGATIVO $name: FALLITO (caricamento accettato)"; echo "$out"; exit 1; fi
  echo "$out" | grep -q "$want" || { echo "NEGATIVO $name: rifiutato per un motivo inatteso"; echo "$out"; exit 1; }
  echo "NEGATIVO $name: rifiutato come atteso ($(echo "$out" | grep -m1 "$want"))"; pass=$((pass + 1))
}
# archivio OCI sintetico: un layer, una configurazione, un manifest; opzionalmente alterato
make_archive() {   # make_archive <cartella> <digest dichiarato in index.json o "auto"> <altera: 0|1>
  python3 -I - "$@" <<'PY'
import hashlib, io, json, sys, tarfile
out, declared, tamper = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
def sha(b): return "sha256:" + hashlib.sha256(b).hexdigest()
layer = b"layer di prova OMNI"; config = json.dumps({"architecture": "amd64", "os": "linux"}).encode()
manifest = json.dumps({"schemaVersion": 2, "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "config": {"mediaType": "application/vnd.oci.image.config.v1+json", "digest": sha(config), "size": len(config)},
    "layers": [{"mediaType": "application/vnd.oci.image.layer.v1.tar", "digest": sha(layer), "size": len(layer)}]}).encode()
md = sha(manifest) if declared == "auto" else declared
blobs = {sha(layer): layer, sha(config): config, md: manifest + (b" " if tamper else b"")}
index = json.dumps({"schemaVersion": 2, "manifests": [{"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": md, "size": len(manifest)}]}).encode()
with tarfile.open(f"{out}/base.tar", "w") as t:
    for name, data in [("oci-layout", b'{"imageLayoutVersion":"1.0.0"}'), ("index.json", index)] + [(f"blobs/sha256/{d.split(':')[1]}", b) for d, b in blobs.items()]:
        ti = tarfile.TarInfo(name); ti.size = len(data); t.addfile(ti, io.BytesIO(data))
open(f"{out}/base-info.txt", "w").write(f"DERIVED_OCI_DIGEST={md}\n")
PY
}
# N1: archivio reale (o sintetico) + base.lock con un digest diverso
sed "s/^DERIVED_OCI_DIGEST=.*/DERIVED_OCI_DIGEST=sha256:$(printf '0%.0s' {1..64})/" image/base.lock > "$tmp/other.lock"
if [ -n "$real" ]; then src=$real; else mkdir -p "$tmp/n1"; make_archive "$tmp/n1" auto 0; src=$tmp/n1; fi
expect_fail N1 "diverso da quello atteso" env B3_LOCK="$tmp/other.lock" bash tests/vm/base_b3.sh load "$src"
# N2: archivio con un altro digest, base.lock reale
mkdir -p "$tmp/n2"; make_archive "$tmp/n2" auto 0
expect_fail N2 "diverso da quello atteso" bash tests/vm/base_b3.sh load "$tmp/n2"
# N3: index.json con il digest fissato, manifest alterato
mkdir -p "$tmp/n3"; make_archive "$tmp/n3" "$pinned" 1
expect_fail N3 "blob manomesso" bash tests/vm/base_b3.sh load "$tmp/n3"
echo "NEGATIVE_B3=ok ($pass/3 archivi non conformi rifiutati)"
