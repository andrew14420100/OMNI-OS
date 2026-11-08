#!/usr/bin/env bash
# Base B3: OCI derivata da un commit OSTree ufficiale Fedora verificato con GPG.
#
#   base_b3.sh prepare <dir>   verifica la provenienza, converte in OCI, verifica il
#                              risultato e scrive <dir>/base.tar e <dir>/base-info.txt
#   base_b3.sh load <dir>      verifica il digest dell'archivio e lo carica in podman
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
lock=image/base.lock
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

if [ "$mode" = load ]; then
  [ -f "$out/base.tar" ] || fail "archivio della base assente in $out (cache non ripristinata?)"
  d=$(oci_digest "$out/base.tar")
  want=${PINNED:-$(sed -n 's/^DERIVED_OCI_DIGEST=//p' "$out/base-info.txt")}
  [ -n "$want" ] || fail "nessun digest atteso per la base derivata"
  [ "$d" = "$want" ] || fail "digest della base derivata $d diverso da quello atteso $want"
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
mnt=$(sudo podman image mount "$IMG")
# il punto di montaggio dell'immagine è leggibile solo da root: tutto il percorso gira con sudo
lists() { sudo bash -c 'cd "$1" && find . -xdev -type f -print0 | xargs -0 -n 2000 sha256sum' _ "$1" | sed 's#  \./#  #' | LC_ALL=C sort -k2; }
lists "$co" > "$work/sha-commit.txt"
lists "$mnt" > "$work/sha-oci.txt"
sudo find "$co" -xdev -type l -printf '%P -> %l\n' | LC_ALL=C sort > "$work/links-commit.txt"
sudo find "$mnt" -xdev -type l -printf '%P -> %l\n' | LC_ALL=C sort > "$work/links-oci.txt"
sudo podman image umount "$IMG" >/dev/null
python3 -I - "$work" <<'PY' | tee -a "$info"
import sys
from pathlib import Path
d = Path(sys.argv[1])
def norm(p):
    # il commit ostree conserva la configurazione in usr/etc; l'OCI può presentarla in etc
    return "etc/" + p[len("usr/etc/"):] if p.startswith("usr/etc/") else p
def m(n):
    r = {}
    for ln in (d / n).read_text().splitlines():
        h, _, p = ln.partition("  "); r[norm(p)] = h
    return r
c, o = m("sha-commit.txt"), m("sha-oci.txt")
same = [p for p in c if p in o and c[p] == o[p]]
diff = [p for p in c if p in o and c[p] != o[p]]
only_c = sorted(set(c) - set(o)); only_o = sorted(set(o) - set(c))
lc = {norm(x) for x in (d / "links-commit.txt").read_text().splitlines()}; lo = {norm(x) for x in (d / "links-oci.txt").read_text().splitlines()}
print(f"EQUIV_FILES_COMMIT={len(c)}"); print(f"EQUIV_FILES_OCI={len(o)}")
print(f"EQUIV_SAME_CONTENT={len(same)}"); print(f"EQUIV_DIFFERENT_CONTENT={len(diff)}")
print(f"EQUIV_ONLY_IN_COMMIT={len(only_c)}"); print(f"EQUIV_ONLY_IN_OCI={len(only_o)}")
print(f"EQUIV_SYMLINKS_DIFF={len(lc ^ lo)}")
for label, items in (("solo nel commit", only_c), ("solo nell'OCI", only_o), ("contenuto diverso", diff)):
    for p in items[:15]:
        print(f"  {label}: {p}")
PY
grep -q '^EQUIV_DIFFERENT_CONTENT=0$' "$info" || fail "file con contenuto diverso fra commit verificato e OCI derivata"
grep -q '^EQUIV_ONLY_IN_COMMIT=0$' "$info" || fail "file del commit verificato assenti dall'OCI derivata"
oo=$(sed -n 's/^EQUIV_ONLY_IN_OCI=//p' "$info")
log "EQUIVALENCE=ok (contenuto identico per tutti i file del commit; file aggiunti dalla conversione: $oo)"
sudo rm -rf "$co" "$k"
echo "base B3 pronta: $out/base.tar ($d)"
