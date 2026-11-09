#!/usr/bin/env bash
# Funzioni per le prove di sessione grafica reale nella VM di test (da includere dopo lib.sh).
# Richiedono: $w (cartella di lavoro con qmp.sock), $LOG, $TESTKEY.
# shellcheck disable=SC2154,SC2034 # w e LOG sono del chiamante; SID, LOGIN_T0, U, PW, UID_, ENVS sono per il chiamante
# Tutto avviene nella VM effimera: utente temporaneo, nessuna modifica all'host.

# Ogni comando SSH ha un limite di tempo: un processo grafico agganciato alla sessione
# non deve bloccare la prova.
vm_ssh() { timeout "${SSH_TIMEOUT:-120}" bash tests/vm/vm_ssh.sh "$TESTKEY" "$@"; }
qmp() { python3 tests/vm/qmp.py "$w/qmp.sock" "$@"; }
# secondi dall'avvio della VM (orologio monotono della VM) e millisecondi epoch della VM
vm_up() { vm_ssh "cut -d' ' -f1 /proc/uptime" 2>/dev/null; }
vm_ms() { vm_ssh "date +%s%3N" 2>/dev/null; }

# sess_user_create <utente>: utente temporaneo con password casuale; disattiva la
# configurazione iniziale (per la prova) e abilita il canale di debug degli script KWin
# solo per questo utente (serve alla sonda delle finestre).
sess_user_create() {
  U=$1
  PW=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 16)
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$PW"; fi
  vm_ssh "useradd -m -c 'OMNI prova temporanea' $U" >> "$LOG" 2>&1 || return 1
  printf '%s:%s\n' "$U" "$PW" | vm_ssh chpasswd >> "$LOG" 2>&1 || return 1
  UID_=$(vm_ssh "id -u $U" 2>/dev/null)
  vm_ssh "install -d -o $U -g $U /home/$U/.config/QtProject && printf '[Rules]\nkwin_scripting.debug=true\n' > /home/$U/.config/QtProject/qtlogging.ini && chown $U:$U /home/$U/.config/QtProject/qtlogging.ini" >> "$LOG" 2>&1
  for u in $(vm_ssh "systemctl list-unit-files --no-legend | awk '{print \$1}' | grep -iE 'plasma-setup|initial-setup' || true" 2>/dev/null); do
    vm_ssh "systemctl disable --now $u; systemctl mask $u" >> "$LOG" 2>&1 || true
  done
}
# sess_greeter: riavvia il gestore di accesso e attende la schermata di accesso
sess_greeter() {
  vm_ssh "systemctl restart display-manager" >> "$LOG" 2>&1
  sleep "${GREETER_WAIT:-35}"
}
# sess_login: accesso reale con tastiera virtuale. Imposta SID e LOGIN_T0 (uptime VM).
sess_login() {
  SID=""
  local strategy
  for strategy in pw user-tab-pw; do
    LOGIN_T0=$(vm_up)
    case $strategy in pw) qmp type "$PW" ;; user-tab-pw) qmp type "$U"; qmp key tab; qmp type "$PW" ;; esac
    qmp key ret
    for _ in $(seq 1 60); do
      SID=$(vm_ssh "loginctl list-sessions --no-legend" 2>/dev/null | awk -v u="$U" '$3==u {print $1; exit}')
      [ -n "$SID" ] && break; sleep 2
    done
    [ -n "$SID" ] && return 0
    qmp key ctrl a; qmp key backspace
  done
  return 1
}
# sess_env: ambiente della sessione grafica, letto dal gestore systemd dell'utente
sess_env() {
  local base="XDG_RUNTIME_DIR=/run/user/$UID_ DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_/bus"
  local wd=""
  for _ in $(seq 1 60); do
    wd=$(vm_ssh "runuser -u $U -- env $base systemctl --user show-environment 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p'" 2>/dev/null)
    [ -n "$wd" ] && break; sleep 2
  done
  ENVS="$base WAYLAND_DISPLAY=${wd:-wayland-0} QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland"
  echo "INFO ambiente della sessione: WAYLAND_DISPLAY=${wd:-?}" >> "$LOG"
}
# u_sh <script>: esegue uno script bash come utente, nella sessione grafica
u_sh() { vm_ssh "runuser -u $U -- env $ENVS bash -s" <<< "$1"; }

# --- sonda delle finestre (script KWin: registra apertura/chiusura con l'ora di KWin) ---
kwin_probe_load() {
  u_sh "cat > /tmp/omniwin-$U.js <<'JS'
workspace.windowAdded.connect(function (w) { print('OMNIWIN add ' + w.resourceClass + ' ' + Date.now()); });
workspace.windowRemoved.connect(function (w) { print('OMNIWIN del ' + w.resourceClass + ' ' + Date.now()); });
print('OMNIWIN pronto ' + Date.now());
JS
gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.loadScript /tmp/omniwin-$U.js omniwin
gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.start" >> "$LOG" 2>&1
  sleep 2
  vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -q 'OMNIWIN pronto'" 2>/dev/null
}
# win_wait <regex-classe> <t0-ms> <timeout-s>: stampa i ms fra t0 e l'apertura della finestra
win_wait() {
  local re=$1 t0=$2 to=$3 end ts
  end=$(( $(date +%s) + to ))
  while [ "$(date +%s)" -lt "$end" ]; do
    ts=$(vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat --since '-5min' | grep -E 'OMNIWIN add ' | awk -v t0=$t0 '\$NF+0 >= t0+0' | grep -iE 'OMNIWIN add [^ ]*($re)[^ ]* ' | head -1 | awk '{print \$NF}'" 2>/dev/null)
    if [ -n "$ts" ]; then echo $(( ts - t0 )); return 0; fi
    sleep 0.5
  done
  return 1
}
# app_desktop <regex>: percorso del file .desktop installato che corrisponde
app_desktop() { vm_ssh "ls /usr/share/applications/ | grep -iE '^($1)\\.desktop\$' | head -1" 2>/dev/null; }
# app_launch <file.desktop>: avvia come farebbe il lanciatore; stampa t0 (ms epoch della VM)
app_launch() { u_sh "date +%s%3N; setsid -f gio launch /usr/share/applications/$1 >/dev/null 2>&1 </dev/null"; }
app_close() { vm_ssh "pkill -u $U -x '$1'" >/dev/null 2>&1 || true; for _ in $(seq 1 20); do vm_ssh "pgrep -u $U -x '$1'" >/dev/null 2>&1 || return 0; sleep 1; done; vm_ssh "pkill -9 -u $U -x '$1'" >/dev/null 2>&1 || true; }

# cpu_ticks <nomi...>: "nome ticks" (utime+stime) per il primo processo dell'utente con quel nome
cpu_ticks() {
  local n
  for n in "$@"; do
    vm_ssh "pid=\$(pgrep -u $U -x '$n' | head -1); [ -n \"\$pid\" ] && awk -v n='$n' '{print n, \$14+\$15}' /proc/\$pid/stat" 2>/dev/null
  done
}
rss_mb() { vm_ssh "pid=\$(pgrep -u $U -x '$1' | head -1); [ -n \"\$pid\" ] && awk '/VmRSS/ {printf \"%.0f\", \$2/1024}' /proc/\$pid/status" 2>/dev/null; }
