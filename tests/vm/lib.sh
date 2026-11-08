#!/usr/bin/env bash
# Funzioni comuni ai test M1 in VM (da includere con: . tests/vm/lib.sh).
# Usano le variabili d'ambiente impostate da ci_prepare.sh:
#   PODMAN, BASE, VMWORK, TESTKEY
# Nessuna funzione modifica qualcosa fuori dal runner effimero o dalla VM.

LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REG_HOST=127.0.0.1:5000      # registro locale visto dall'host (solo loopback)
REG_VM=10.0.2.2:5000         # lo stesso registro visto dalla VM (rete utente di QEMU)
REPO=omni-os

# --- Risultati -------------------------------------------------------------
# res_init <file> <titolo>; rec <OK|FAIL|INFO> <descrizione>
res_init() { RESULTS=$1; RES_FAIL=0; RES_T0=$(date +%s); { echo "## $2"; echo; echo "| Esito | Passo | Tempo |"; echo "|---|---|---|"; } > "$RESULTS"; }
rec() {
  local t=$(( $(date +%s) - RES_T0 ))
  echo "| $1 | $2 | ${t} s |" >> "$RESULTS"
  echo "$1 $2"
  if [ "$1" = FAIL ]; then RES_FAIL=1; fi
}
res_end() { echo >> "$RESULTS"; if [ "$RES_FAIL" -eq 0 ]; then echo "Esito complessivo: SUPERATO" >> "$RESULTS"; else echo "Esito complessivo: FALLITO" >> "$RESULTS"; fi; cat "$RESULTS"; return "$RES_FAIL"; }
# expect_ok/expect_fail <descrizione> <comando...>: il comando deve riuscire / fallire
expect_ok()   { local d=$1; shift; if "$@" >> "$LOG" 2>&1; then rec OK "$d"; else rec FAIL "$d"; fi; }
expect_fail() { local d=$1; shift; if "$@" >> "$LOG" 2>&1; then rec FAIL "$d (accettato, atteso rifiuto)"; else rec OK "$d (rifiutato come atteso)"; fi; }

# --- VM --------------------------------------------------------------------
vm_ssh() { bash "$LIB_DIR/vm_ssh.sh" "$TESTKEY" "$@"; }
vm_scp() { scp -i "$TESTKEY" -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$@"; }
# vm_fresh <dir>: copia il disco mai avviato e avvia la VM (UEFI), attende la fine dell'avvio
vm_fresh() {
  local w=$1; mkdir -p "$w"
  cp --sparse=always "$VMWORK/disk-pristine.raw" "$w/disk.raw"
  bash "$LIB_DIR/boot_vm.sh" "$w/disk.raw" "$w" uefi >/dev/null
  vm_ready "$w"
}
# vm_ready <dir>: attende SSH e 'systemctl is-system-running --wait' (max 10 min)
vm_ready() {
  bash "$LIB_DIR/wait_ssh.sh" "$TESTKEY" "$1" 900 >/dev/null || return 1
  timeout 600 bash "$LIB_DIR/vm_ssh.sh" "$TESTKEY" systemctl is-system-running --wait >/dev/null 2>&1 || true
}
# vm_reboot <dir>: riavvio pulito; ritorna i secondi fino a sistema pronto in REBOOT_S
vm_reboot() {
  local t0; t0=$(date +%s)
  vm_ssh 'systemctl reboot' >/dev/null 2>&1 || true
  sleep 15
  vm_ready "$1" || return 1
  export REBOOT_S=$(( $(date +%s) - t0 ))
}
vm_stop() { if [ -f "$1/qemu.pid" ]; then kill "$(cat "$1/qemu.pid")" 2>/dev/null || true; sleep 3; fi; rm -f "$1/disk.raw"; }
# shellcheck disable=SC2016 # espansione voluta nella VM
vm_version() { vm_ssh '. /usr/lib/omni-os/build-info; echo "$OMNI_OS_VERSION"' 2>/dev/null; }
vm_dm_active() { vm_ssh systemctl is-active display-manager >/dev/null 2>&1; }
# check_booted <versione-attesa> <descrizione>
check_booted() {
  local v; v=$(vm_version)
  if [ "$v" = "$1" ]; then rec OK "$2: avviato su $v"; else rec FAIL "$2: versione '$v' invece di $1"; fi
  if vm_dm_active; then rec OK "$2: gestore di accesso attivo"; else rec FAIL "$2: gestore di accesso non attivo"; fi
}

# --- Immagini --------------------------------------------------------------
# build_image <versione> <tag> [argomenti podman build aggiuntivi...]
build_image() {
  local v=$1 t=$2; shift 2
  $PODMAN build --build-arg BASE_IMAGE="$BASE" --build-arg OMNI_VERSION="$v" -t "$t" "$@" image/ > "$VMWORK/build-$v.log" 2>&1 \
    || { tail -40 "$VMWORK/build-$v.log"; return 1; }
}

# --- Registro locale effimero (solo loopback) -------------------------------
# Pacchetto Ubuntu docker-registry con configurazione minima scritta per intero:
# nessuna autenticazione, ascolto SOLO su 127.0.0.1, dati in cartella temporanea.
registry_start() {
  if ! command -v docker-registry >/dev/null 2>&1; then sudo apt-get install -y -qq docker-registry >/dev/null 2>&1; fi
  sudo mkdir -p /var/tmp/omni-registry
  sudo tee /etc/docker/registry/config.yml >/dev/null <<'YAML'
version: 0.1
log:
  level: warn
storage:
  filesystem:
    rootdirectory: /var/tmp/omni-registry
  delete:
    enabled: true
http:
  addr: 127.0.0.1:5000
YAML
  sudo chown -R docker-registry: /var/tmp/omni-registry 2>/dev/null || true
  sudo systemctl restart docker-registry
  for _ in $(seq 1 60); do curl -fsS "http://$REG_HOST/v2/" >/dev/null 2>&1 && return 0; sleep 1; done
  sudo journalctl -u docker-registry --no-pager -n 30; return 1
}
registry_stop()  { sudo systemctl stop docker-registry; }
registry_resume() { sudo systemctl start docker-registry; for _ in $(seq 1 30); do curl -fsS "http://$REG_HOST/v2/" >/dev/null 2>&1 && return 0; sleep 1; done; return 1; }
# reg_push <immagine-locale> <tag>: carica e stampa il digest
reg_push() {
  $PODMAN push --tls-verify=false --digestfile "$VMWORK/push.digest" "$1" "docker://$REG_HOST/$REPO:$2" >> "$LOG" 2>&1 || return 1
  cat "$VMWORK/push.digest"
}

# --- Configurazione containers nella VM -------------------------------------
# vm_containers_config <unsigned|signed> [chiave-pubblica-locale]
#   unsigned: registro insicuro consentito, policy che accetta tutto (test di rollback, non di firma)
#   signed:   policy che rifiuta tutto tranne $REG_VM/$REPO firmato con la chiave indicata
vm_containers_config() {
  local mode=$1 pub=${2:-}
  vm_ssh "mkdir -p /etc/pki/containers /etc/containers/registries.d /etc/containers/registries.conf.d
printf '[[registry]]\nlocation = \"$REG_VM\"\ninsecure = true\n' > /etc/containers/registries.conf.d/50-omni-prova.conf
printf 'docker:\n  $REG_VM:\n    use-sigstore-attachments: true\n' > /etc/containers/registries.d/50-omni-prova.yaml" >> "$LOG" 2>&1
  if [ "$mode" = signed ]; then
    vm_scp "$pub" root@127.0.0.1:/etc/pki/containers/omni-prova.pub >> "$LOG" 2>&1
    vm_ssh 'cat > /etc/containers/policy.json' <<JSON
{"default":[{"type":"reject"}],
 "transports":{"docker":{"$REG_VM/$REPO":[{"type":"sigstoreSigned","keyPath":"/etc/pki/containers/omni-prova.pub","signedIdentity":{"type":"matchRepository"}}]},
               "docker-daemon":{"":[{"type":"reject"}]}}}
JSON
  else
    vm_ssh 'cat > /etc/containers/policy.json' <<'JSON'
{"default":[{"type":"insecureAcceptAnything"}]}
JSON
  fi
}

# --- Gestori di aggiornamento ------------------------------------------------
# mgr_switch <bootc|rpm-ostree> <riferimento-registro-VM> <unsigned|signed>
mgr_switch() {
  local c=$1 ref=$2 mode=$3
  case "$c:$mode" in
    bootc:unsigned)      vm_ssh "bootc switch $ref" ;;
    bootc:signed)        vm_ssh "bootc switch --enforce-container-sigpolicy $ref" ;;
    rpm-ostree:unsigned) vm_ssh "rpm-ostree rebase ostree-unverified-registry:$ref" ;;
    rpm-ostree:signed)   vm_ssh "rpm-ostree rebase ostree-image-signed:docker://$ref" ;;
  esac
}
mgr_upgrade() { case "$1" in bootc) vm_ssh "bootc upgrade" ;; rpm-ostree) vm_ssh "rpm-ostree upgrade" ;; esac; }
mgr_status()  { case "$1" in bootc) vm_ssh "bootc status --format json" ;; rpm-ostree) vm_ssh "rpm-ostree status --json" ;; esac; }
# staged_version: versione dell'aggiornamento preparato (vuoto se nessuno)
staged_version() {
  vm_ssh "rpm-ostree status --json" 2>/dev/null | jq -r '[.deployments[] | select(.staged == true) | .version][0] // empty'
}

# --- Firma (chiavi effimere) --------------------------------------------------
# keys_new <dir>: crea una coppia cosign effimera (password casuale mascherata nei log)
keys_new() {
  mkdir -p "$1"; chmod 700 "$1"
  COSIGN_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$COSIGN_PASSWORD"; fi
  export COSIGN_PASSWORD
  (cd "$1" && "$COSIGN" generate-key-pair --output-key-prefix prova >/dev/null 2>&1)
}
# sign_digest <dir-chiavi> <digest>: firma senza registro di trasparenza, identità vista dalla VM
sign_digest() {
  "$COSIGN" sign --yes --key "$1/prova.key" --tlog-upload=false \
    --sign-container-identity "$REG_VM/$REPO" \
    --allow-insecure-registry --allow-http-registry "$REG_HOST/$REPO@$2" >> "$LOG" 2>&1
}
keys_destroy() { shred -u "$1"/*.key 2>/dev/null; rm -rf "$1"; unset COSIGN_PASSWORD; }
# cosign_install: cosign 2.6.5 con checksum fissato
cosign_install() {
  COSIGN=$RUNNER_TEMP/cosign
  curl -sSLf --retry 5 --retry-delay 5 --retry-all-errors -o "$COSIGN" https://github.com/sigstore/cosign/releases/download/v2.6.5/cosign-linux-amd64
  echo "c3b4f5410e608af03a5eb0aaac84a4313d8da131248e08ff1759ac70c79d1644  $COSIGN" | sha256sum -c - >/dev/null
  chmod +x "$COSIGN"
}
