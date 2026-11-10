#!/usr/bin/env bash
# Costruisce l'immagine OMNI personale (M1 + OMNI Shell) da un albero sorgente.
# Uso: build_personale.sh <albero-sorgente> <tag-immagine> <versione>
# Usato sia per la versione di riferimento (0.2.0, commit fissato) sia per quella nuova.
set -euo pipefail
src=$(cd "$1" && pwd) tag=$2 ver=$3
cd "$src"
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
build_image "$ver" "localhost/omni-os:m1-$ver"
bash tests/vm/build_shell_bundle.sh "localhost/omni-os:m1-$ver" "$RUNNER_TEMP/shell-$ver"
rm -rf image/personale/omni-shell && cp -r "$RUNNER_TEMP/shell-$ver/pkg" image/personale/omni-shell
$PODMAN build --build-arg OMNI_IMAGE="localhost/omni-os:m1-$ver" -t "$tag" image/personale/ > "$VMWORK/build-personale-$ver.log" 2>&1 \
  || { tail -40 "$VMWORK/build-personale-$ver.log"; exit 1; }
$PODMAN image inspect --format '{{.Id}}' "$tag"
