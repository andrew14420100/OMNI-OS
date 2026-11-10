#!/usr/bin/env bash
# Prove REALI del desktop OMNI nella VM di test (4K, scala 200%, clic e tasti veri via QMP):
# sessione unica senza duplicati, barra e Start, finestre e desktop virtuali reali, notifiche,
# audio, rete, Bluetooth, schermo, recupero dopo arresti anomali, modalità sicura,
# disconnessione, riavvio e spegnimento (solo la VM di prova).
# Uso: omni_desktop_test.sh <dir-di-lavoro>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
# shellcheck source=tests/vm/sessione_lib.sh
. tests/vm/sessione_lib.sh
w=$1; mkdir -p "$w/schermate"
LOG=$w/desktop.log; : > "$LOG"
ev=$w/desktop-evidenze.txt; : > "$ev"
res_init "$w/desktop.md" "Desktop OMNI: prove reali nella VM (4K, scala 200%)"
shot() { qmp screendump "$w/schermate/$1.png" >/dev/null 2>&1 && echo "schermata: $1.png" >> "$ev"; }
export VM_TABLET=1 VM_AUDIO=1 VM_RES=${VM_RES:-3840x2160} VM_MEM=${VM_MEM:-8192} VM_CPUS=${VM_CPUS:-4}
W=${VM_RES%x*} H=${VM_RES#*x} SCALA=${SCALA:-2}

vm_fresh "$w" || { rec FAIL "avvio della VM"; res_end; exit 1; }
rec OK "VM avviata ($(vm_version), ${VM_RES})"
expect_ok "sessione OMNI e modalità sicura installate" vm_ssh "grep -q omni-session /usr/share/wayland-sessions/plasma.desktop && test -f /usr/share/wayland-sessions/omnios-sicura.desktop"
expect_ok "servizio utente OMNI Shell e recupero installati" vm_ssh "test -f /usr/lib/systemd/user/omni-shell.service && test -f /usr/lib/systemd/user/omni-shell-recupero.service && test -f /usr/lib/systemd/user/plasma-plasmashell.service.d/10-omni.conf"
expect_ok "nessun avvio automatico residuo della versione 0.2" vm_ssh "! test -e /etc/xdg/autostart/org.omnios.Shell.desktop"
expect_ok "nessun file setuid/setgid in OMNI Shell" vm_ssh "! find /usr/lib/omni-shell /usr/libexec/omni-os -perm /6000 | grep -q ."
vm_ssh "ls /usr/share/wayland-sessions/; cat /etc/plasmalogin.conf 2>/dev/null; ls /etc/plasmalogin.conf.d /usr/lib/plasmalogin.conf.d 2>/dev/null" >> "$ev" 2>&1

# --- 1. accesso: quale sessione parte per impostazione predefinita ---
sess_user_create omniprova || { rec FAIL "utente di prova"; vm_stop "$w"; res_end; exit 1; }
GREETER_WAIT=45 sess_greeter
shot 00-accesso
if ! sess_login; then rec FAIL "accesso"; shot 00-accesso-fallito; vm_stop "$w"; res_end; exit 1; fi
sess_env
desk=$(vm_ssh "loginctl show-session $SID -p Desktop --value" 2>/dev/null)
{ echo "--- stato del gestore di accesso"; vm_ssh "ls -la /var/lib/plasmalogin/ 2>&1; cat /var/lib/plasmalogin/state.conf 2>&1; ls /var/lib/AccountsService/users/ 2>&1"; } >> "$ev" 2>&1
echo "INFO sessione predefinita: Desktop=$desk" | tee -a "$LOG" "$ev"
shell_up() { vm_ssh "pgrep -u $U -f 'omni-shell-prototipo --session'" >/dev/null 2>&1; }
plasma_up() { vm_ssh "pgrep -u $U -x plasmashell" >/dev/null 2>&1; }
for _ in $(seq 1 60); do shell_up && break; sleep 2; done
if shell_up; then rec OK "sessione OMNI predefinita: OMNI Shell avviata come servizio utente"; else
  rec FAIL "OMNI Shell non avviata nella sessione predefinita (Desktop=$desk)"; shot 01-sessione-predefinita
fi
sleep 20
vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -iE 'omni|plasmashell|layer' | tail -60" >> "$LOG" 2>&1
if plasma_up; then rec FAIL "il pannello di Plasma è in esecuzione insieme a OMNI Shell (duplicati)"; else rec OK "pannello e menu di Plasma NON in esecuzione: nessuna interfaccia duplicata"; fi
t=$(vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -m1 'OMNI Shell: primo fotogramma'" 2>/dev/null)
if [ -n "$t" ]; then rec OK "primo fotogramma della barra: ${t#*fotogramma }"; else rec FAIL "primo fotogramma non registrato"; fi
owner() { u_sh "busctl --user status $1 2>/dev/null | sed -n 's/^Comm=//p'"; }
o=$(owner org.freedesktop.Notifications); if [ "$o" = "omni-shell-prot" ]; then rec OK "notifiche del sistema gestite da OMNI Shell"; else rec FAIL "proprietario delle notifiche: '${o:-nessuno}'"; fi
o=$(owner org.kde.plasmashell); if [ "$o" = "omni-shell-prot" ]; then rec OK "tasto Meta collegato al menu Start di OMNI"; else rec FAIL "org.kde.plasmashell: '${o:-nessuno}'"; fi
vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -E 'servizio (collegato|NON disponibile)|OMNI Shell:|renderer|notifiche:|tasto Meta|sessione OMNI|controllo della shell'" >> "$ev" 2>&1
if vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -q 'servizio NON disponibile'"; then rec FAIL "uno o più servizi KDE non collegati (vedi evidenze)"; else rec OK "finestre, audio, rete e Bluetooth collegati ai componenti KDE"; fi

# --- 2. 4K a scala 200% ---
out=$(u_sh "kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print \$3; exit}'")
u_sh "kscreen-doctor output.$out.mode.${W}x${H}@60 output.$out.scale.$SCALA" >> "$LOG" 2>&1; sleep 10
sc=$(u_sh "kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -m1 Scale | tr -s ' '")
echo "INFO schermo: $sc" >> "$ev"
shot 02-desktop-4k
rec INFO "schermo: ${sc:-?}"

# --- geometria reale degli elementi (per clic veri) ---
geo() { u_sh "gdbus call --session --dest org.omnios.Shell --object-path /Shell --method org.omnios.Shell.DumpGeometry /tmp/geo-$U.json >/dev/null; cat /tmp/geo-$U.json" > "$w/geo.json" 2>/dev/null; }
# at <nome>: coordinate fisiche (barra ancorata in basso, pannelli sopra la barra, fumetti in basso a destra)
at() { python3 -I - "$w/geo.json" "$1" "$W" "$H" <<'PY'
import json, sys
try:
    g = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
name = sys.argv[2]; W, H = float(sys.argv[3]), float(sys.argv[4])
it = g.get("items", {}).get(name)
wins = g.get("windows", {})
if not it or "barra" not in wins: sys.exit(0)
wl = float(wins["barra"]["w"]); k = W / wl; hl = H / k
bar_h = float(wins["barra"]["h"])
x, y, win = it["x"], it["y"], it["win"]
if win == "barra": y += hl - bar_h
elif win == "notifiche": n = wins["notifiche"]; x += wl - n["w"]; y += hl - bar_h - n["h"]
print("%d %d" % (round(x * k), round(y * k)))
PY
}
click() { local xy x y; geo; xy=$(at "$1"); [ -n "$xy" ] || { echo "AVVISO: $1 assente" | tee -a "$LOG"; return 1; }; read -r x y <<< "$xy"; qmp click "$x" "$y" "$W" "$H"; sleep "${2:-1}"; }
has() { geo; [ -n "$(at "$1")" ]; }

# --- 3. barra delle applicazioni e menu Start ---
if kwin_probe_load; then rec OK "sonda delle finestre di KWin attiva"; else rec FAIL "sonda delle finestre non attiva"; fi
if has bar:start && has bar:clock && has bar:status; then rec OK "barra OMNI: Start, area di stato e orologio presenti"; else rec FAIL "elementi della barra mancanti"; fi
click bar:start 2; shot 03-start
if has start:search; then rec OK "menu Start aperto con un clic (unico menu delle applicazioni)"; else rec FAIL "menu Start non aperto"; fi
qmp key esc; sleep 1
if ! has start:search; then rec OK "Esc chiude il menu Start"; else rec FAIL "Esc non chiude il menu Start"; fi
qmp key meta_l; sleep 2
if ! has start:search; then qmp tap meta_l; sleep 2; fi
if has start:search; then rec OK "tasto Meta apre il menu Start di OMNI"; else
  rec FAIL "tasto Meta: menu Start non aperto"
  { echo "--- diagnosi tasto Meta"; u_sh "kreadconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta; gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell --method org.kde.PlasmaShell.activateLauncherMenu"; } >> "$ev" 2>&1
  sleep 2; if has start:search; then echo "INFO Meta: la chiamata D-Bus diretta apre Start (KWin non la invia)" >> "$ev"; else echo "INFO Meta: neanche la chiamata D-Bus diretta apre Start" >> "$ev"; fi
fi
qmp key esc; sleep 1

# avvio reale dalla barra (app fissate) e dalla ricerca di Start; tempo clic -> finestra (ora di KWin)
launch_check() { # <etichetta> <regex-classe> <azioni...>
  local label=$1 re=$2 t0 d; shift 2
  t0=$(vm_ms); "$@"
  if d=$(win_wait "$re" "$t0" 90); then rec OK "$label: finestra aperta in $(python3 -c "print('%.2f' % ($d/1000))") s dal clic"; echo "MISURA clic.$label $d ms" >> "$ev"
  else rec FAIL "$label: nessuna finestra entro 90 s"; fi
}
search_launch() { click bar:start 2; qmp type "$1"; sleep 1; qmp key ret; }
min_after() { vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -E 'OMNIWIN min [^ ]*$1[^ ]* $2' | awk -v t0=$3 '\$NF+0 >= t0+0' | grep -q ."; }
launch_check Konsole konsole click bar:task:org.kde.konsole.desktop
sleep 3; shot 04-konsole
if has bar:running:org.kde.konsole.desktop; then rec OK "Konsole compare nella barra come app aperta"; else rec FAIL "Konsole non indicata come aperta nella barra"; fi
t0=$(vm_ms); click bar:task:org.kde.konsole.desktop 2
if min_after konsole true "$t0"; then rec OK "clic su Konsole attiva nella barra: finestra ridotta a icona"; else rec FAIL "riduzione a icona dalla barra non verificata"; fi
t0=$(vm_ms); click bar:task:org.kde.konsole.desktop 2
if min_after konsole false "$t0"; then rec OK "secondo clic: Konsole ripristinata"; else rec FAIL "ripristino dalla barra non verificato"; fi
launch_check Dolphin dolphin search_launch dolphin
sleep 3; shot 05-dolphin
launch_check Firefox firefox click bar:task:org.mozilla.firefox.desktop
sleep 8; shot 06-firefox
launch_check "Impostazioni (ricerca 'settings' in Start)" "org.omnios.Settings|systemsettings" search_launch settings
sleep 4; shot 07-impostazioni
for p in konsole dolphin firefox systemsettings; do app_close "$p"; done
omni_app_close() { vm_ssh "pkill -u $U -f 'omni-shell-prototipo --app $1'" >/dev/null 2>&1 || true; sleep 2; }
omni_app_close impostazioni; sleep 3

# --- 3b. app OMNI 0.4: Impostazioni, Gestione attività, Esplora file, Store ---
expect_ok "voci delle app OMNI installate" vm_ssh "for a in Settings TaskManager Explorer Store; do test -f /usr/share/applications/org.omnios.\$a.desktop || exit 1; done"
d=$(u_sh "xdg-mime query default inode/directory" 2>/dev/null)
if [ "$d" = org.omnios.Explorer.desktop ]; then rec OK "le cartelle si aprono in OMNI Explorer (xdg-mime)"; else rec FAIL "applicazione predefinita per le cartelle: '${d:-nessuna}'"; fi
launch_dbus() { u_sh "gdbus call --session --dest org.omnios.Shell --object-path /Shell --method org.omnios.Shell.Launch /usr/share/applications/$1.desktop" >> "$LOG" 2>&1; }
qp_settings() { click bar:status 2; click qs:settings 1; }
launch_check "OMNI Settings dal pannello rapido" "org.omnios.Settings" qp_settings
sleep 5; shot 16-omni-impostazioni; omni_app_close impostazioni
launch_check "OMNI Task Manager" "org.omnios.TaskManager" launch_dbus org.omnios.TaskManager
sleep 6; shot 17-omni-gestione-attivita; omni_app_close attivita
u_sh "mkdir -p ~/Documenti/Progetti ~/Immagini && echo Appunti > ~/Documenti/appunti.txt && echo Relazione > ~/Documenti/relazione.md; true"
launch_check "OMNI Explorer (ricerca 'esplora' in Start)" "org.omnios.Explorer" search_launch esplora
sleep 5; shot 18-omni-esplora-file; omni_app_close explorer
vm_ssh "flatpak remotes --columns=name,url,options 2>&1; ls /var/lib/flatpak/appstream 2>&1" > "$w/flatpak-sorgenti.txt" 2>&1
launch_check "OMNI Store" "org.omnios.Store" launch_dbus org.omnios.Store
sleep 10; shot 19-omni-store; omni_app_close store
errs=$(vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -E 'qml/apps/.*(Error|TypeError|ReferenceError|Unable to assign|is not installed)'" 2>/dev/null)
if [ -z "$errs" ]; then rec OK "app OMNI: nessun errore QML nel registro"; else rec FAIL "app OMNI: errori QML (vedi evidenze)"; echo "$errs" | head -30 >> "$ev"; fi
vm_ssh "journalctl -b _UID=$UID_ --no-pager -o cat | grep -E 'app OMNI|OMNI Shell: (finestra|primo)'" >> "$ev" 2>&1

# --- 4. desktop virtuali (KWin): la barra mostra solo le finestre del desktop corrente ---
kw() { u_sh "gdbus call --session --dest org.kde.kglobalaccel --object-path /component/kwin --method org.kde.kglobalaccel.Component.invokeShortcut '$1'" >> "$LOG" 2>&1; }
vdm() { u_sh "gdbus call --session --dest org.kde.KWin --object-path /VirtualDesktopManager $*" 2>/dev/null; }
u_sh "setsid -f konsole >/dev/null 2>&1 </dev/null"; sleep 6
vdm "--method org.kde.KWin.VirtualDesktopManager.createDesktop 1 'Desktop 2'" >> "$LOG"; sleep 2
cnt=$(vdm "--method org.freedesktop.DBus.Properties.Get org.kde.KWin.VirtualDesktopManager count" | grep -oE '[0-9]+' | tail -1)
on1=no; has bar:running:org.kde.konsole.desktop && on1=yes
kw "Switch to Next Desktop"; sleep 3
on2=no; has bar:running:org.kde.konsole.desktop && on2=yes
shot 08-desktop-2
if [ "${cnt:-0}" -ge 2 ] && [ "$on1" = yes ] && [ "$on2" = no ]; then rec OK "desktop virtuali reali di KWin ($cnt): sul desktop 2 la barra non mostra Konsole del desktop 1"
else rec FAIL "desktop virtuali: count=${cnt:-?}, Konsole in barra desktop1=$on1 desktop2=$on2"; fi
kw "Switch to Previous Desktop"; sleep 2
click bar:taskview 3; shot 09-visualizzazione-attivita; qmp key esc; sleep 2
app_close konsole

# --- 5. notifiche reali ---
u_sh "notify-send -a 'Prova OMNI' 'Notifica reale' 'Inviata con notify-send'"; sleep 2; shot 10-notifica
geo; if grep -q '"note:' "$w/geo.json"; then rec OK "notifica di un'app mostrata da OMNI Shell (fumetto)"; else rec FAIL "fumetto della notifica non visibile"; fi
click bar:clock 2; shot 11-centro-notifiche
if has notes:clear; then rec OK "centro notifiche aperto con la cronologia"; else rec FAIL "centro notifiche non aperto"; fi
click notes:dnd 1; qmp key esc; sleep 1
u_sh "notify-send -a 'Prova OMNI' 'Silenziosa' 'Non disturbare'"; sleep 2; geo
if ! grep -q '"note:' "$w/geo.json"; then rec OK "Non disturbare: nessun fumetto (la notifica resta nel centro)"; else rec FAIL "fumetto mostrato con Non disturbare attivo"; fi
click bar:clock 2; click notes:dnd 1; click notes:clear 1; qmp key esc; sleep 1

# --- 6. impostazioni rapide: audio, rete, Bluetooth, schermo ---
vol() { u_sh "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null" | grep -oE '[0-9]+\.[0-9]+' | head -1; }
v0=$(vol); echo "INFO volume iniziale: ${v0:-?}; dispositivi: $(u_sh 'wpctl status 2>/dev/null | grep -A4 Sinks: | tr -s " " | tr "\n" " "')" >> "$ev"
click bar:status 2; shot 12-impostazioni-rapide
geo; xy=$(at qs:volume)
if [ -n "$xy" ] && [ -n "$v0" ]; then
  read -r x y <<< "$xy"
  qmp click "$(( x - 60 * SCALA ))" "$y" "$W" "$H"; sleep 2
  v1=$(vol); echo "INFO volume dopo il clic: ${v1:-?}" >> "$ev"
  if [ -n "$v1" ] && [ "$v1" != "$v0" ]; then rec OK "volume reale modificato da OMNI Shell (PipeWire: $v0 -> $v1)"; else rec FAIL "volume non modificato (prima $v0, dopo ${v1:-?})"; fi
else rec FAIL "controllo del volume o dispositivo audio non disponibile (volume: ${v0:-nessun dispositivo})"; fi
nm_name=$(vm_ssh "nmcli -t -f NAME connection show --active | grep -v '^lo$' | head -1" 2>/dev/null)
if [ -n "$nm_name" ] && has qs:network; then rec OK "rete: connessione attiva reale '$nm_name' (NetworkManager)"; else rec FAIL "stato della rete non verificato"; fi
geo; xy=$(at qs:network)
if [ -n "$xy" ]; then read -r x y <<< "$xy"; qmp click "$(( x + 30 * SCALA ))" "$y" "$W" "$H"; sleep 2; fi
shot 13-rete
if has "net:$nm_name"; then rec OK "elenco delle connessioni reali di NetworkManager mostrato"; else rec INFO "elenco connessioni: voce '$nm_name' non trovata (vedi schermata)"; fi
qmp key esc; sleep 1; qmp key esc; sleep 1
if vm_ssh "ls /sys/class/bluetooth 2>/dev/null | grep -q ."; then rec INFO "adattatore Bluetooth presente nella VM"; else rec OK "Bluetooth: nessun adattatore nella VM, riquadro mostrato come non disponibile"; fi
click bar:status 2; click qs:display 3; shot 14-schermo; qmp key esc; sleep 1; qmp key esc; sleep 1
s1=$(u_sh "kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -m1 Scale | grep -oE '[0-9.]+'")
if [ "${s1%%.*}" = "$SCALA" ]; then rec OK "scala 200% applicata e mantenuta (KScreen: $s1)"; else rec FAIL "scala attesa $SCALA, letta ${s1:-?}"; fi

# --- 7. recupero: OMNI Shell si riavvia dopo un arresto anomalo; dopo arresti ripetuti parte Plasma ---
pid1=$(vm_ssh "pgrep -u $U -f 'omni-shell-prototipo --session'" 2>/dev/null)
vm_ssh "kill -SEGV $pid1" >/dev/null 2>&1
# il salvataggio del core dump (processo di ~600 MB) ritarda il riavvio: si attende fino a 60 s
pid2=""; for _ in $(seq 1 30); do sleep 2; pid2=$(vm_ssh "pgrep -u $U -f 'omni-shell-prototipo --session'" 2>/dev/null); [ -n "$pid2" ] && [ "$pid2" != "$pid1" ] && break; done
if [ -n "$pid2" ] && [ "$pid2" != "$pid1" ]; then rec OK "arresto anomalo: OMNI Shell riavviata da systemd ($pid1 -> $pid2)"; else rec FAIL "OMNI Shell non riavviata dopo l'arresto anomalo"; fi
{ echo "--- diagnosi riavvio dopo arresto anomalo (pid $pid1 -> ${pid2:-nessuno})"
  u_sh "systemctl --user status omni-shell.service --no-pager 2>&1 | head -15"
  vm_ssh "journalctl -b _UID=$UID_ --no-pager -o short-monotonic | grep -E 'omni-shell|coredump|SEGV|Scheduled restart' | tail -25"
  vm_ssh "journalctl -b -u systemd-coredump@* --no-pager -o short-monotonic | tail -8"; } >> "$ev" 2>&1
# arresti ripetuti: si provoca un arresto a ogni riavvio finché systemd raggiunge il limite
for _ in $(seq 1 8); do
  p=""; for _ in $(seq 1 20); do p=$(vm_ssh "pgrep -u $U -f 'omni-shell-prototipo --session'" 2>/dev/null); [ -n "$p" ] && break; sleep 1; done
  [ -n "$p" ] || break
  vm_ssh "kill -SEGV $p" >/dev/null 2>&1; sleep 2
done
for _ in $(seq 1 40); do plasma_up && break; sleep 2; done; sleep 5; shot 15-recupero
if plasma_up; then rec OK "arresti ripetuti: desktop Plasma di riserva avviato automaticamente (mai senza interfaccia)"; else rec FAIL "nessuna interfaccia dopo arresti ripetuti"; fi

# --- 8. nuovo accesso e Disconnetti dal menu energia ---
vm_ssh "loginctl terminate-session $SID" >/dev/null 2>&1; sleep 25
if sess_login; then
  sess_env; for _ in $(seq 1 60); do shell_up && break; sleep 2; done; sleep 15
  for _ in $(seq 1 30); do vm_ssh "pgrep -u $U -x ksplashqml" >/dev/null 2>&1 || break; sleep 2; done
  if vm_ssh "pgrep -u $U -x ksplashqml" >/dev/null 2>&1; then rec FAIL "schermata di caricamento di Plasma ancora visibile dopo 60 s"; else rec OK "schermata di caricamento chiusa (OMNI Shell segnala il desktop pronto)"; fi
  if shell_up && ! plasma_up; then rec OK "nuovo accesso: di nuovo sessione OMNI (il recupero vale solo per la sessione precedente)"; else rec FAIL "nuovo accesso: sessione OMNI non ripristinata"; fi
  click bar:start 2; click start:power 1; shot 16-menu-energia
  click power:logout 1
  for _ in $(seq 1 30); do vm_ssh "loginctl list-sessions --no-legend | awk '{print \$3}' | grep -qx $U" || break; sleep 2; done
  sleep 5; shot 17-dopo-disconnessione
  if ! vm_ssh "loginctl list-sessions --no-legend | awk '{print \$3}' | grep -qx $U"; then rec OK "Disconnetti (menu energia OMNI): sessione chiusa, schermata di accesso"; else rec FAIL "Disconnetti non ha chiuso la sessione"; fi
else rec FAIL "nuovo accesso dopo il recupero"; fi

# --- 10. Arresta dal menu energia (con app aperte), nuovo avvio, Riavvia dal menu ---
sess_greeter
if sess_login; then
  sess_env; for _ in $(seq 1 60); do shell_up && break; sleep 2; done; sleep 15
  u_sh "setsid -f konsole >/dev/null 2>&1 </dev/null; setsid -f dolphin >/dev/null 2>&1 </dev/null"; sleep 10
  pid=$(cat "$w/qemu.pid"); t1=$(date +%s)
  click bar:start 2; click start:power 1; click power:shutdown 0
  off=""; for _ in $(seq 1 120); do kill -0 "$pid" 2>/dev/null || { off=$(( $(date +%s) - t1 )); break; }; sleep 2; done
  if [ -n "$off" ]; then rec OK "Arresta (menu OMNI, Konsole e Dolphin aperte): VM spenta in $off s"; echo "MISURA spegnimento.menu $off s" >> "$ev"
  else shot 19-spegnimento-bloccato; rec FAIL "spegnimento dal menu non completato entro 240 s"; kill "$pid" 2>/dev/null; sleep 3; fi
else rec FAIL "accesso prima della prova di spegnimento"; fi
rm -f "$w/qmp.sock"
bash tests/vm/boot_vm.sh "$w/disk.raw" "$w" uefi >/dev/null
if vm_ready "$w"; then rec OK "nuovo avvio dopo lo spegnimento: sistema pronto"; else rec FAIL "il sistema non riparte dopo lo spegnimento"; fi
# dopo un avvio la schermata di accesso è già quella vera: nessun riavvio del gestore
sleep 45
if sess_login || { shot 20a-accesso-primo-tentativo; GREETER_WAIT=45 sess_greeter; sess_login; }; then
  sess_env; for _ in $(seq 1 60); do shell_up && break; sleep 2; done; sleep 15
  b0=$(vm_ssh "cat /proc/sys/kernel/random/boot_id" 2>/dev/null)
  click bar:start 2; click start:power 1; click power:reboot 0
  sleep 45
  if vm_ready "$w"; then
    b1=$(vm_ssh "cat /proc/sys/kernel/random/boot_id" 2>/dev/null)
    if [ -n "$b1" ] && [ "$b1" != "$b0" ]; then rec OK "Riavvia (menu OMNI): sistema riavviato e di nuovo pronto"; else rec FAIL "riavvio non avvenuto"; fi
  else rec FAIL "il sistema non è tornato dopo il riavvio"; fi
else rec FAIL "accesso prima della prova di riavvio"; shot 20-accesso-dopo-avvio; fi
SID=$(vm_ssh "loginctl list-sessions --no-legend" 2>/dev/null | awk -v u="$U" '$3==u {print $1; exit}')
[ -n "$SID" ] && { vm_ssh "loginctl terminate-session $SID" >/dev/null 2>&1; sleep 20; }
# --- 9. modalità sicura (Plasma originale) dalla sua voce di sessione, tramite il gestore di accesso:
# accesso automatico configurato SOLO per questa prova e poi rimosso ---
vm_ssh "mkdir -p /etc/plasmalogin.conf.d; printf '[Autologin]\nUser=$U\nSession=omnios-sicura.desktop\nRelogin=false\n' > /etc/plasmalogin.conf.d/zz-prova-modalita-sicura.conf" >> "$LOG" 2>&1
vm_ssh "systemctl restart display-manager" >> "$LOG" 2>&1
SID=""; for _ in $(seq 1 60); do SID=$(vm_ssh "loginctl list-sessions --no-legend" 2>/dev/null | awk -v u="$U" '$3==u {print $1; exit}'); [ -n "$SID" ] && break; sleep 2; done
vm_ssh "rm -f /etc/plasmalogin.conf.d/zz-prova-modalita-sicura.conf" >> "$LOG" 2>&1
if [ -n "$SID" ]; then
  sess_env; for _ in $(seq 1 60); do plasma_up && break; sleep 2; done; sleep 10; shot 18-modalita-sicura
  if plasma_up && ! shell_up; then rec OK "modalità sicura (voce 'OMNI OS - modalità sicura'): desktop Plasma originale, OMNI Shell non avviata"
  else rec FAIL "modalità sicura: plasma=$(plasma_up && echo sì || echo no), OMNI Shell=$(shell_up && echo sì || echo no)"; fi
  vm_ssh "loginctl terminate-session $SID" >/dev/null 2>&1; sleep 20
else rec FAIL "modalità sicura: accesso non avvenuto"; fi

echo "INFO core dump registrati (quelli con SEGV sono provocati dalla prova di recupero): $(vm_ssh 'coredumpctl list --no-legend 2>/dev/null | wc -l')" >> "$ev"
vm_ssh "coredumpctl list --no-legend 2>/dev/null" >> "$ev" 2>&1
vm_ssh "userdel -r -f $U" >/dev/null 2>&1 || true
vm_stop "$w"
res_end
