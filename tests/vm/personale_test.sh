#!/usr/bin/env bash
# VM personale — prova sul disco DI TEST (stessa immagine del disco personale, più la
# chiave SSH effimera per i controlli): accesso reale, avvio automatico di OMNI Shell e
# AVVIO REALE di applicazioni installate con clic e tasti veri (QEMU).
# Uso: personale_test.sh <dir-di-lavoro>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
w=$1; mkdir -p "$w/schermate"
# Ogni comando SSH ha un limite di tempo: un processo grafico rimasto agganciato alla
# sessione non deve bloccare la prova.
vm_ssh() { timeout 120 bash tests/vm/vm_ssh.sh "$TESTKEY" "$@"; }
LOG=$w/personale.log; : > "$LOG"
ev=$w/personale-evidenze.txt; : > "$ev"
res_init "$w/personale.md" "VM personale: avvio automatico di OMNI Shell e avvio reale delle applicazioni"
qmp() { python3 tests/vm/qmp.py "$w/qmp.sock" "$@"; }
shot() { qmp screendump "$w/schermate/$1.png" && echo "schermata: $1.png" >> "$ev"; }
W=1280 H=800

export VM_TABLET=1
vm_fresh "$w" || { rec FAIL "avvio della VM"; res_end; exit 1; }
rec OK "VM avviata dall'immagine OMNI personale"
v=$(vm_version); echo "INFO versione: $v" | tee -a "$LOG" "$ev"
expect_ok "OMNI Shell installata nell'immagine (/usr/bin/omni-shell)" vm_ssh "test -x /usr/bin/omni-shell && test -x /usr/lib/omni-shell/bin/omni-shell-prototipo"
expect_ok "voce di menu e avvio automatico presenti" vm_ssh "test -f /usr/share/applications/org.omnios.Shell.desktop && test -f /etc/xdg/autostart/org.omnios.Shell.desktop"
expect_ok "eseguibile senza setuid/setgid" vm_ssh "! test -u /usr/lib/omni-shell/bin/omni-shell-prototipo && ! test -g /usr/lib/omni-shell/bin/omni-shell-prototipo"

# --- accesso reale ---
user=omniprova
pw=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 16)
if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$pw"; fi
expect_ok "utente temporaneo creato" vm_ssh "useradd -m -c 'OMNI prova temporanea' $user"
printf '%s:%s\n' "$user" "$pw" | vm_ssh chpasswd >> "$LOG" 2>&1
uid=$(vm_ssh "id -u $user" 2>/dev/null)
for u in $(vm_ssh "systemctl list-unit-files --no-legend | awk '{print \$1}' | grep -iE 'plasma-setup|initial-setup' || true" 2>/dev/null); do
  vm_ssh "systemctl disable --now $u; systemctl mask $u" >> "$LOG" 2>&1 || true
done
vm_ssh "systemctl restart display-manager" >> "$LOG" 2>&1; sleep 25
sid=""
for strategy in pw user-tab-pw; do
  case $strategy in pw) qmp type "$pw" ;; user-tab-pw) qmp type "$user"; qmp key tab; qmp type "$pw" ;; esac
  qmp key ret
  for _ in $(seq 1 30); do sid=$(vm_ssh "loginctl list-sessions --no-legend" 2>/dev/null | awk -v u="$user" '$3==u {print $1; exit}'); [ -n "$sid" ] && break; sleep 3; done
  [ -n "$sid" ] && break
  qmp key ctrl a; qmp key backspace
done
if [ -z "$sid" ]; then rec FAIL "accesso alla sessione"; vm_stop "$w"; res_end; exit 1; fi
rec OK "accesso reale alla sessione Plasma ($(vm_ssh "loginctl show-session $sid -p Type --value" 2>/dev/null))"

# --- avvio automatico di OMNI Shell ---
shell_pid=""
for _ in $(seq 1 40); do shell_pid=$(vm_ssh "pgrep -u $user -f 'omni-shell-prototipo --real-launch' | head -1" 2>/dev/null); [ -n "$shell_pid" ] && break; sleep 3; done
if [ -n "$shell_pid" ]; then rec OK "OMNI Shell avviata automaticamente all'accesso (pid $shell_pid, utente $user)"; else rec FAIL "OMNI Shell non avviata automaticamente"; fi
sleep 12
shot 01-omni-shell-avvio-automatico
vm_ssh "ps -o user=,pid=,args= -p $shell_pid" >> "$ev" 2>&1
if [ "$(vm_ssh "ps -o user= -p $shell_pid" 2>/dev/null | tr -d ' ')" = "$user" ]; then rec OK "OMNI Shell eseguita come utente non privilegiato"; else rec FAIL "proprietario del processo inatteso"; fi
if vm_ssh "journalctl -b _UID=$uid --no-pager -o cat | grep -q 'avvio delle applicazioni: REALE'"; then rec OK "modalità di avvio reale attiva (registro dell'app)"; else rec FAIL "modalità di avvio reale non confermata dal registro"; fi
if vm_ssh "journalctl -b _UID=$uid --no-pager -o cat | grep -q 'interfaccia: avvio delle applicazioni REALE'"; then rec OK "interfaccia collegata all'avvio reale (registro QML)"; else rec FAIL "interfaccia in modalità simulata"; fi
wdisp=$(vm_ssh "tr '\\0' '\\n' < /proc/$shell_pid/environ | sed -n 's/^WAYLAND_DISPLAY=//p'" 2>/dev/null); wdisp=${wdisp:-wayland-1}
ubus="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
envs="$ubus XDG_RUNTIME_DIR=/run/user/$uid WAYLAND_DISPLAY=$wdisp QT_QPA_PLATFORM=wayland QT_FORCE_STDERR_LOGGING=1"
plasma_before=$(vm_ssh "pgrep -u $user -x plasmashell; pgrep -u $user -x kwin_wayland" 2>/dev/null | tr '\n' ' ')

# --- geometria reale (seconda istanza temporanea, stesse dimensioni) ---
for sc in desktop launcher quicksettings; do
  vm_ssh "runuser -u $user -- env $envs /usr/bin/omni-shell --fullscreen --scene $sc --dump-geometry /tmp/geo-$sc.json --delay 5000 </dev/null > /dev/null 2>&1; cat /tmp/geo-$sc.json" > "$w/geo-$sc.json" 2>/dev/null
done
python3 -I -c 'import json,sys; m={}; [m.update(json.load(open(p))) for p in sys.argv[2:] if open(p).read().strip()]; json.dump(m, open(sys.argv[1],"w"))' "$w/geometria.json" "$w"/geo-desktop.json "$w"/geo-launcher.json "$w"/geo-quicksettings.json
at() { python3 -I -c 'import json,sys; g=json.load(open(sys.argv[1])); e=g.get(sys.argv[2]); print("%d %d" % (e["x"], e["y"]) if e else "")' "$w/geometria.json" "$1"; }
click() { local xy; xy=$(at "$1"); [ -n "$xy" ] || { echo "AVVISO: $1 assente" | tee -a "$LOG"; return 1; }; read -r x y <<< "$xy"; qmp click "$x" "$y" "$W" "$H"; }
procs() { vm_ssh "ps -u $user -o comm=" 2>/dev/null | LC_ALL=C sort -u; }

# real_launch <etichetta> <processo atteso (regex)> <azioni...>: esegue le azioni e controlla
# che un NUOVO processo dell'utente corrisponda a quello atteso
real_launch() {
  local label=$1 want=$2; shift 2
  local before after new
  before=$(procs)
  "$@"
  for _ in $(seq 1 30); do
    sleep 2; after=$(procs)
    new=$(LC_ALL=C comm -13 <(echo "$before") <(echo "$after") | tr '\n' ' ')
    echo "$new" | grep -qE "$want" && break
  done
  echo "INFO $label: nuovi processi dell'utente: ${new:-nessuno}" | tee -a "$LOG" "$ev"
  sleep 6
  shot "02-avvio-reale-$label"
  if echo "$new" | grep -qE "$want"; then
    owner=$(vm_ssh "ps -o user= -C $(echo "$new" | grep -oE "$want" | head -1) | sort -u | tr -d ' '" 2>/dev/null)
    rec OK "$label avviata DAVVERO da OMNI Shell (processo: $(echo "$new" | grep -oE "$want" | head -1), utente: $owner)"
  else
    rec FAIL "$label non avviata"
  fi
  vm_ssh "pkill -u $user -x '$(echo "$new" | grep -oE "$want" | head -1)'" >/dev/null 2>&1 || true
  sleep 4
}
real_launch Konsole 'konsole' click dock:terminal
real_launch Dolphin 'dolphin' click dock:files
real_launch Firefox 'firefox' click dock:browser
type_settings() { click dock:launcher; sleep 3; qmp type settings; sleep 2; qmp key ret; }
real_launch Impostazioni 'systemsettings|kcmshell6|plasma-systemmo' type_settings

if vm_ssh "kill -0 $shell_pid"; then rec OK "OMNI Shell ancora in esecuzione dopo gli avvii (nessun crash)"; else rec FAIL "OMNI Shell terminata"; fi

# --- uscita e ritorno a Plasma ---
click topbar:tray; sleep 3; click qs:quit; sleep 5
if ! vm_ssh "kill -0 $shell_pid" 2>/dev/null; then rec OK "'Esci da OMNI Shell' chiude l'app"; else rec FAIL "OMNI Shell non si è chiusa"; fi
shot 03-plasma-dopo-uscita
plasma_after=$(vm_ssh "pgrep -u $user -x plasmashell; pgrep -u $user -x kwin_wayland" 2>/dev/null | tr '\n' ' ')
if [ -n "$plasma_before" ] && [ "$plasma_before" = "$plasma_after" ]; then rec OK "Plasma e KWin invariati (PID $plasma_after)"; else rec FAIL "PID di Plasma/KWin cambiati"; fi
# riapertura dalla voce di menu (stesso meccanismo dei lanciatori di Plasma)
# output del processo avviato staccato dalla sessione SSH (altrimenti ssh resta in attesa)
vm_ssh "runuser -u $user -- env $envs gio launch /usr/share/applications/org.omnios.Shell.desktop </dev/null >/dev/null 2>&1" >> "$LOG" 2>&1
sleep 12
if vm_ssh "pgrep -u $user -f 'omni-shell-prototipo --real-launch'" >/dev/null 2>&1; then rec OK "OMNI Shell riaperta dalla voce di menu"; else rec FAIL "riapertura dalla voce di menu"; fi
shot 04-omni-shell-riaperta
cores=$(vm_ssh "coredumpctl list --no-legend 2>/dev/null | grep -Ei 'omni|plasma|kwin|konsole|dolphin|firefox|systemsettings' || true" 2>/dev/null)
if [ -z "$cores" ]; then rec OK "nessun core dump"; else rec FAIL "core dump: $cores"; fi
vm_ssh "loginctl terminate-user $user" >/dev/null 2>&1 || true; sleep 5
expect_ok "utente temporaneo eliminato" vm_ssh "userdel -r -f $user"
unset pw
vm_stop "$w"
res_end
