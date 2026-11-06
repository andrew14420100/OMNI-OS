#!/usr/bin/env bash
# Costruisce l'immagine N (versione $1) e il disco di prova mai avviato
# $VMWORK/disk-pristine.raw. Richiede l'ambiente di ci_prepare.sh.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
version=${1:?versione}
build_image "$version" localhost/omni-os:m1-ci
bash tests/vm/make_disk.sh localhost/omni-os:m1-ci "$VMWORK" "$TESTKEY.pub"
sudo chown "$(id -u):$(id -g)" "$VMWORK/disk.raw"
mv "$VMWORK/disk.raw" "$VMWORK/disk-pristine.raw"
