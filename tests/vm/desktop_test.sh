#!/usr/bin/env bash
# AC-M1-03: accesso reale tramite plasmalogin e sessione KDE Plasma su Wayland.
# Il test NON è superato solo perché il gestore di accesso è attivo: richiede una
# sessione utente Wayland attiva, kwin_wayland e plasmashell in esecuzione e
# raggiungibili su D-Bus, l'apertura di un'applicazione e l'assenza di crash.
# Uso: desktop_test.sh <dir-di-lavoro>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
w=$1; mkdir -p "$w"
LOG=$w/desktop.log; : > "$LOG"
ev=$w/desktop-evidenze.txt; : > "$ev"
res_init "$w/desktop.md" "AC-M1-03 — accesso tramite plasmalogin e sessione Plasma Wayland"
shot() { python3 tests/vm/qmp.py "$w/qmp.sock" screendump "$w/$1.png" && echo "schermata: $1.png" >> "$ev"; }

vm_fresh "$w" || { rec FAIL "avvio della VM"; res_end; exit 1; }
rec OK "VM avviata (sistema pronto)"

# Utente temporaneo con password casuale (mascherata nei log di GitHub Actions).
user=omniprova
pw=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 16)
if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$pw"; fi
expect_ok "utente temporaneo '$user' creato" vm_ssh "useradd -m -c 'OMNI prova temporanea' $user"
if printf '%s:%s\n' "$user" "$pw" | vm_ssh chpasswd >> "$LOG" 2>&1; then rec OK "password temporanea impostata"; else rec FAIL "password temporanea"; fi
uid=$(vm_ssh "id -u $user" 2>/dev/null)

# Al primo avvio, senza utenti, KDE mostra la configurazione iniziale ("Welcome to
# Plasma Desktop — Begin Setup", schermata reale delle esecuzioni P7). Creato l'utente
# di prova, la configurazione iniziale viene disattivata SOLO su questa VM e il
# gestore di accesso viene riavviato, così da mostrare il login vero.
shot 00-configurazione-iniziale
setup_units=$(vm_ssh "systemctl list-unit-files --no-legend 2>/dev/null | awk '{print \$1}' | grep -iE 'plasma-setup|initial-setup|kde-initial' || true" 2>/dev/null)
echo "INFO unità di configurazione iniziale trovate: ${setup_units:-nessuna}" | tee -a "$LOG" "$ev"
for u in $setup_units; do vm_ssh "systemctl disable --now $u; systemctl mask $u" >> "$LOG" 2>&1 || true; done
vm_ssh "ls /etc/plasma-setup* /var/lib/plasma-setup* 2>/dev/null; true" >> "$ev" 2>&1
expect_ok "gestore di accesso riavviato" vm_ssh "systemctl restart display-manager"
sleep 25
shot 01-schermata-accesso

session_id() { vm_ssh "loginctl list-sessions --no-legend" 2>/dev/null | awk -v u="$user" '$3==u {print $1; exit}'; }
wait_session() { for _ in $(seq 1 30); do s=$(session_id); if [ -n "$s" ]; then echo "$s"; return 0; fi; sleep 3; done; return 1; }

# Tentativi di inserimento tramite la tastiera virtuale (QMP), dal più probabile.
sid=""
attempt=0
for strategy in "pw" "user-tab-pw" "esc-pw" "tab-pw"; do
  attempt=$((attempt + 1))
  case "$strategy" in
    pw)          python3 tests/vm/qmp.py "$w/qmp.sock" type "$pw" ;;
    user-tab-pw) python3 tests/vm/qmp.py "$w/qmp.sock" type "$user"; python3 tests/vm/qmp.py "$w/qmp.sock" key tab
                 python3 tests/vm/qmp.py "$w/qmp.sock" type "$pw" ;;
    esc-pw)      python3 tests/vm/qmp.py "$w/qmp.sock" key esc; python3 tests/vm/qmp.py "$w/qmp.sock" type "$pw" ;;
    tab-pw)      python3 tests/vm/qmp.py "$w/qmp.sock" key tab; python3 tests/vm/qmp.py "$w/qmp.sock" type "$pw" ;;
  esac
  python3 tests/vm/qmp.py "$w/qmp.sock" key ret
  if sid=$(wait_session); then
    rec OK "accesso tramite plasmalogin riuscito (tentativo $attempt, modalità '$strategy')"
    break
  fi
  shot "02-tentativo-$attempt"
  echo "INFO tentativo $attempt ('$strategy') senza sessione" | tee -a "$LOG"
  # svuota eventuali campi prima del tentativo successivo
  python3 tests/vm/qmp.py "$w/qmp.sock" key ctrl a; python3 tests/vm/qmp.py "$w/qmp.sock" key backspace
done
if [ -z "$sid" ]; then
  rec FAIL "nessuna sessione utente aperta tramite plasmalogin"
  vm_ssh "journalctl -b -u plasmalogin --no-pager -n 60" >> "$LOG" 2>&1
else
  props=$(vm_ssh "loginctl show-session $sid -p Name -p Type -p Class -p State -p Active -p Remote -p Service -p Desktop -p Seat -p VTNr" 2>/dev/null)
  echo "$props" | tee -a "$ev"
  get() { echo "$props" | sed -n "s/^$1=//p"; }
  if [ "$(get Type)" = wayland ]; then rec OK "sessione di tipo wayland"; else rec FAIL "tipo di sessione '$(get Type)' (atteso wayland)"; fi
  if [ "$(get Class)" = user ]; then rec OK "sessione di classe user"; else rec FAIL "classe '$(get Class)'"; fi
  if [ "$(get Active)" = yes ] && [ "$(get State)" = active ]; then rec OK "sessione attiva in primo piano"; else rec FAIL "sessione non attiva (Active=$(get Active) State=$(get State))"; fi
  if [ "$(get Remote)" = no ]; then rec OK "sessione locale (non remota): avviata dalla schermata di accesso"; else rec FAIL "sessione remota"; fi
  echo "INFO servizio PAM della sessione: $(get Service); desktop: $(get Desktop)" | tee -a "$LOG"

  # Componenti del desktop in esecuzione per l'utente.
  sleep 25
  procs=$(vm_ssh "pgrep -u $user -a" 2>/dev/null); echo "$procs" >> "$ev"
  for p in kwin_wayland plasmashell; do
    if echo "$procs" | grep -qE "(^|/| )$p( |$)"; then rec OK "$p in esecuzione"; else rec FAIL "$p non in esecuzione"; fi
  done
  # Nome reale del display Wayland, letto dall'ambiente di plasmashell (non si presume wayland-0).
  wdisp=$(vm_ssh "pid=\$(pgrep -u $user -x plasmashell | head -1); tr '\\0' '\\n' < /proc/\$pid/environ | sed -n 's/^WAYLAND_DISPLAY=//p'" 2>/dev/null)
  echo "INFO WAYLAND_DISPLAY di plasmashell: ${wdisp:-non trovato}; socket: $(vm_ssh "ls /run/user/$uid/ | grep -E '^wayland' | tr '\n' ' '" 2>/dev/null)" | tee -a "$LOG" "$ev"
  wdisp=${wdisp:-wayland-0}
  if vm_ssh "test -S /run/user/$uid/$wdisp"; then rec OK "socket Wayland /run/user/$uid/$wdisp presente"; else rec FAIL "socket Wayland /run/user/$uid/$wdisp assente"; fi
  pid_before=$(vm_ssh "pgrep -u $user -x plasmashell; pgrep -u $user -x kwin_wayland" 2>/dev/null | tr '\n' ' ')
  shot 03-desktop-plasma

  # Il desktop risponde: chiamate D-Bus a plasmashell e KWin nella sessione dell'utente.
  ubus="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
  expect_ok "plasmashell risponde su D-Bus" vm_ssh "runuser -u $user -- env $ubus timeout 10 busctl --user call org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Peer Ping"
  expect_ok "KWin risponde su D-Bus" vm_ssh "runuser -u $user -- env $ubus timeout 10 busctl --user call org.kde.KWin /KWin org.freedesktop.DBus.Peer Ping"

  # Interazione: apertura di un'applicazione (Impostazioni di sistema) nella sessione.
  vm_ssh "runuser -u $user -- env $ubus XDG_RUNTIME_DIR=/run/user/$uid WAYLAND_DISPLAY=$wdisp QT_QPA_PLATFORM=wayland setsid -f systemsettings >/dev/null 2>&1" >> "$LOG" 2>&1
  sleep 20
  if vm_ssh "pgrep -u $user -x systemsettings" >/dev/null 2>&1; then rec OK "applicazione 'systemsettings' aperta e in esecuzione dopo 20 s"; else rec FAIL "applicazione 'systemsettings' non in esecuzione"; fi
  shot 04-applicazione-aperta
  vm_ssh "pkill -u $user -x systemsettings" >/dev/null 2>&1 || true

  # Assenza di blocchi o riavvii: stessi PID dopo l'uso, nessun core dump.
  sleep 10
  pid_after=$(vm_ssh "pgrep -u $user -x plasmashell; pgrep -u $user -x kwin_wayland" 2>/dev/null | tr '\n' ' ')
  if [ -n "$pid_before" ] && [ "$pid_before" = "$pid_after" ]; then rec OK "plasmashell e kwin_wayland stabili (stessi PID: $pid_after)"; else rec FAIL "PID cambiati o assenti ('$pid_before' → '$pid_after')"; fi
  cores=$(vm_ssh "coredumpctl list --no-legend 2>/dev/null | grep -Ei 'plasma|kwin|plasmalogin' || true" 2>/dev/null)
  if [ -z "$cores" ]; then rec OK "nessun core dump di componenti Plasma"; else rec FAIL "core dump: $cores"; fi
  errs=$(vm_ssh "journalctl -b _UID=$uid -p err --no-pager -o cat | wc -l" 2>/dev/null)
  echo "INFO righe di errore nel journal della sessione utente: $errs" | tee -a "$LOG"
  vm_ssh "journalctl -b _UID=$uid -p err --no-pager -o cat | head -40" >> "$ev" 2>&1
  if command -v compare >/dev/null; then
    diffpx=$(compare -metric AE "$w/01-schermata-accesso.png" "$w/03-desktop-plasma.png" null: 2>&1 || true)
    echo "INFO pixel diversi fra schermata di accesso e desktop: $diffpx" | tee -a "$LOG"
  fi
fi

# Pulizia: chiusura della sessione ed eliminazione dell'utente e delle credenziali.
vm_ssh "loginctl terminate-user $user" >/dev/null 2>&1 || true
sleep 5
expect_ok "utente temporaneo eliminato (userdel -r)" vm_ssh "userdel -r -f $user"
expect_fail "utente non più presente" vm_ssh "id $user"
expect_fail "nessuna voce di password residua" vm_ssh "getent shadow $user"
unset pw
vm_stop "$w"
res_end
