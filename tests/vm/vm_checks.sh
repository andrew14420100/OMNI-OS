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
# Unità che possono fallire SOLO perché l'hardware è virtuale, con motivazione.
# Qualsiasi altra unità fallita fa fallire il controllo.
#   mcelog.service: registra le Machine Check Exception della CPU; la CPU
#   virtuale di QEMU non le espone, quindi il demone termina con errore.
allowed_vm_failures="mcelog.service"
state=$(systemctl is-system-running 2>/dev/null || true)
echo "INFO systemctl is-system-running: $state"
mapfile -t failed < <(systemctl --failed --no-legend --plain | awk '{print $1}')
for u in "${failed[@]}"; do echo "INFO unità fallita: $u"; done
unexpected=()
for u in "${failed[@]}"; do
  case " $allowed_vm_failures " in *" $u "*) ;; *) unexpected+=("$u") ;; esac
done
case "$state" in
  running) echo "OK   systemd: avvio completato (running)" ;;
  degraded)
    if [ "${#unexpected[@]}" -eq 0 ]; then
      echo "OK   systemd: degraded solo per guasti attesi in VM (${failed[*]})"
    else
      echo "FAIL systemd: degraded con unità fallite non previste: ${unexpected[*]}"; fail=1
    fi ;;
  *) echo "FAIL systemd: stato '$state' (avvio non completato)"; fail=1 ;;
esac
check "graphical.target attivo" systemctl is-active graphical.target
dm=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
echo "INFO gestore di accesso configurato: ${dm:-nessuno}"
check "display-manager attivo (schermata di accesso)" systemctl is-active display-manager
check "NetworkManager attivo" systemctl is-active NetworkManager
check "rete: indirizzo IPv4 assegnato" bash -c 'ip -4 -o addr show scope global | grep -q inet'
echo "INFO kernel: $(uname -r)"
sb_var=$(find /sys/firmware/efi/efivars -name 'SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c' 2>/dev/null | head -1)
if [ -n "$sb_var" ]; then
  sb=$(od -An -t u1 -j 4 -N 1 "$sb_var" | tr -d ' ')
  echo "INFO Secure Boot (variabile EFI SecureBoot): $([ "$sb" = 1 ] && echo attivo || echo disattivo)"
else
  echo "INFO Secure Boot: variabile EFI non trovata"
fi
echo "INFO bootc status:"; bootc status 2>&1 | sed 's/^/  /'
echo "INFO rpm-ostree status:"; rpm-ostree status 2>&1 | sed 's/^/  /'

if [ "$fail" -eq 0 ]; then echo "vm_checks: OK"; else echo "vm_checks: FALLITO"; fi
exit "$fail"
