#!/usr/bin/env bash
# Attende che la VM risponda via SSH (o che scada il tempo). Mostra le ultime
# righe della console seriale in caso di fallimento.
# Uso: wait_ssh.sh <chiave-privata> <dir-di-lavoro> [timeout-secondi]
set -uo pipefail
key=$1 work=$2 timeout=${3:-900}
here=$(dirname "$0")
start=$(date +%s)
while true; do
  if bash "$here/vm_ssh.sh" "$key" true 2>/dev/null; then
    echo "SSH raggiungibile dopo $(( $(date +%s) - start )) s"; exit 0
  fi
  if ! kill -0 "$(cat "$work/qemu.pid" 2>/dev/null)" 2>/dev/null; then
    echo "ERRORE: QEMU non è più in esecuzione"; tail -n 80 "$work/serial.log" 2>/dev/null; exit 1
  fi
  if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then
    echo "ERRORE: SSH non raggiungibile entro ${timeout} s"; tail -n 80 "$work/serial.log" 2>/dev/null; exit 1
  fi
  sleep 10
done
