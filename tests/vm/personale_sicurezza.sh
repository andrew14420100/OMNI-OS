#!/usr/bin/env bash
# Controlli di sicurezza sul disco PERSONALE (quello da scaricare), montato in sola lettura.
# Uso: personale_sicurezza.sh <disk.raw> <chiave-pubblica-di-prova> <dir-risultati>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
disk=$1 testpub=$2 w=$3; mkdir -p "$w"
res_init "$w/sicurezza.md" "Controlli di sicurezza del disco della VM personale"
loop=$(sudo losetup -f --show -P -r "$disk")
sleep 2
mnt=$w/mnt; mkdir -p "$mnt"
lsblk -o NAME,FSTYPE,PARTLABEL,SIZE "$loop" | tee "$w/partizioni.txt"
i=0; roots=()
for part in "${loop}"p*; do
  fs=$(sudo blkid -o value -s TYPE "$part" 2>/dev/null || true)
  [ -n "$fs" ] || continue
  i=$((i + 1)); mkdir -p "$mnt/$i"
  opts=ro; [ "$fs" = xfs ] && opts=ro,norecovery
  sudo mount -o "$opts" "$part" "$mnt/$i" && roots+=("$mnt/$i")
done
root=""; for r in "${roots[@]}"; do [ -d "$r/ostree/deploy" ] && root=$r; done
[ -n "$root" ] || { rec FAIL "radice ostree non trovata"; res_end; exit 1; }
dep=$(sudo find "$root/ostree/deploy" -mindepth 3 -maxdepth 3 -type d -path '*/deploy/*' -name '*.0' | head -1)
var=$(dirname "$(dirname "$dep")")/var
echo "INFO deployment: ${dep#"$root"/}" | tee -a "$w/evidenze.txt"
sudo cat "$dep.origin" 2>/dev/null | tee -a "$w/evidenze.txt"

n=$(sudo find "$var" "$dep/etc" -name 'authorized_keys*' 2>/dev/null | wc -l)
if [ "$n" -eq 0 ]; then rec OK "nessun file authorized_keys (né per root né per altri utenti)"; else rec FAIL "$n file authorized_keys presenti"; fi
key=$(awk '{print $2}' "$testpub")
if ! sudo grep -rqsF "$key" "$var" "$dep/etc" 2>/dev/null; then rec OK "la chiave SSH effimera dei test non è presente"; else rec FAIL "chiave di prova trovata nel disco"; fi
users=$(sudo awk -F: '$3>=1000 && $3<65534 {print $1}' "$dep/etc/passwd")
if [ -z "$users" ]; then rec OK "nessun account utente preconfigurato (lo crea il proprietario al primo avvio)"; else rec FAIL "account presenti: $users"; fi
rootpw=$(sudo awk -F: '$1=="root" {print $2}' "$dep/etc/shadow")
case "$rootpw" in '!'*|'*'*) rec OK "account root bloccato (nessuna password)" ;; '') rec FAIL "root senza password (accesso libero)" ;; *) rec FAIL "root con password impostata" ;; esac
if ! sudo test -e "$dep/etc/systemd/system/multi-user.target.wants/sshd.service"; then rec OK "sshd non abilitato"; else rec FAIL "sshd abilitato"; fi
entries=$(for r in "${roots[@]}"; do sudo find "$r" -path '*loader/entries/*.conf' 2>/dev/null; done)
if [ -n "$entries" ] && ! for e in $entries; do sudo cat "$e"; done | grep -qE 'sshd|ttyS0'; then
  rec OK "argomenti del kernel senza opzioni di test (sshd, console seriale)"
else rec FAIL "voci di avvio assenti o con opzioni di test"; fi
for e in $entries; do sudo grep -h '^options' "$e"; done | tee -a "$w/evidenze.txt"
b=$dep/usr/lib/omni-shell/bin/omni-shell-prototipo
if [ "$(sudo stat -c '%a %u' "$b")" = "755 0" ]; then rec OK "OMNI Shell: eseguibile di root, permessi 755"; else rec FAIL "permessi di OMNI Shell: $(sudo stat -c '%a %u' "$b")"; fi
if [ -z "$(sudo find "$dep/usr/lib/omni-shell" -perm /6000 2>/dev/null)" ]; then rec OK "nessun file setuid/setgid in OMNI Shell"; else rec FAIL "file setuid/setgid in OMNI Shell"; fi
for t in rpm-ostreed-automatic.timer bootc-fetch-apply-updates.timer; do
  if sudo test -e "$dep/etc/systemd/system/timers.target.wants/$t"; then echo "INFO $t: abilitato" | tee -a "$w/evidenze.txt"; else echo "INFO $t: non abilitato (nessun aggiornamento automatico)" | tee -a "$w/evidenze.txt"; fi
done
sudo cat "$dep/usr/lib/omni-os/build-info" | tee -a "$w/evidenze.txt"
for r in "${roots[@]}"; do sudo umount "$r"; done
sudo losetup -d "$loop"
res_end
