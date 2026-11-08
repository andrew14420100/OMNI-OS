#!/usr/bin/env bash
# P6: avvia il disco di prova in QEMU con firmware UEFI (OVMF), in background.
# Console seriale su file, monitor QMP su socket, SSH inoltrato su localhost:2222.
#
# Uso: boot_vm.sh <disco> <dir-di-lavoro> [secureboot]
set -euo pipefail
disk=$1 work=$2 mode=${3:-uefi}
mkdir -p "$work"

case "$mode" in
  uefi)       code=/usr/share/OVMF/OVMF_CODE_4M.fd;          vars=/usr/share/OVMF/OVMF_VARS_4M.fd ;;
  secureboot) code=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd;  vars=/usr/share/OVMF/OVMF_VARS_4M.ms.fd ;;
  *) echo "modalità sconosciuta: $mode"; exit 2 ;;
esac
if [ ! -f "$code" ] || [ ! -f "$vars" ]; then echo "firmware OVMF mancante: $code / $vars"; exit 1; fi
cp "$vars" "$work/OVMF_VARS.fd"

accel=tcg
if [ -w /dev/kvm ]; then accel=kvm; fi
echo "accelerazione: $accel, firmware: $mode"

machine=q35
if [ "$mode" = secureboot ]; then machine=q35,smm=on; fi

extra=()
if [ "$mode" = secureboot ]; then
  extra+=(-global "driver=cfi.pflash01,property=secure,value=on")
fi

qemu-system-x86_64 \
  -name omni-m1-test -machine "$machine",accel="$accel" -cpu max \
  -smp "${VM_CPUS:-2}" -m "${VM_MEM:-6144}" \
  "${extra[@]}" \
  -drive if=pflash,format=raw,unit=0,readonly=on,file="$code" \
  -drive if=pflash,format=raw,unit=1,file="$work/OVMF_VARS.fd" \
  -drive if=virtio,format=raw,file="$disk" \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 \
  -device virtio-vga -display none \
  -serial file:"$work/serial.log" \
  -qmp unix:"$work/qmp.sock",server=on,wait=off \
  -daemonize -pidfile "$work/qemu.pid"

echo "QEMU avviato, pid $(cat "$work/qemu.pid")"
