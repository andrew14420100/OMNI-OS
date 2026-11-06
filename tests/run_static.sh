#!/usr/bin/env bash
# Esegue tutti i controlli statici (usato dalla CI e in locale).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
python3 tests/static/check_docs.py
bash tests/static/check_secrets.sh
bash tests/static/check_image.sh
