#!/usr/bin/env bash
# Verifica delle risorse del runner prima di qualsiasi build (percorso build §3).
# Scrive un riepilogo e le variabili di uscita in $GITHUB_OUTPUT (se presente).
set -euo pipefail

out="${GITHUB_OUTPUT:-/dev/null}"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

kvm=no
if [ -e /dev/kvm ]; then kvm=yes; fi
virt_flags=$(grep -cE 'vmx|svm' /proc/cpuinfo || true)
cpus=$(nproc)
mem_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)

# Spazio libero (GB) sulle due posizioni candidate per lo storage di podman.
free_root=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
free_mnt=0
if mountpoint -q /mnt 2>/dev/null || [ -d /mnt ]; then
  free_mnt=$(df -BG --output=avail /mnt | tail -1 | tr -dc '0-9')
fi
if [ "$free_mnt" -gt "$free_root" ]; then storage_dir=/mnt/omni-containers; free_best=$free_mnt
else storage_dir=/var/tmp/omni-containers; free_best=$free_root; fi

podman_v=$(podman --version 2>/dev/null || echo "assente")
qemu_v=$(qemu-system-x86_64 --version 2>/dev/null | head -1 || echo "assente")

{
  echo "## Verifica del runner"
  echo "| Risorsa | Valore |"
  echo "|---|---|"
  echo "| CPU | $cpus (flag di virtualizzazione: $virt_flags) |"
  echo "| RAM | ${mem_gb} GB |"
  echo "| /dev/kvm | $kvm |"
  echo "| Spazio libero / | ${free_root} GB |"
  echo "| Spazio libero /mnt | ${free_mnt} GB |"
  echo "| Storage podman scelto | $storage_dir (${free_best} GB liberi) |"
  echo "| podman | $podman_v |"
  echo "| qemu-system-x86_64 | $qemu_v |"
} >> "$summary"

{
  echo "kvm=$kvm"
  echo "cpus=$cpus"
  echo "mem_gb=$mem_gb"
  echo "free_gb=$free_best"
  echo "storage_dir=$storage_dir"
} >> "$out"

echo "kvm=$kvm cpus=$cpus mem_gb=$mem_gb free_gb=$free_best storage_dir=$storage_dir podman='$podman_v'"

min_free=${MIN_FREE_GB:-30}
if [ "$free_best" -lt "$min_free" ]; then
  echo "ERRORE: spazio insufficiente (${free_best} GB < ${min_free} GB)"; exit 1
fi
