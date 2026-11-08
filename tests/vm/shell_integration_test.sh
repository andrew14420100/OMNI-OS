#!/usr/bin/env bash
# Prova di integrazione SPERIMENTALE (non M4): OMNI Shell V2 come normale applicazione
# utente, non privilegiata, dentro la sessione KDE Plasma Wayland reale di una VM OMNI OS.
# Non sostituisce Plasma, KWin né il gestore di accesso e non modifica l'immagine.
# Uso: shell_integration_test.sh <dir-di-lavoro> <pacchetto omni-shell-f45.tar.gz>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
w=$1 bundle=$2; mkdir -p "$w/schermate"
LOG=$w/integrazione.log; : > "$LOG"
ev=$w/integrazione-evidenze.txt; : > "$ev"
res_init "$w/integrazione.md" "Integrazione sperimentale di OMNI Shell V2 nella sessione Plasma Wayland della VM"
qmp() { python3 tests/vm/qmp.py "$w/qmp.sock" "$@"; }
shot() { qmp screendump "$w/schermate/$1.png" && echo "schermata: $1.png" >> "$ev"; }
W=1280 H=800

export VM_TABLET=1
vm_fresh "$w" || { rec FAIL "avvio della VM"; res_end; exit 1; }
rec OK "VM OMNI OS avviata (immagine M1, base B3)"

# --- accesso reale con un utente temporaneo (come AC-M1-03) ---
user=omniprova
pw=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 16)
if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$pw"; fi
expect_ok "utente temporaneo '$user' creato" vm_ssh "useradd -m -c 'OMNI prova temporanea' $user"
printf '%s:%s\n' "$user" "$pw" | vm_ssh chpasswd >> "$LOG" 2>&1
uid=$(vm_ssh "id -u $user" 2>/dev/null)
for u in $(vm_ssh "systemctl list-unit-files --no-legend | awk '{print \$1}' | grep -iE 'plasma-setup|initial-setup' || true" 2>/dev/null); do
  vm_ssh "systemctl disable --now $u; systemctl mask $u" >> "$LOG" 2>&1 || true
done
expect_ok "gestore di accesso riavviato" vm_ssh "systemctl restart display-manager"
sleep 25
sid=""
for strategy in pw user-tab-pw; do
  case $strategy in
    pw) qmp type "$pw" ;;
    user-tab-pw) qmp type "$user"; qmp key tab; qmp type "$pw" ;;
  esac
  qmp key ret
  for _ in $(seq 1 30); do sid=$(vm_ssh "loginctl list-sessions --no-legend" 2>/dev/null | awk -v u="$user" '$3==u {print $1; exit}'); [ -n "$sid" ] && break; sleep 3; done
  [ -n "$sid" ] && break
  qmp key ctrl a; qmp key backspace
done
if [ -z "$sid" ]; then rec FAIL "accesso alla sessione Plasma"; vm_stop "$w"; res_end; exit 1; fi
rec OK "accesso reale alla sessione Plasma (sessione $sid, $(vm_ssh "loginctl show-session $sid -p Type --value" 2>/dev/null))"
sleep 25
wdisp=$(vm_ssh "pid=\$(pgrep -u $user -x plasmashell | head -1); tr '\\0' '\\n' < /proc/\$pid/environ | sed -n 's/^WAYLAND_DISPLAY=//p'" 2>/dev/null)
wdisp=${wdisp:-wayland-1}
ubus="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
pids_before=$(vm_ssh "pgrep -u $user -x plasmashell; pgrep -u $user -x kwin_wayland" 2>/dev/null | tr '\n' ' ')
echo "INFO display Wayland: $wdisp; PID plasmashell/kwin: $pids_before" | tee -a "$LOG" "$ev"
shot 00-plasma-prima

# --- installazione NELLA HOME dell'utente (nessun privilegio, immagine invariata) ---
vm_scp "$bundle" root@127.0.0.1:/var/tmp/omni-shell.tar.gz >> "$LOG" 2>&1
expect_ok "OMNI Shell copiata nella home dell'utente (senza privilegi)" vm_ssh "runuser -u $user -- bash -c 'mkdir -p ~/.local/omni-shell ~/.local/share/fonts && tar -xzf /var/tmp/omni-shell.tar.gz -C ~/.local/omni-shell && cp -r ~/.local/omni-shell/fonts/. ~/.local/share/fonts/ 2>/dev/null; fc-cache -f >/dev/null 2>&1; true'"
vm_ssh "rpm -q qt6-qtbase qt6-qtdeclarative" > "$w/qt-vm.txt" 2>&1
echo "INFO Qt nella VM: $(tr '\n' ' ' < "$w/qt-vm.txt")" | tee -a "$LOG" "$ev"
echo "INFO Qt di compilazione: $(tar -xzOf "$bundle" ./qt-build.txt 2>/dev/null | tr '\n' ' ')" | tee -a "$LOG" "$ev"
if vm_ssh "test \"\$(stat -c %U /home/$user/.local/omni-shell/bin/omni-shell-prototipo)\" = $user && ! test -u /home/$user/.local/omni-shell/bin/omni-shell-prototipo"; then
  rec OK "eseguibile di proprietà dell'utente, senza setuid"; else rec FAIL "proprietà o permessi dell'eseguibile"; fi

app="/home/$user/.local/omni-shell/bin/omni-shell-prototipo"
# QT_FORCE_STDERR_LOGGING: senza terminale Qt scrive nel journal; serve il registro nel file
envs="$ubus XDG_RUNTIME_DIR=/run/user/$uid WAYLAND_DISPLAY=$wdisp QT_QPA_PLATFORM=wayland QT_FORCE_STDERR_LOGGING=1 OMNI_QML_DIR=/home/$user/.local/omni-shell/qml"
# run_shell <nome-log> <argomenti...>: avvia l'app come utente nella sessione grafica
run_shell() {
  local n=$1; shift
  vm_ssh "pkill -u $user -f omni-shell-prototipo; sleep 1; runuser -u $user -- env $envs setsid -f $app $* > /tmp/omni-shell-$n.log 2>&1" >> "$LOG" 2>&1
}
alive() { vm_ssh "pgrep -u $user -f omni-shell-prototipo" >/dev/null 2>&1; }

# --- geometria reale degli elementi nella VM (per clic precisi) ---
for sc in desktop quicksettings notifications launcher; do
  vm_ssh "rm -f /tmp/geo-$sc.json; runuser -u $user -- env $envs $app --fullscreen --scene $sc --dump-geometry /tmp/geo-$sc.json --delay 5000 > /tmp/omni-geo-$sc.log 2>&1" >> "$LOG" 2>&1
  vm_ssh "cat /tmp/geo-$sc.json" > "$w/geo-$sc.json" 2>/dev/null
done
python3 -I -c 'import json,sys; m={}; [m.update(json.load(open(p))) for p in sys.argv[2:] if open(p).read().strip()]; json.dump(m, open(sys.argv[1],"w"))' "$w/geometria.json" "$w"/geo-desktop.json "$w"/geo-quicksettings.json "$w"/geo-notifications.json "$w"/geo-launcher.json
n_geo=$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$w/geometria.json" 2>/dev/null || echo 0)
if [ "${n_geo:-0}" -gt 10 ]; then rec OK "geometria misurata nella VM ($n_geo elementi)"; else rec FAIL "geometria non misurata ($n_geo)"; fi
vm_ssh "cat /tmp/omni-geo-desktop.log" > "$w/avvio-geometria.log" 2>&1
plat=$(grep -m1 '^piattaforma' "$w/avvio-geometria.log")
echo "INFO $plat" | tee -a "$LOG" "$ev"
if echo "$plat" | grep -q 'piattaforma: wayland'; then rec OK "OMNI Shell eseguita come client Wayland nativo"; else rec FAIL "piattaforma non wayland: $plat"; fi
grep -m1 '^applicazioni' "$w/avvio-geometria.log" | sed 's/^/INFO /' | tee -a "$LOG" "$ev"
grep -m1 '^renderer OpenGL' "$w/avvio-geometria.log" | sed 's/^/INFO /' | tee -a "$LOG" "$ev"

# --- scene: schermate reali dello schermo della VM ---
for spec in "desktop dark" "launcher dark" "quicksettings dark" "notifications dark" "desktop light" "launcher light"; do
  # shellcheck disable=SC2086 # divisione voluta in scena e tema
  set -- $spec
  run_shell "$1-$2" --fullscreen --scene "$1" --theme "$2"
  sleep 9
  if alive; then rec OK "scena $1, tema $2: in esecuzione"; else rec FAIL "scena $1, tema $2: processo terminato"; fi
  shot "omni-shell-$1-$2"
done

# --- interazioni reali (mouse e tastiera virtuali QEMU) e video dello schermo della VM ---
run_shell video --fullscreen --scene desktop --theme dark
sleep 9
# QMP accetta un solo client: la registrazione usa una connessione dedicata
if python3 tests/vm/qmp_record.py "$w/qmp.sock" "$w/fotogrammi" "$W" "$H" tests/vm/interazioni_vm.json "$w/geometria.json" 2>&1 | tee -a "$LOG"; then
  rec OK "interazioni reali eseguite e schermo registrato"
else
  rec FAIL "registrazione delle interazioni"
fi
if alive; then rec OK "OMNI Shell ancora in esecuzione dopo le interazioni (nessun crash)"; else rec FAIL "OMNI Shell terminata durante le interazioni"; fi
shot omni-shell-dopo-interazioni
vm_ssh "cat /tmp/omni-shell-video.log" > "$w/omni-shell-video.log" 2>&1
warn=$(grep -cE 'qml:|TypeError|ReferenceError|Binding loop' "$w/omni-shell-video.log" || true)
echo "INFO avvisi QML durante le interazioni: $warn" | tee -a "$LOG" "$ev"

# --- nessuna regressione nella sessione Plasma ---
expect_ok "OMNI Shell chiusa normalmente (SIGTERM)" vm_ssh "pkill -TERM -u $user -f omni-shell-prototipo; sleep 3; ! pgrep -u $user -f omni-shell-prototipo"
sleep 5
shot 99-plasma-dopo
pids_after=$(vm_ssh "pgrep -u $user -x plasmashell; pgrep -u $user -x kwin_wayland" 2>/dev/null | tr '\n' ' ')
if [ -n "$pids_before" ] && [ "$pids_before" = "$pids_after" ]; then rec OK "plasmashell e kwin_wayland invariati (PID $pids_after)"; else rec FAIL "PID cambiati ('$pids_before' → '$pids_after')"; fi
if [ "$(vm_ssh "loginctl show-session $sid -p State --value" 2>/dev/null)" = active ]; then rec OK "sessione Plasma ancora attiva"; else rec FAIL "sessione Plasma non attiva"; fi
cores=$(vm_ssh "coredumpctl list --no-legend 2>/dev/null | grep -Ei 'omni|plasma|kwin' || true" 2>/dev/null)
if [ -z "$cores" ]; then rec OK "nessun core dump (OMNI Shell, Plasma, KWin)"; else rec FAIL "core dump: $cores"; fi
expect_ok "immagine di sistema invariata (nessun file OMNI Shell fuori dalla home)" vm_ssh "! find /usr /etc /opt -name 'omni-shell-prototipo*' 2>/dev/null | grep -q ."

vm_ssh "loginctl terminate-user $user" >/dev/null 2>&1 || true
sleep 5
expect_ok "utente temporaneo eliminato" vm_ssh "userdel -r -f $user"
unset pw
vm_stop "$w"
res_end
