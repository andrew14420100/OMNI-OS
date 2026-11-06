#!/usr/bin/env bash
# Preparazione comune dei job M1 sul runner GitHub Actions (effimero):
# spazio disco, base B3 verificata (caricata dalla cache del job 'base'), e, se NEED_VM=1,
# KVM, QEMU/OVMF, ImageMagick e chiave SSH effimera di prova.
# Scrive PODMAN, BASE, VMWORK, TESTKEY in $GITHUB_ENV.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
need_vm=${NEED_VM:-1}

out=$(bash tests/static/check_image.sh); echo "$out"
echo "$out" | grep -qx 'BUILD_ALLOWED=true' || { echo "ERRORE: build non consentita"; exit 1; }
base=$(grep -E '^BASE_IMAGE=' image/base.lock | cut -d= -f2-)

sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL /usr/local/share/boost
sudo docker image prune -af >/dev/null 2>&1 || true
MIN_FREE_GB=${MIN_FREE_GB:-30} bash tests/vm/runner_check.sh

mkdir -p "$RUNNER_TEMP/vm"
if [ "$need_vm" = 1 ]; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq qemu-system-x86 ovmf imagemagick >/dev/null
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger --name-match=kvm
  sudo udevadm settle || true
  # la regola udev si applica in modo asincrono: attesa breve prima del controllo
  for _ in $(seq 1 20); do [ -w /dev/kvm ] && break; sleep 0.5; done
  ls -l /dev/kvm
  test -w /dev/kvm || { echo "ERRORE: /dev/kvm non accessibile"; exit 1; }
  # chiave effimera: generata qui, mai salvata né pubblicata, distrutta con il runner
  ssh-keygen -q -t ed25519 -N '' -C omni-m1-ci-effimera -f "$RUNNER_TEMP/testkey"
  qemu-system-x86_64 --version | head -1
fi

# Base B3: archivio OCI derivato, ripristinato dalla cache dal workflow e
# caricato solo se il digest coincide con quello atteso (base_b3.sh load).
bash tests/vm/base_b3.sh load "$RUNNER_TEMP/base-b3"

{
  echo "PODMAN=sudo podman"
  echo "BASE=$base"
  echo "VMWORK=$RUNNER_TEMP/vm"
  echo "TESTKEY=$RUNNER_TEMP/testkey"
} >> "$GITHUB_ENV"
