#!/usr/bin/env bash
# P5: crea un disco virtuale di PROVA (raw, sparso) installando l'immagine OMNI
# con "bootc install to-disk --via-loopback". Solo per VM: il file disco resta
# nel job della CI e non viene pubblicato.
#
# Uso: make_disk.sh <podman-root> <immagine> <dir-uscita> <chiave-pubblica-ssh-di-prova>
set -euo pipefail
storage=$1 image=$2 outdir=$3 pubkey=$4
size=${DISK_SIZE:-30G}

mkdir -p "$outdir"
cp "$pubkey" "$outdir/test_key.pub"
truncate -s "$size" "$outdir/disk.raw"

# - console=ttyS0: log di avvio sulla console seriale (letto dai test)
# - systemd.wants=sshd.service: avvia sshd solo su questo disco di prova,
#   senza modificare l'immagine OMNI
sudo podman --root "$storage" run --rm --privileged --pid=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev \
  -v "$storage":/var/lib/containers/storage \
  -v "$outdir":/output \
  "$image" \
  bootc install to-disk \
    --via-loopback \
    --generic-image \
    --filesystem xfs \
    --root-ssh-authorized-keys /output/test_key.pub \
    --karg console=ttyS0,115200n8 \
    --karg systemd.wants=sshd.service \
    /output/disk.raw

ls -lsh "$outdir/disk.raw"
