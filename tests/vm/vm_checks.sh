#!/usr/bin/env bash
# P6/P7: controlli eseguiti DENTRO la VM avviata (via SSH, come root).
# Uso (nella VM): bash vm_checks.sh <versione-OMNI-attesa>
set -uo pipefail
expected_version=${1:?versione attesa}
fail=0
check() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then echo "OK   $desc"; else echo "FAIL $desc"; fail=1; fi
}

# shellcheck disable=SC1091
. /usr/lib/omni-os/build-info
check "build-info versione $OMNI_OS_VERSION = $expected_version" test "$OMNI_OS_VERSION" = "$expected_version"
check "avvio in modalità UEFI (/sys/firmware/efi presente)" test -d /sys/firmware/efi
check "sistema ostree avviato (/run/ostree-booted)" test -e /run/ostree-booted
state=$(systemctl is-system-running 2>/dev/null || true)
echo "INFO systemctl is-system-running: $state"
case "$state" in running|degraded) echo "OK   systemd: stato $state";; *) echo "FAIL systemd: stato '$state'"; fail=1;; esac
systemctl --failed --no-legend --plain | sed 's/^/INFO unità fallita: /'
check "graphical.target attivo" systemctl is-active graphical.target
dm=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
echo "INFO gestore di accesso configurato: ${dm:-nessuno}"
check "display-manager attivo (schermata di accesso)" systemctl is-active display-manager
check "NetworkManager attivo" systemctl is-active NetworkManager
check "rete: indirizzo IPv4 assegnato" bash -c 'ip -4 -o addr show scope global | grep -q inet'
echo "INFO kernel: $(uname -r)"
echo "INFO Secure Boot: $(mokutil --sb-state 2>/dev/null || echo 'mokutil non disponibile')"
echo "INFO bootc status:"; bootc status 2>&1 | sed 's/^/  /'
echo "INFO rpm-ostree status:"; rpm-ostree status 2>&1 | sed 's/^/  /'

if [ "$fail" -eq 0 ]; then echo "vm_checks: OK"; else echo "vm_checks: FALLITO"; fi
exit "$fail"
