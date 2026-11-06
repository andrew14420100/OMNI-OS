#!/usr/bin/env bash
# AC-M1-07: raccoglie le informazioni di un'immagine per il confronto fra build.
# Uso: repro_collect.sh <immagine-locale> <dir-uscita>
set -euo pipefail
img=$1 out=$2; mkdir -p "$out"
id=$(sudo podman image inspect --format '{{.Id}}' "$img"); echo "$id" > "$out/image-id.txt"
created=$(sudo podman image inspect --format '{{.Created}}' "$img"); echo "$created" > "$out/created.txt"
sudo podman image inspect --format '{{json .RootFS.Layers}}' "$img" | jq -r '.[]' > "$out/layers.txt"
sudo podman run --rm "$img" rpm -qa --qf '%{NEVRA}\n' | LC_ALL=C sort > "$out/rpm.txt"
mnt=$(sudo podman image mount "$img")
# metadati: percorso, tipo, permessi, proprietario, gruppo, dimensione, destinazione del link
sudo find "$mnt" -xdev -printf '%P\t%y\t%m\t%U\t%G\t%s\t%l\n' | LC_ALL=C sort > "$out/meta.tsv"
sudo find "$mnt" -xdev -printf '%P\t%T@\n' | LC_ALL=C sort > "$out/mtime.tsv"
(cd "$mnt" && sudo find . -xdev -type f -print0 | sudo xargs -0 -n 2000 sha256sum) | sed 's#  \./#  #' | LC_ALL=C sort -k2 > "$out/sha256.txt"
sudo podman image umount "$img" >/dev/null
wc -l "$out"/*.txt "$out"/*.tsv
