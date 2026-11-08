#!/usr/bin/env bash
# Base B3: OCI derivata da un commit OSTree ufficiale Fedora verificato con GPG.
#
#   base_b3.sh prepare <dir>   verifica la provenienza, converte in OCI, verifica il
#                              risultato e scrive <dir>/base.tar e <dir>/base-info.txt
#   base_b3.sh load <dir>      verifica digest e blob dell'archivio e lo carica in podman
#   base_b3.sh import <dir>    reimporta l'archivio con ostree-ext e verifica il commit
#
# Catena di fiducia (prepare):
#   1. chiave Fedora 45: impronta = GPG_FINGERPRINT (base.lock) su DUE fonti ufficiali
#   2. ostree pull con gpg-verify=true (rifiuta commit senza firma valida)
#   3. analisi rigorosa dell'esito della firma (ostree show non usa il codice di uscita)
#   4. ostree fsck del commit (impronta di ogni oggetto)
#   5. conversione con rpm-ostree compose container-encapsulate (in un container Fedora,
#      rpm-ostree installato da dnf con verifica GPG dei pacchetti)
#   6. verifica indipendente sul runner: contenuto dell'OCI = checkout del commit verificato
#   7. digest del manifest OCI derivato: confrontato con DERIVED_OCI_DIGEST se già fissato
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
mode=${1:?prepare|load} out=${2:?dir}
lock=${B3_LOCK:-image/base.lock}
get() { grep -E "^$1=" "$lock" | head -1 | cut -d= -f2-; }
fail() { echo "ERRORE: $*"; exit 1; }
COMMIT=$(get OSTREE_COMMIT) FPR=$(get GPG_FINGERPRINT) KEYID=$(get GPG_KEY_ID)
URL=$(get OSTREE_REMOTE_URL) VERSION=$(get OSTREE_VERSION) IMG=$(get BASE_IMAGE)
PINNED=$(get DERIVED_OCI_DIGEST)
[ "$(get BASE_KIND)" = ostree-b3 ] || fail "BASE_KIND non è ostree-b3"
mkdir -p "$out"
work=${B3_WORK:-$out.work}   # file di lavoro grandi: fuori dalla cartella messa in cache

# load_tag <archivio>: carica in podman e assegna il nome locale $IMG
load_tag() { local r; r=$(sudo podman load -i "$1" 2>&1 | sed -n 's/^Loaded image.*: //p' | tail -1); [ -n "$r" ] || return 1; sudo podman tag "$r" "$IMG"; }
oci_digest() { python3 -I -c 'import json,sys,tarfile;t=tarfile.open(sys.argv[1]);print(json.load(t.extractfile("index.json"))["manifests"][0]["digest"])' "$1"; }
# verify_blobs <archivio>: ricalcola lo sha256 del manifest, della configurazione e di
# ogni layer e lo confronta con il nome (digest) dichiarato. Rileva archivi manomessi
# anche quando index.json riporta il digest atteso.
verify_blobs() {
  python3 -I - "$1" <<'PY'
import hashlib, json, sys, tarfile
t = tarfile.open(sys.argv[1])
def blob(d):
    algo, hexd = d.split(":", 1)
    if algo != "sha256": sys.exit(f"algoritmo non ammesso: {algo}")
    return t.extractfile(f"blobs/sha256/{hexd}")
def check(d):
    h = hashlib.sha256(); f = blob(d)
    for chunk in iter(lambda: f.read(1 << 20), b""): h.update(chunk)
    if "sha256:" + h.hexdigest() != d: sys.exit(f"blob manomesso: dichiarato {d}, calcolato sha256:{h.hexdigest()}")
md = json.load(t.extractfile("index.json"))["manifests"][0]["digest"]
check(md)
m = json.load(blob(md))
check(m["config"]["digest"])
for layer in m["layers"]: check(layer["digest"])
print(f"BLOBS_VERIFIED=manifest+config+{len(m['layers'])} layer")
PY
}

# run_import <archivio> <cartella risultati>: verifica autorevole. Reimporta l'OCI con
# ostree-ext (lo stesso meccanismo usato da bootc e rpm-ostree all'installazione) in un
# repository ostree nuovo e controlla che contenga il commit verificato: gli oggetti
# ostree sono indirizzati per contenuto, quindi un commit con lo stesso checksum e un
# fsck superato implicano file, cartelle, permessi, proprietari e xattr identici.
run_import() {
  local arc=$1 res=$2 tool=quay.io/fedora/fedora:45
  mkdir -p "$res"
  sudo podman pull -q "$tool" >/dev/null
  sudo podman run --rm --privileged --security-opt label=disable -v "$(dirname "$arc")":/in:ro -v "$res":/res "$tool" bash -euo pipefail -c "
    dnf -y -q install rpm-ostree >/dev/null
    mkdir -p /tmp/imp && ostree --repo=/tmp/imp init --mode=bare
    ostree container image pull /tmp/imp ostree-unverified-image:oci-archive:/in/$(basename "$arc") > /res/import.log 2>&1 || { tail -20 /res/import.log; exit 1; }
    ref=\$(ostree --repo=/tmp/imp refs | grep '^ostree/container/image/' | head -1)
    { echo \"IMPORT_REF_COMMIT=\$(ostree --repo=/tmp/imp rev-parse \"\$ref\")\"
      echo \"IMPORT_HAS_VERIFIED_COMMIT=\$(ostree --repo=/tmp/imp rev-parse $COMMIT 2>/dev/null || echo no)\"
      if ostree --repo=/tmp/imp fsck >/dev/null 2>&1; then echo IMPORT_FSCK=ok; else echo IMPORT_FSCK=fallito; fi
      # albero del commit di unione (quello che bootc installa) contro albero del commit verificato:
      # ls -C riporta i checksum di ogni file e dei metadati di ogni cartella
      ostree --repo=/tmp/imp ls -R -C \"\$ref\" / > /res/tree-ref.txt
      ostree --repo=/tmp/imp ls -R -C $COMMIT / > /res/tree-verified.txt
      echo \"IMPORT_TREE_ENTRIES=\$(wc -l < /res/tree-verified.txt)\"
      if cmp -s /res/tree-ref.txt /res/tree-verified.txt; then echo IMPORT_TREE_IDENTICAL=si; else echo IMPORT_TREE_IDENTICAL=no; diff /res/tree-verified.txt /res/tree-ref.txt | head -20; fi
    } > /res/import-result.txt
    ostree --repo=/tmp/imp ls -R $COMMIT / > /res/meta-imported.txt 2>/dev/null || true"
  sudo chown -R "$(id -u):$(id -g)" "$res"
  cat "$res/import-result.txt"
  grep -q "^IMPORT_FSCK=ok$" "$res/import-result.txt" || fail "fsck del repository reimportato fallito"
  grep -q "^IMPORT_HAS_VERIFIED_COMMIT=$COMMIT$" "$res/import-result.txt" || fail "la reimportazione non contiene il commit verificato $COMMIT"
  grep -q "^IMPORT_TREE_IDENTICAL=si$" "$res/import-result.txt" || fail "l'albero del commit installabile differisce da quello del commit verificato"
  echo "IMPORT=ok (l'OCI derivata ricostruisce il commit verificato $COMMIT; l'albero installabile è identico, metadati compresi)"
}

if [ "$mode" = import ]; then
  [ -f "$out/base.tar" ] || fail "archivio della base assente in $out"
  run_import "$out/base.tar" "${B3_WORK:-$out.work}/import"
  exit 0
fi

if [ "$mode" = load ]; then
  [ -f "$out/base.tar" ] || fail "archivio della base assente in $out (cache non ripristinata?)"
  d=$(oci_digest "$out/base.tar")
  want=${PINNED:-$(sed -n 's/^DERIVED_OCI_DIGEST=//p' "$out/base-info.txt")}
  [ -n "$want" ] || fail "nessun digest atteso per la base derivata"
  [ "$d" = "$want" ] || fail "digest della base derivata $d diverso da quello atteso $want"
  verify_blobs "$out/base.tar" || fail "verifica dei blob dell'archivio fallita"
  if [ -z "$PINNED" ]; then echo "AVVISO: DERIVED_OCI_DIGEST non ancora fissato in base.lock; atteso dal job della base: $want"; fi
  load_tag "$out/base.tar" || fail "caricamento dell'archivio fallito"
  sudo podman image exists "$IMG" || fail "immagine $IMG non presente dopo il caricamento"
  echo "base B3 caricata: $IMG (digest $d, commit $COMMIT)"
  exit 0
fi

[ "$mode" = prepare ] || fail "modalità sconosciuta: $mode"
info=$out/base-info.txt; : > "$info"
log() { echo "$*" | tee -a "$info"; }
sudo apt-get install -y -qq ostree gnupg >/dev/null
log "OSTREE_COMMIT=$COMMIT"
log "OSTREE_VERSION=$VERSION"
log "ostree_tool=$(ostree --version | sed -n "s/^ Version: //p" | tr -d "'")"

# 1. Chiave: due fonti ufficiali, stessa impronta attesa.
k=$work/keys; mkdir -p "$k"
curl -sSLf --retry 5 --retry-delay 5 --retry-all-errors -o "$k/fedora-repos.asc" "$(get GPG_KEY_URL)"
curl -sSLf --retry 5 --retry-delay 5 --retry-all-errors -o "$k/fedora.gpg" "$(get GPG_KEYRING_URL)"
f1=$(gpg --show-keys --with-colons "$k/fedora-repos.asc" | awk -F: '/^fpr/{print $10; exit}')
f2=$(gpg --show-keys --with-colons "$k/fedora.gpg" | awk -F: '/^fpr/{print $10}' | grep -x "$FPR" || true)
[ "$f1" = "$FPR" ] || fail "impronta della chiave da fedora-repos ($f1) diversa da $FPR"
[ "$f2" = "$FPR" ] || fail "impronta $FPR assente dal portachiavi fedoraproject.org/fedora.gpg"
log "GPG_FINGERPRINT_VERIFIED=$FPR (fedora-repos e fedoraproject.org/fedora.gpg concordanti)"

# 2-4. Commit: pull con verifica obbligatoria, esito della firma, fsck.
repo=$work/ostree-repo
if [ ! -d "$repo/objects" ]; then ostree --repo="$repo" init --mode=archive >/dev/null; fi
ostree --repo="$repo" remote delete --if-exists fedora
ostree --repo="$repo" remote add --set=gpg-verify=true --set=gpgkeypath="$k/fedora-repos.asc" fedora "$URL"
[ "$(ostree --repo="$repo" config get 'remote "fedora".gpg-verify')" = true ] || fail "gpg-verify non attivo sul remoto"
t0=$(date +%s)
ostree --repo="$repo" pull fedora "$COMMIT" 2>&1 | tail -3
log "pull_seconds=$(( $(date +%s) - t0 ))"
sig=$(ostree --repo="$repo" show --gpg-verify-remote=fedora "$COMMIT" 2>&1)
echo "$sig" | grep -E "Signature|Good|BAD|Can't|key" | sed 's/^/  /'
echo "$sig" | grep -q "using RSA key ID $KEYID" || fail "firma non prodotta dalla chiave $KEYID"
echo "$sig" | grep -q 'Good signature from "Fedora <fedora-45-primary@fedoraproject.org>"' || fail "firma non valida"
if echo "$sig" | grep -qE "BAD signature|Can't check|EXPIRED|REVOKED"; then fail "esito della firma non accettabile"; fi
log "GPG_SIGNATURE=Good signature, key ID $KEYID"
got_version=$(ostree --repo="$repo" show "$COMMIT" | sed -n 's/^Version: //p')
[ "$got_version" = "$VERSION" ] || fail "versione del commit $got_version diversa da $VERSION"
ostree --repo="$repo" fsck --verify-back-refs 2>&1 | tail -2 || fail "ostree fsck fallito"
log "OSTREE_FSCK=ok"

# 5. Conversione in OCI in un container Fedora (strumento, non contenuto).
tool=quay.io/fedora/fedora:45
sudo podman pull -q "$tool" >/dev/null
log "tool_image=$tool@$(sudo podman image inspect --format '{{.Digest}}' "$tool")"
sudo podman run --rm --security-opt label=disable -v "$repo":/repo:ro -v "$out":/out "$tool" bash -euo pipefail -c "
  dnf -y -q install rpm-ostree >/dev/null
  { rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}\nSIGPGP: %{SIGPGP:pgpsig}\nRSAHEADER: %{RSAHEADER:pgpsig}\nOPENPGP: %{OPENPGP}\n' rpm-ostree 2>&1
    echo \"dnf gpgcheck: \$(grep -hE '^gpgcheck' /etc/dnf/dnf.conf /etc/yum.repos.d/fedora*.repo 2>/dev/null | sort -u | tr '\n' ' ')\"; } > /out/tool-rpm-ostree.txt
  rpm-ostree compose container-encapsulate --repo=/repo \
    --label containers.bootc=1 --label ostree.bootable=true \
    --label org.opencontainers.image.version=$VERSION \
    $COMMIT oci-archive:/out/base.tar"
sudo chown -R "$(id -u):$(id -g)" "$out" "$work"
log "tool_rpm_ostree=$(tr '\n' ' ' < "$out/tool-rpm-ostree.txt")"
run_import "$out/base.tar" "$work/import" | while read -r ln; do log "$ln"; done
grep -q '^IMPORT=ok' "$info" || fail "verifica di reimportazione non superata"
cp "$work/import/meta-imported.txt" "$work/meta-imported.txt"
d=$(oci_digest "$out/base.tar")
log "DERIVED_OCI_DIGEST=$d"
if [ -n "$PINNED" ] && [ "$d" != "$PINNED" ]; then fail "la conversione ha prodotto $d, diverso dal digest fissato $PINNED"; fi

# 6. Verifica indipendente: contenuto dell'immagine derivata = checkout del commit verificato.
load_tag "$out/base.tar" || fail "caricamento dell'archivio fallito"
sudo podman image exists "$IMG" || fail "immagine derivata non caricata"
log "loaded_as=$IMG"
lbl=$(sudo podman image inspect --format '{{index .Labels "ostree.commit"}}' "$IMG")
log "label_ostree_commit=$lbl"
[ "$lbl" = "$COMMIT" ] || fail "etichetta ostree.commit ($lbl) diversa dal commit verificato"
co=$work/checkout; sudo rm -rf "$co"
ostree --repo="$repo" checkout -U "$COMMIT" "$co"
# Metadati di riferimento dal commit verificato (tipo, permessi, proprietario, destinazione
# dei collegamenti): presi da ostree, non dal checkout -U che non conserva i proprietari.
ostree --repo="$repo" ls -R "$COMMIT" / > "$work/meta-commit.txt"
mnt=$(sudo podman image mount "$IMG")
# il punto di montaggio dell'immagine è leggibile solo da root: tutto il percorso gira con sudo
lists() { sudo bash -c 'cd "$1" && find . -xdev -type f -print0 | xargs -0 -n 2000 sha256sum' _ "$1" | sed 's#  \./#  #' | LC_ALL=C sort -k2; }
lists "$co" > "$work/sha-commit.txt"
lists "$mnt" > "$work/sha-oci.txt"
sudo find "$mnt" -xdev -mindepth 1 -printf '%y\t%m\t%U\t%G\t%P\t%l\n' | tee "$work/meta-oci.txt" >/dev/null
sudo podman image umount "$IMG" >/dev/null
python3 -I - "$work" <<'PY' | tee -a "$info"
import sys
from collections import Counter
from pathlib import Path
d = Path(sys.argv[1])
def norm(p):
    # il commit ostree conserva la configurazione in usr/etc; l'OCI può presentarla in etc
    if p == "usr/etc": return "etc"
    return "etc/" + p[len("usr/etc/"):] if p.startswith("usr/etc/") else p
def m(n):
    r = {}
    for ln in (d / n).read_text().splitlines():
        h, _, p = ln.partition("  "); r[norm(p)] = h
    return r
# --- contenuto dei file regolari ---
c, o = m("sha-commit.txt"), m("sha-oci.txt")
same = [p for p in c if p in o and c[p] == o[p]]
diff = [p for p in c if p in o and c[p] != o[p]]
only_c = sorted(set(c) - set(o)); only_o = sorted(set(o) - set(c))
print(f"EQUIV_FILES_COMMIT={len(c)}"); print(f"EQUIV_FILES_OCI={len(o)}")
print(f"EQUIV_SAME_CONTENT={len(same)}"); print(f"EQUIV_DIFFERENT_CONTENT={len(diff)}")
print(f"EQUIV_ONLY_IN_COMMIT={len(only_c)}"); print(f"EQUIV_ONLY_IN_OCI={len(only_o)}")
# --- metadati: ogni voce del commit (file, cartelle, collegamenti) ---
TYPES = {"-": "f", "d": "d", "l": "l"}
mc = {}
for ln in (d / "meta-commit.txt").read_text().splitlines():
    # formato ostree ls: <tipo><permessi ottali> <uid> <gid> <dimensione> /percorso [-> destinazione]
    parts = ln.split(None, 4)
    if len(parts) < 5: continue
    mode, uid, gid, _size, rest = parts
    path, _, target = rest.partition(" -> ")
    path = path.lstrip("/")
    if not path: continue
    mc[norm(path)] = (TYPES.get(mode[0], mode[0]), int(mode[1:], 8) & 0o7777, int(uid), int(gid), target)
mo = {}
for ln in (d / "meta-oci.txt").read_text().splitlines():
    y, perm, uid, gid, path, target = (ln.split("\t") + [""] * 6)[:6]
    mo[norm(path)] = (y, int(perm, 8) & 0o7777, int(uid), int(gid), target)
kinds = Counter(); samples = []
for p, (ty, pm, u, g, tg) in mc.items():
    if p not in mo: kinds["mancante"] += 1; samples.append(f"mancante: {p}"); continue
    oy, opm, ou, og, otg = mo[p]
    if oy != ty: kinds["tipo"] += 1; samples.append(f"tipo {ty}->{oy}: {p}"); continue
    if ty == "l":
        if otg != tg: kinds["destinazione"] += 1; samples.append(f"destinazione {tg} -> {otg}: {p}")
    elif opm != pm: kinds["permessi"] += 1; samples.append(f"permessi {pm:o}->{opm:o}: {p}")
    if (ou, og) != (u, g): kinds["proprietario"] += 1; samples.append(f"proprietario {u}:{g}->{ou}:{og}: {p}")
types_c = Counter(v[0] for v in mc.values())
print(f"META_ENTRIES_COMMIT={len(mc)} (file {types_c['f']}, cartelle {types_c['d']}, collegamenti {types_c['l']})")
for k in ("mancante", "tipo", "destinazione", "permessi", "proprietario"):
    print(f"META_DIFF_{k.upper()}={kinds[k]}")
for s_ in samples[:20]: print(f"  {s_}")
# Vista container: differenze ammesse SOLO per permessi/proprietario di CARTELLE (le
# cartelle senza voce esplicita nel tar ricevono valori predefiniti), a condizione che la
# reimportazione ostree ricostruisca il commit verificato con metadati identici (vedi sotto).
def tolerated(s_):
    kind, _, path = s_.rpartition(": ")
    return (kind.startswith("permessi") or kind.startswith("proprietario")) and mc.get(path, ("?",))[0] == "d"
tol = [s_ for s_ in samples if tolerated(s_)]
other = [s_ for s_ in samples if not tolerated(s_)]
print(f"META_CONTAINER_VIEW_DIRS={len(tol)} (etc/: {sum(1 for x in tol if x.rpartition(': ')[2].startswith('etc/'))}, altre: {sum(1 for x in tol if not x.rpartition(': ')[2].startswith('etc/'))})")
for s_ in [x for x in tol if not x.rpartition(': ')[2].startswith('etc/')][:15]: print(f"  cartella con valori predefiniti: {s_}")
print(f"META_CONTAINER_VIEW_OTHER={len(other)}")
for s_ in other[:15]: print(f"  differenza non ammessa: {s_}")
# Vista ostree reimportata: deve coincidere voce per voce con il commit verificato.
imp = d / "meta-imported.txt"
if imp.exists() and imp.stat().st_size > 0:
    a = (d / "meta-commit.txt").read_text().splitlines(); b = imp.read_text().splitlines()
    print(f"IMPORT_META_ENTRIES={len(b)}")
    print(f"IMPORT_META_IDENTICAL={'si' if a == b else 'no'}")
else:
    print("IMPORT_META_IDENTICAL=no (metadati non disponibili)")
# --- voci presenti solo nell'OCI, per cartella di primo livello ---
extra = [p for p in mo if p not in mc]
top = Counter(p.split("/", 1)[0] for p in extra)
print(f"META_ONLY_IN_OCI={len(extra)} per cartella: " + ", ".join(f"{k}={v}" for k, v in sorted(top.items())))
outside = [p for p in extra if mo[p][0] == "f" and not p.startswith("sysroot/")]
print(f"META_ONLY_IN_OCI_FILES_OUTSIDE_SYSROOT={len(outside)}")
for p in outside[:15]: print(f"  file aggiunto fuori da sysroot: {p}")
for label, items in (("solo nel commit", only_c), ("contenuto diverso", diff)):
    for p in items[:15]:
        print(f"  {label}: {p}")
PY
grep -q '^EQUIV_DIFFERENT_CONTENT=0$' "$info" || fail "file con contenuto diverso fra commit verificato e OCI derivata"
grep -q '^EQUIV_ONLY_IN_COMMIT=0$' "$info" || fail "file del commit verificato assenti dall'OCI derivata"
for k in MANCANTE TIPO DESTINAZIONE; do
  grep -q "^META_DIFF_$k=0$" "$info" || fail "metadati diversi fra commit verificato e OCI derivata ($k)"
done
grep -q '^META_CONTAINER_VIEW_OTHER=0$' "$info" || fail "differenze di metadati non ammesse nella vista container dell'OCI"
grep -q '^IMPORT_META_IDENTICAL=si$' "$info" || fail "i metadati del commit reimportato differiscono da quelli del commit verificato"
grep -q '^META_ONLY_IN_OCI_FILES_OUTSIDE_SYSROOT=0$' "$info" || fail "la conversione ha aggiunto file regolari fuori da sysroot/"
oo=$(sed -n 's/^EQUIV_ONLY_IN_OCI=//p' "$info")
ed=$(sed -n 's/^META_CONTAINER_VIEW_DIRS=//p' "$info")
log "EQUIVALENCE=ok (reimportazione ostree: commit verificato ricostruito con metadati identici; vista container: contenuto, tipi e collegamenti identici, cartelle con permessi/proprietario predefiniti: $ed; file aggiunti solo in sysroot/: $oo)"
sudo rm -rf "$co" "$k"
echo "base B3 pronta: $out/base.tar ($d)"
