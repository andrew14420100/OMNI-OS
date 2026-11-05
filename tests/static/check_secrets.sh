#!/usr/bin/env bash
# Cerca segreti e materiale sensibile nei file tracciati da Git.
# Il repository è pubblico (REQ-PUB-03): qualsiasi risultato blocca la CI.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

self="tests/static/check_secrets.sh"
patterns='(BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|xox[abp]-[A-Za-z0-9-]{10,}|[0-9]{6}-[0-9]{6}-[0-9]{6}-[0-9]{6}-[0-9]{6}-[0-9]{6}-[0-9]{6}-[0-9]{6}|(api[_-]?key|secret[_-]?key|password|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,})'

status=0
if git grep -nIiE "$patterns" -- . ":(exclude)$self"; then
  echo "ERRORE: possibili segreti trovati (vedi sopra)"
  status=1
fi

# File che non devono mai essere nel repository (chiavi private, chiavi cosign, MOK).
if git ls-files | grep -nE '(^|/)(cosign\.key|.*\.key|.*\.p12|.*\.pfx|MOK\.priv|.*private.*\.pem)$'; then
  echo "ERRORE: file di chiave privata tracciati"
  status=1
fi

[ "$status" -eq 0 ] && echo "check_secrets: OK (nessun segreto o file di chiave privata trovato)"
exit "$status"
