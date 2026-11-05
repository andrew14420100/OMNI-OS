#!/usr/bin/env bash
# P4: verifica del contenuto dell'immagine. Va eseguito DENTRO il container
# dell'immagine OMNI costruita:
#   podman run --rm -v ./tests/vm:/t:ro,Z <immagine> bash /t/check_image_content.sh <versione>
set -uo pipefail
expected_version="${1:?versione OMNI attesa}"
fail=0

# check "descrizione" comando [argomenti...]: esegue il comando e registra l'esito.
check() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then echo "OK   $desc"; else echo "FAIL $desc"; fail=1; fi
}

if [ ! -f /usr/lib/omni-os/build-info ]; then
  echo "FAIL /usr/lib/omni-os/build-info mancante (eseguire dentro l'immagine OMNI)"; exit 1
fi
# shellcheck disable=SC1091
. /usr/lib/omni-os/build-info
check "build-info: versione '$OMNI_OS_VERSION' = '$expected_version'" test "$OMNI_OS_VERSION" = "$expected_version"
check "build-info: stadio '$OMNI_OS_STAGE'" test "$OMNI_OS_STAGE" = "M1 prototipo, solo macchina virtuale"

# shellcheck disable=SC1091
. /usr/lib/os-release
check "os-release: ID=$ID" test "$ID" = "fedora"
check "os-release: VERSION_ID=$VERSION_ID" test "$VERSION_ID" = "45"
check "os-release: VARIANT_ID=${VARIANT_ID:-}" test "${VARIANT_ID:-}" = "kinoite"

mapfile -t kernels < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
check "kernel presenti: ${kernels[*]:-nessuno}" test "${#kernels[@]}" -ge 1
for k in "${kernels[@]}"; do
  check "vmlinuz per $k" test -f "/usr/lib/modules/$k/vmlinuz"
done

for bin in bootc rpm-ostree ostree systemctl; do
  check "comando $bin presente" command -v "$bin"
done
for pkg in plasma-workspace sddm kwin NetworkManager; do
  check "pacchetto $pkg installato ($(rpm -q "$pkg" 2>/dev/null || echo assente))" rpm -q "$pkg"
done

if [ "$fail" -eq 0 ]; then echo "check_image_content: OK"; else echo "check_image_content: FALLITO"; fi
exit "$fail"
