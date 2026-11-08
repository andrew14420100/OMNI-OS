#!/usr/bin/env bash
# P8: test di aggiornamento, rollback e gestione degli errori nella VM, eseguito
# separatamente per ciascun gestore (bootc oppure rpm-ostree), su un disco
# di prova dedicato. Orchestrato dall'host via SSH.
#
# Uso: update_test.sh <bootc|rpm-ostree> <chiave-privata> <dir-di-lavoro> <archivio-oci-N+1> <versione-N> <versione-N+1>
set -uo pipefail
client=$1 key=$2 work=$3 archive=$4 vN=$5 vN1=$6
here=$(dirname "$0")
ssh_vm() { bash "$here/vm_ssh.sh" "$key" "$@"; }
results="$work/update-$client.md"
fail=0
t0=$(date +%s)
rec() { # rec ESITO descrizione
  echo "| $1 | $2 | $(( $(date +%s) - t0 )) s |" >> "$results"
  echo "$1 $2"
  [ "$1" = OK ] || fail=1
}
# shellcheck disable=SC2016 # espansione voluta nella VM, non sull host
version() { ssh_vm '. /usr/lib/omni-os/build-info; echo "$OMNI_OS_VERSION"' 2>/dev/null; }
reboot_vm() {
  ssh_vm 'systemctl reboot' >/dev/null 2>&1 || true
  sleep 20
  bash "$here/wait_ssh.sh" "$key" "$work" 900 || return 1
  timeout 600 bash "$here/vm_ssh.sh" "$key" systemctl is-system-running --wait >/dev/null 2>&1 || true
}
status() {
  case "$client" in
    bootc) ssh_vm 'bootc status --format json' ;;
    rpm-ostree) ssh_vm 'rpm-ostree status --json' ;;
  esac
}

{
  echo "## P8 — $client"
  echo
  echo "| Esito | Passo | Tempo |"
  echo "|---|---|---|"
} > "$results"

if [ "$(version)" = "$vN" ]; then rec OK "versione iniziale $vN"; else rec FAIL "versione iniziale '$(version)' != $vN"; fi

# Copia dell'immagine N+1 nella VM (archivio OCI locale, nessun registry).
if scp -i "$key" -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
      "$archive" root@127.0.0.1:/var/tmp/omni-n1.tar; then
  rec OK "archivio N+1 copiato nella VM"
else
  rec FAIL "copia dell'archivio N+1"; exit 1
fi

# E1 — gestione errori: sorgente inesistente/corrotta. Deve fallire senza cambiare i deployment.
before=$(status | sha256sum)
ssh_vm 'head -c 1048576 /dev/urandom > /var/tmp/corrotto.tar'
case "$client" in
  bootc)      cmd='bootc switch --transport oci-archive /var/tmp/corrotto.tar' ;;
  rpm-ostree) cmd='rpm-ostree rebase ostree-unverified-image:oci-archive:/var/tmp/corrotto.tar' ;;
esac
if ssh_vm "$cmd" > "$work/e1-$client.log" 2>&1; then
  rec FAIL "E1 archivio corrotto accettato (atteso rifiuto)"
else
  rec OK "E1 archivio corrotto rifiutato (codice di uscita diverso da 0)"
fi
after=$(status | sha256sum)
if [ "$before" = "$after" ]; then rec OK "E1 deployment invariati dopo l'errore"; else rec FAIL "E1 deployment modificati dopo l'errore"; fi

# E2 — interruzione: aggiornamento preparato ma VM spenta brutalmente prima del riavvio.
case "$client" in
  bootc)      up='bootc switch --transport oci-archive /var/tmp/omni-n1.tar' ;;
  rpm-ostree) up='rpm-ostree rebase ostree-unverified-image:oci-archive:/var/tmp/omni-n1.tar' ;;
esac
if ssh_vm "$up" > "$work/e2-stage-$client.log" 2>&1; then rec OK "E2 aggiornamento preparato"; else rec FAIL "E2 preparazione aggiornamento"; fi
ssh_vm 'sync' || true
kill -9 "$(cat "$work/qemu.pid")" 2>/dev/null; sleep 3
bash "$here/boot_vm.sh" "$work/disk.raw" "$work" uefi >/dev/null
if bash "$here/wait_ssh.sh" "$key" "$work" 900 >/dev/null; then timeout 600 bash "$here/vm_ssh.sh" "$key" systemctl is-system-running --wait >/dev/null 2>&1; rec OK "E2 avvio dopo spegnimento forzato"; else rec FAIL "E2 avvio dopo spegnimento forzato"; exit 1; fi
v=$(version); echo "INFO versione dopo spegnimento forzato: $v" | tee -a "$results"
case "$v" in "$vN"|"$vN1") rec OK "E2 sistema coerente dopo l'interruzione (versione $v)";; *) rec FAIL "E2 versione inattesa '$v'";; esac
status > "$work/e2-status-$client.json" 2>&1 || true

# U1 — aggiornamento a N+1 e riavvio (ripete la preparazione se l'interruzione l'ha scartata).
if [ "$(version)" != "$vN1" ]; then
  if ssh_vm "$up" > "$work/u1-$client.log" 2>&1; then rec OK "U1 aggiornamento preparato"; else rec FAIL "U1 preparazione"; fi
  if reboot_vm >/dev/null; then rec OK "U1 riavvio"; else rec FAIL "U1 riavvio"; fi
fi
if [ "$(version)" = "$vN1" ]; then rec OK "U1 versione dopo aggiornamento: $vN1"; else rec FAIL "U1 versione '$(version)' != $vN1"; fi

# R1 — rollback al deployment precedente e riavvio.
case "$client" in
  bootc)      rb='bootc rollback' ;;
  rpm-ostree) rb='rpm-ostree rollback' ;;
esac
if ssh_vm "$rb" > "$work/r1-$client.log" 2>&1; then rec OK "R1 rollback impostato"; else rec FAIL "R1 rollback"; fi
if reboot_vm >/dev/null; then rec OK "R1 riavvio"; else rec FAIL "R1 riavvio"; fi
if [ "$(version)" = "$vN" ]; then rec OK "R1 versione dopo rollback: $vN"; else rec FAIL "R1 versione '$(version)' != $vN"; fi
if ssh_vm 'systemctl is-active display-manager' >/dev/null 2>&1; then rec OK "R1 display-manager attivo dopo rollback"; else rec FAIL "R1 display-manager non attivo dopo rollback"; fi
status > "$work/final-status-$client.json" 2>&1 || true

echo >> "$results"
echo "Esito complessivo $client: $([ $fail -eq 0 ] && echo SUPERATO || echo FALLITO)" >> "$results"
cat "$results"
exit "$fail"
