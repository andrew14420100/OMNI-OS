#!/usr/bin/env bash
# Esegue un comando nella VM di prova via SSH (chiave effimera di prova).
# Uso: vm_ssh.sh <chiave-privata-di-prova> <comando...>
set -euo pipefail
key=$1; shift
exec ssh -i "$key" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=10 -o BatchMode=yes -o LogLevel=ERROR root@127.0.0.1 "$@"
