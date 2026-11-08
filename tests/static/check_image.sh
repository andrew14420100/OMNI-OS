#!/usr/bin/env bash
# Controlli statici sulla base dell'immagine (image/base.lock).
# B3: commit OSTree ufficiale Fedora fissato, chiave GPG fissata per impronta,
# immagine derivata solo locale. Una base che non soddisfa questi vincoli blocca la build.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
lock="image/base.lock"
get() { grep -E "^$1=" "$lock" | head -1 | cut -d= -f2-; }
fail() { echo "ERRORE: $*"; exit 1; }

status_line=$(get STATUS)
case "$status_line" in
  PENDING_OWNER_DECISION)
    [ -z "$(get BASE_IMAGE)" ] || fail "BASE_IMAGE valorizzato ma STATUS=PENDING_OWNER_DECISION"
    echo "check_image: OK (base non ancora approvata: build dell'immagine NON consentita)"
    echo "BUILD_ALLOWED=false"; exit 0 ;;
  APPROVED) ;;
  *) fail "STATUS non valido in $lock: '$status_line'" ;;
esac

for f in APPROVED_BY APPROVED_ON SCOPE BASE_KIND BASE_IMAGE; do [ -n "$(get "$f")" ] || fail "$f mancante in $lock"; done
case "$(get BASE_KIND)" in
  ostree-b3)
    [[ "$(get OSTREE_COMMIT)" =~ ^[0-9a-f]{64}$ ]] || fail "OSTREE_COMMIT deve essere un checksum completo di 64 caratteri"
    [[ "$(get GPG_FINGERPRINT)" =~ ^[0-9A-F]{40}$ ]] || fail "GPG_FINGERPRINT deve essere un'impronta completa di 40 caratteri esadecimali"
    [[ "$(get OSTREE_REMOTE_URL)" =~ ^https://[a-z0-9.]+\.fedoraproject\.org/ ]] || fail "OSTREE_REMOTE_URL deve essere un sito fedoraproject.org in HTTPS"
    [[ "$(get BASE_IMAGE)" =~ ^localhost/ ]] || fail "con B3 BASE_IMAGE deve essere un nome locale (localhost/...)"
    d=$(get DERIVED_OCI_DIGEST)
    if [ -n "$d" ] && ! [[ "$d" =~ ^sha256:[0-9a-f]{64}$ ]]; then fail "DERIVED_OCI_DIGEST non valido: '$d'"; fi
    [ "$(get SCOPE)" = VM_ONLY ] || fail "in M1 la base è ammessa solo con SCOPE=VM_ONLY"
    ;;
  *) fail "BASE_KIND non ammesso: '$(get BASE_KIND)' (la base A1 non è più autorizzata)" ;;
esac
grep -qE '^FROM \$\{BASE_IMAGE\}$' image/Containerfile || fail "il Containerfile deve usare FROM \${BASE_IMAGE}"
echo "check_image: OK (base B3: commit $(get OSTREE_COMMIT), versione $(get OSTREE_VERSION))"
echo "BUILD_ALLOWED=true"
