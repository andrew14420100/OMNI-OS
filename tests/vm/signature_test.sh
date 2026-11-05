#!/usr/bin/env bash
# P9: verifica delle firme con chiavi EFFIMERE di prova (generate e distrutte nel job).
# Registro OCI locale effimero solo su 127.0.0.1 del runner (pacchetto Ubuntu
# docker-registry): nessuna pubblicazione all'esterno. Firma cosign senza
# registro di trasparenza pubblico (--tlog-upload=false).
#
# Dalla VM il registro è raggiungibile come 10.0.2.2:5000 (rete utente di QEMU);
# la policy usa remapIdentity perché la firma è fatta sul nome 127.0.0.1:5000.
#
# Uso: signature_test.sh <podman-cmd> <img-firmata> <img-non-firmata> <chiave-ssh> <dir-lavoro> <cosign> <versione-attesa-dopo-switch>
set -uo pipefail
podman_cmd=$1 img_signed=$2 img_unsigned=$3 key=$4 work=$5 cosign=$6 v_signed=$7
here=$(dirname "$0")
ssh_vm() { bash "$here/vm_ssh.sh" "$key" "$@"; }
results="$work/p9-firma.md"
fail=0
rec() { echo "| $1 | $2 |" >> "$results"; echo "$1 $2"; [ "$1" = OK ] || fail=1; }
expect_fail() { local d=$1; shift; if "$@" >> "$work/p9.log" 2>&1; then rec FAIL "$d (accettato, atteso rifiuto)"; else rec OK "$d (rifiutato come atteso)"; fi; }
expect_ok()   { local d=$1; shift; if "$@" >> "$work/p9.log" 2>&1; then rec OK "$d"; else rec FAIL "$d"; fi; }
{ echo "## P9 — verifica delle firme (chiavi effimere)"; echo; echo "| Esito | Passo |"; echo "|---|---|"; } > "$results"
mkdir -p "$work/keys"; chmod 700 "$work/keys"

# --- Registro locale effimero (solo loopback) ---
sudo apt-get install -y -qq docker-registry 2>&1 | tee -a "$work/p9.log" >/dev/null
cfg=/etc/docker/registry/config.yml
echo "--- configurazione del pacchetto (sostituita):"; sudo grep -nE 'addr|auth|htpasswd|realm' "$cfg" 2>&1 || true
# Configurazione minima scritta per intero: nessuna autenticazione (il pacchetto
# Ubuntu abilita htpasswd e risponde 401), ascolto SOLO su loopback, dati in una
# cartella temporanea del job.
sudo mkdir -p /var/tmp/omni-registry
sudo tee "$cfg" >/dev/null <<'YAML'
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
echo "--- configurazione applicata:"; sudo cat "$cfg"
sudo systemctl restart docker-registry || true
for _ in $(seq 1 60); do curl -fsS http://127.0.0.1:5000/v2/ >/dev/null 2>&1 && break; sleep 1; done
if ! curl -fsS http://127.0.0.1:5000/v2/ >/dev/null 2>&1; then
  echo "--- diagnosi registro:"
  sudo systemctl status docker-registry --no-pager -l 2>&1 | tail -20 || true
  sudo journalctl -u docker-registry --no-pager -n 40 2>&1 || true
  sudo ss -ltnp 2>&1 | grep -E ':5000|registry' || echo "nessun processo in ascolto su :5000"
fi
expect_ok "registro locale attivo su 127.0.0.1:5000" curl -fsS http://127.0.0.1:5000/v2/

R=127.0.0.1:5000/omni-os
$podman_cmd push --tls-verify=false --digestfile "$work/signed.digest" "$img_signed" "docker://$R:signed" >> "$work/p9.log" 2>&1
$podman_cmd push --tls-verify=false --digestfile "$work/unsigned.digest" "$img_unsigned" "docker://$R:unsigned" >> "$work/p9.log" 2>&1
d_signed=$(cat "$work/signed.digest"); d_unsigned=$(cat "$work/unsigned.digest")
if [ -n "$d_signed" ] && [ -n "$d_unsigned" ] && [ "$d_signed" != "$d_unsigned" ]; then
  rec OK "immagini caricate nel registro locale (firmata $d_signed, non firmata $d_unsigned)"
else
  rec FAIL "caricamento immagini nel registro locale"; tail -40 "$work/p9.log"; exit 1
fi

# --- Chiavi effimere: una corretta e una "sbagliata" per il test di chiave errata ---
COSIGN_PASSWORD=$(head -c 32 /dev/urandom | base64)
export COSIGN_PASSWORD
(cd "$work/keys" && "$cosign" generate-key-pair --output-key-prefix prova >/dev/null 2>&1 \
  && "$cosign" generate-key-pair --output-key-prefix sbagliata >/dev/null 2>&1)
expect_ok "chiavi effimere generate" test -s "$work/keys/prova.pub" -a -s "$work/keys/sbagliata.pub"

expect_ok "firma dell'immagine con la chiave di prova (senza registro di trasparenza)" \
  "$cosign" sign --yes --key "$work/keys/prova.key" --tlog-upload=false \
  --allow-insecure-registry --allow-http-registry "$R@$d_signed"
expect_ok "verifica sull'host: immagine firmata valida" \
  "$cosign" verify --key "$work/keys/prova.pub" --insecure-ignore-tlog=true \
  --allow-insecure-registry --allow-http-registry "$R@$d_signed"
expect_fail "verifica sull'host: immagine non firmata" \
  "$cosign" verify --key "$work/keys/prova.pub" --insecure-ignore-tlog=true \
  --allow-insecure-registry --allow-http-registry "$R@$d_unsigned"

# --- Configurazione della VM (solo questo disco di prova) ---
write_policy() { # write_policy <file-chiave-pubblica-locale>
  scp -i "$key" -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "$1" root@127.0.0.1:/etc/pki/containers/omni-prova.pub >> "$work/p9.log" 2>&1
  ssh_vm 'cat > /etc/containers/policy.json' <<'JSON'
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "10.0.2.2:5000/omni-os": [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/omni-prova.pub",
        "signedIdentity": {"type": "remapIdentity", "prefix": "10.0.2.2:5000/omni-os", "signedPrefix": "127.0.0.1:5000/omni-os"}
      }]
    },
    "docker-daemon": {"": [{"type": "reject"}]}
  }
}
JSON
}
ssh_vm 'mkdir -p /etc/pki/containers /etc/containers/registries.d /etc/containers/registries.conf.d
cp -a /etc/containers/policy.json /etc/containers/policy.json.orig-p9
printf "[[registry]]\nlocation = \"10.0.2.2:5000\"\ninsecure = true\n" > /etc/containers/registries.conf.d/50-omni-prova.conf
printf "docker:\n  10.0.2.2:5000:\n    use-sigstore-attachments: true\n" > /etc/containers/registries.d/50-omni-prova.yaml' >> "$work/p9.log" 2>&1

V=10.0.2.2:5000/omni-os
# S1–S2: immagine non firmata rifiutata da entrambi i gestori.
write_policy "$work/keys/prova.pub"
expect_fail "S1 bootc: immagine NON firmata" ssh_vm "bootc switch --enforce-container-sigpolicy $V:unsigned"
expect_fail "S2 rpm-ostree: immagine NON firmata" ssh_vm "rpm-ostree rebase ostree-image-signed:docker://$V:unsigned"
# S3–S4: immagine firmata ma chiave pubblica errata nella policy.
write_policy "$work/keys/sbagliata.pub"
expect_fail "S3 bootc: firma con chiave non riconosciuta" ssh_vm "bootc switch --enforce-container-sigpolicy $V:signed"
expect_fail "S4 rpm-ostree: firma con chiave non riconosciuta" ssh_vm "rpm-ostree rebase ostree-image-signed:docker://$V:signed"
# S5–S6: immagine firmata con la chiave corretta accettata.
write_policy "$work/keys/prova.pub"
expect_ok "S5 rpm-ostree: immagine firmata accettata (preparata)" ssh_vm "rpm-ostree rebase ostree-image-signed:docker://$V:signed"
ssh_vm 'rpm-ostree cleanup -p' >> "$work/p9.log" 2>&1 || true
expect_ok "S6 bootc: immagine firmata accettata (preparata)" ssh_vm "bootc switch --enforce-container-sigpolicy $V:signed"
ssh_vm 'systemctl reboot' >/dev/null 2>&1 || true
sleep 20
expect_ok "S6 riavvio sull'immagine firmata" bash "$here/wait_ssh.sh" "$key" "$work" 900
# shellcheck disable=SC2016 # espansione voluta nella VM
v=$(ssh_vm '. /usr/lib/omni-os/build-info; echo "$OMNI_OS_VERSION"' 2>/dev/null)
if [ "$v" = "$v_signed" ]; then rec OK "S6 sistema avviato dall'immagine firmata (versione $v)"; else rec FAIL "S6 versione '$v' != $v_signed"; fi

# Distruzione delle chiavi effimere.
shred -u "$work"/keys/*.key 2>/dev/null; rm -rf "$work/keys"; unset COSIGN_PASSWORD
if [ ! -e "$work/keys" ]; then rec OK "chiavi effimere distrutte"; else rec FAIL "distruzione chiavi"; fi

if [ "$fail" -ne 0 ]; then echo "--- ultime righe di p9.log:"; tail -60 "$work/p9.log"; fi
echo >> "$results"; echo "Esito complessivo P9: $([ $fail -eq 0 ] && echo SUPERATO || echo FALLITO)" >> "$results"
cat "$results"
exit "$fail"
