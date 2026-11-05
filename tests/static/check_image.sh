#!/usr/bin/env bash
# Controlli statici sull'immagine: la base deve essere approvata dal proprietario
# e fissata per digest prima di qualsiasi build (docs/11-m1/verifica-base-oci.md).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

lock="image/base.lock"
status_line=$(grep -E '^STATUS=' "$lock" | cut -d= -f2)
base=$(grep -E '^BASE_IMAGE=' "$lock" | cut -d= -f2-)

case "$status_line" in
  PENDING_OWNER_DECISION)
    if [ -n "$base" ]; then
      echo "ERRORE: BASE_IMAGE valorizzato ma STATUS=PENDING_OWNER_DECISION"; exit 1
    fi
    echo "check_image: OK (base non ancora approvata: build dell'immagine NON consentita)"
    echo "BUILD_ALLOWED=false"
    ;;
  APPROVED)
    if ! [[ "$base" =~ ^[a-z0-9./_-]+@sha256:[0-9a-f]{64}$ ]]; then
      echo "ERRORE: BASE_IMAGE deve essere fissato per digest (repo@sha256:<64 hex>): '$base'"; exit 1
    fi
    for f in APPROVED_BY APPROVED_ON; do
      grep -qE "^$f=.+" "$lock" || { echo "ERRORE: $f mancante in $lock"; exit 1; }
    done
    echo "check_image: OK (base approvata: $base)"
    echo "BUILD_ALLOWED=true"
    ;;
  *)
    echo "ERRORE: STATUS non valido in $lock: '$status_line'"; exit 1
    ;;
esac

grep -qE '^FROM \$\{BASE_IMAGE\}$' image/Containerfile || {
  echo "ERRORE: il Containerfile deve usare FROM \${BASE_IMAGE}"; exit 1; }
