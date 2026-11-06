#!/usr/bin/env bash
# P5: crea un disco virtuale di PROVA (raw, sparso) installando l'immagine OMNI
# con "bootc install to-disk --via-loopback". Solo per VM: il file disco resta
# nel job della CI e non viene pubblicato.
#
# Invocazione secondo la documentazione di bootc: storage predefinito di podman
# dell'host montato come /var/lib/containers.
#
# Uso: make_disk.sh <immagine> <dir-uscita> <chiave-pubblica-ssh-di-prova>
set -euo pipefail
image=$1 outdir=$2 pubkey=$3
size=${DISK_SIZE:-30G}

mkdir -p "$outdir"
cp "$pubkey" "$outdir/test_key.pub"
truncate -s "$size" "$outdir/disk.raw"

# - console=ttyS0: log di avvio sulla console seriale (letto dai test)
# - systemd.wants=sshd.service: avvia sshd solo su questo disco di prova,
#   senza modificare l'immagine OMNI
sudo podman run --rm --privileged --pid=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev \
  -v /var/lib/containers:/var/lib/containers \
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
