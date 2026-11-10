#!/usr/bin/env bash
# Misure REALI di prestazioni e comportamento nella VM di test (QEMU/KVM, grafica software
# llvmpipe: è il caso peggiore, senza accelerazione 3D). Stessa procedura per ogni versione,
# così il confronto prima/dopo è equo.
#
# Uso: prestazioni.sh <dir-di-lavoro> <etichetta>
# Variabili: VM_RES (predefinito 3840x2160), SCALA (predefinito 2), SPEGNIMENTO=1 per provare
# spegnimento e riavvio (via org.kde.Shutdown, come i pulsanti del desktop).
# Produce: misure.tsv (chiave, valore, unità, nota), prestazioni.md, esplorazione.txt, schermate/.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
# shellcheck source=tests/vm/sessione_lib.sh
. tests/vm/sessione_lib.sh
w=$1 etichetta=$2; mkdir -p "$w/schermate"
LOG=$w/prestazioni.log; : > "$LOG"
M=$w/misure.tsv; printf 'chiave\tvalore\tunita\tnota\n' > "$M"
X=$w/esplorazione.txt; : > "$X"
res_init "$w/prestazioni.md" "Prestazioni e comportamento in VM: $etichetta"
m() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}" >> "$M"; echo "MISURA $1 = $2 $3 ${4:-}" | tee -a "$LOG"; }
shot() { qmp screendump "$w/schermate/$1.png" >/dev/null 2>&1 || true; }
sec() { python3 -c 'import sys; print("%.2f" % (float(sys.argv[1]) - float(sys.argv[2])))' "$1" "$2"; }

export VM_TABLET=1 VM_RES=${VM_RES:-3840x2160} VM_MEM=${VM_MEM:-8192} VM_CPUS=${VM_CPUS:-4}
W=${VM_RES%x*} H=${VM_RES#*x}
vm_fresh "$w" || { rec FAIL "avvio della VM"; res_end; exit 1; }
rec OK "VM avviata ($etichetta, $(vm_version), ${VM_RES}, ${VM_CPUS} CPU, $((VM_MEM / 1024)) GB)"

# --- 1. avvio del sistema ---
sa=$(vm_ssh "systemd-analyze" 2>/dev/null | head -3); echo "$sa" >> "$X"
tot=$(echo "$sa" | grep -oE '= [0-9.]+(min )?[0-9.]*s' | head -1)
m avvio.systemd-analyze "$(echo "$sa" | head -1 | tr '\t' ' ')" "" "firmware+loader+kernel+initrd+userspace"
dm=$(vm_ssh "systemctl show display-manager -p ActiveEnterTimestampMonotonic --value" 2>/dev/null)
[ -n "$dm" ] && m avvio.schermata-accesso "$(python3 -c "print('%.1f' % (int('$dm')/1e6))")" s "dall'avvio del kernel al gestore di accesso attivo"
{ echo "=== systemd-analyze blame (prime 30)"; vm_ssh "systemd-analyze blame --no-pager | head -30"
  echo "=== critical-chain display-manager"; vm_ssh "systemd-analyze critical-chain display-manager.service --no-pager"
  echo "=== servizi di sistema abilitati"; vm_ssh "systemctl list-unit-files --state=enabled --no-legend --no-pager"
  echo "=== servizi utente abilitati (globali)"; vm_ssh "systemctl --global list-unit-files --state=enabled --no-legend --no-pager"
} >> "$X" 2>&1
[ -n "$tot" ] && rec OK "avvio misurato: $tot"

# --- 2. esplorazione dei componenti disponibili (per collegare servizi reali) ---
{ echo "=== pacchetti"; vm_ssh "rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}\n' | grep -iE '^(layer-shell-qt|plasma-workspace|plasma-nm|plasma-pa|bluez-qt|kf6-bluez-qt|kscreen|libkscreen|kf6-kscreen|kwayland|kwin|powerdevil|plasmalogin|libplasma|plasma-desktop|qt6-qtsvg|qt6-qtwayland|qt6-qtbase|qt6-qtdeclarative|mesa-dri-drivers|virtualbox-guest-additions|open-vm-tools|spice-vdagent|qemu-guest-agent|NetworkManager|pipewire|wireplumber|bluez|power-profiles-daemon|tuned-ppd|baloo|kf6-baloo|plasma-discover|xdg-desktop-portal-kde|polkit-kde)' | sort"
  echo "=== moduli QML KDE"; vm_ssh "find /usr/lib64/qt6/qml/org/kde -maxdepth 4 -name qmldir | sed 's|/usr/lib64/qt6/qml/||; s|/qmldir||' | sort"
  echo "=== layer-shell QML"; vm_ssh "cat /usr/lib64/qt6/qml/org/kde/layershell/qmldir 2>&1; rpm -ql layer-shell-qt 2>&1 | head -30"
  echo "=== interfacce Wayland privilegiate (X-KDE-Wayland-Interfaces)"; vm_ssh "grep -l X-KDE-Wayland-Interfaces /usr/share/applications/*.desktop 2>/dev/null | while read -r f; do echo \"\$f: \$(grep -E '^(Exec|X-KDE-Wayland-Interfaces)=' \"\$f\" | tr '\n' ' ')\"; done"
  echo "=== sessioni"; vm_ssh "ls -la /usr/share/wayland-sessions /usr/share/xsessions 2>&1; for f in /usr/share/wayland-sessions/*.desktop; do echo \"--- \$f\"; cat \"\$f\"; done"
  echo "=== plasmalogin"; vm_ssh "systemctl cat display-manager --no-pager 2>&1 | head -40; find /etc /usr/lib /usr/share /var/lib -maxdepth 3 -iname '*plasmalogin*' 2>/dev/null; for f in \$(find /etc /usr/lib /usr/share -maxdepth 3 -iname '*plasmalogin*' -name '*.conf' 2>/dev/null); do echo \"--- \$f\"; cat \"\$f\"; done"
  echo "=== unità utente di Plasma"; vm_ssh "ls /usr/lib/systemd/user/ | grep -iE 'plasma|kwin|ksm|kde|pipewire|wireplumber|obex|baloo|xdg'; for f in plasma-plasmashell.service plasma-workspace.target plasma-core.target plasma-workspace-wayland.target plasma-kwin_wayland.service plasma-ksmserver.service plasma-polkit-agent.service plasma-xdg-desktop-portal-kde.service; do echo \"--- \$f\"; cat /usr/lib/systemd/user/\$f 2>&1; done"
  echo "=== layout e shell di Plasma"; vm_ssh "ls /usr/share/plasma/shells/ /usr/share/plasma/look-and-feel/ /usr/share/plasma/layout-templates/ 2>&1; ls /usr/share/plasma/shells/org.kde.plasma.desktop/contents/ 2>&1"
  echo "=== energia"; vm_ssh "for m in CanPowerOff CanReboot CanSuspend CanHibernate; do echo \"\$m: \$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager \$m 2>&1)\"; done; powerprofilesctl 2>&1 | head -12"
  echo "=== rete"; vm_ssh "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>&1; rfkill list 2>&1"
  echo "=== bluetooth"; vm_ssh "systemctl is-active bluetooth 2>&1; ls /sys/class/bluetooth 2>&1"
  echo "=== grafica"; vm_ssh "ls /usr/lib64/dri 2>&1 | head -30; lspci -nnk 2>/dev/null | grep -A3 -iE 'vga|display' | head -12"
} >> "$X" 2>&1

# --- 3. primo accesso (con creazione della cartella utente) ---
sess_user_create omniperf || { rec FAIL "utente di prova"; vm_stop "$w"; res_end; exit 1; }
GREETER_WAIT=45 sess_greeter
shot 00-schermata-accesso
if ! sess_login; then rec FAIL "accesso"; shot 00-accesso-fallito; vm_stop "$w"; res_end; exit 1; fi
sess_env
# pronto = il processo della shell grafica principale esiste e ha scritto la riga di avvio
ready_after() { # stampa i secondi fra LOGIN_T0 e la prima riga di avvio della shell (o del pannello Plasma)
  local s
  for _ in $(seq 1 90); do
    s=$(vm_ssh "journalctl -b _UID=$UID_ --no-pager -o short-monotonic | grep -E 'OMNI Shell: primo fotogramma|avvio delle applicazioni: |omni-shell.*pronta' | tail -1 | sed -E 's/^\\[ *([0-9.]+)\\].*/\\1/'" 2>/dev/null)
    if [ -n "$s" ] && python3 -c "import sys; sys.exit(0 if float('$s') > float('$LOGIN_T0') else 1)"; then sec "$s" "$LOGIN_T0"; return 0; fi
    sleep 2
  done
  return 1
}
if t=$(ready_after); then m accesso.primo "$t" s "dall'Invio alla shell pronta (prima volta: crea la cartella utente)"; rec OK "primo accesso: $t s"; else rec FAIL "shell non pronta dopo il primo accesso"; fi
sleep 15
{ echo "=== sessione: nomi D-Bus"; u_sh "busctl --user list --no-legend 2>/dev/null | awk '{print \$1, \$3}' | grep -vE '^:' | sort"
  echo "=== sessione: proprietario di org.freedesktop.Notifications"; u_sh "busctl --user status org.freedesktop.Notifications 2>&1 | grep -E '^(PID|Comm|CommandLine)='"
  echo "=== sessione: servizi utente in esecuzione"; u_sh "systemctl --user list-units --type=service --state=running --no-legend --no-pager"
  echo "=== sessione: audio"; u_sh "wpctl status 2>&1 | head -40"
  echo "=== sessione: schermo"; u_sh "kscreen-doctor -o 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | head -30"
  echo "=== sessione: processi dell'utente"; vm_ssh "ps -u $U -o pid,rss,comm --sort=-rss | head -40"
} >> "$X" 2>&1

# --- 4. 4K a scala 200% (configurazione dell'utente) ---
out=$(u_sh "kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print \$3; exit}'")
if [ -n "$out" ]; then
  u_sh "kscreen-doctor output.$out.mode.${W}x${H}@60 output.$out.scale.${SCALA:-2}" >> "$LOG" 2>&1
  sleep 8
  m schermo.configurazione "$(u_sh "kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'Modes|Scale|Geometry' | tr -s ' ' | tr '\n' ' '" | cut -c1-200)" "" "kscreen-doctor dopo l'impostazione"
fi
shot 01-desktop-4k
m memoria.disponibile "$(vm_ssh "awk '/MemAvailable/ {printf \"%.0f\", \$2/1024}' /proc/meminfo")" MB "dopo l'accesso"

# --- 4b. strumenti di misura dentro la VM (stesso metodo per ogni versione) ---
vm_scp tests/vm/misura_app.sh tests/vm/misura_start.sh root@127.0.0.1:/tmp/ >> "$LOG" 2>&1 || true
vm_ssh "chmod 755 /tmp/misura_app.sh /tmp/misura_start.sh" >> "$LOG" 2>&1
misura() { u_sh "bash /tmp/misura_app.sh $(printf '%q ' "$@")" 2>>"$LOG" | tail -1; }
campo() { sed -n "s/.*$1=\([0-9NA]*\).*/\1/p" <<< "$2"; }
# prima apertura di un'app dopo l'accesso (senza svuotare le cache): ciò che l'utente nota per primo
f=$(app_desktop "org.kde.konsole|konsole")
if [ -n "$f" ]; then
  r=$(misura gio "$(basename "$f")" konsole '(^|/)konsole( |$)')
  fw=$(campo finestra "$r"); fu=$(campo utilizzabile "$r")
  if [ -n "$fw" ]; then m app.Konsole.primo-dopo-accesso "$(python3 -c "print('%.2f' % ($fw/1000))")" s "prima app aperta dopo l'accesso; utilizzabile dopo ${fu:-NA} ms"; else rec FAIL "Konsole: prima apertura non misurata ($r)"; fi
  app_close konsole; sleep 3
fi
# reattività del menu Start (richiesta del tasto Meta -> contenuto visibile)
r=$(u_sh "bash /tmp/misura_start.sh 7" 2>>"$LOG" | tail -1)
if [ -n "$(campo apertura_mediana "$r")" ]; then
  m start.apertura "$(campo apertura_mediana "$r")" ms "mediana di 7, massimo $(campo apertura_max "$r") ms (include ~gdbus della misura)"
  m start.chiusura "$(campo chiusura_mediana "$r")" ms "mediana di 7, massimo $(campo chiusura_max "$r") ms"
else rec FAIL "reattività del menu Start non misurata ($r)"; fi

# --- 5. apertura delle applicazioni: a freddo (cache svuotate) e riapertura ---
for spec in "Konsole|konsole|org.kde.konsole|konsole" "Dolphin|dolphin|org.kde.dolphin|dolphin" "Firefox|firefox|org.mozilla.firefox|firefox" "Impostazioni|settings|org.kde.systemsettings|systemsettings"; do
  IFS='|' read -r nome q dsk proc <<< "$spec"
  f=$(app_desktop "$dsk|$proc"); [ -n "$f" ] || { rec FAIL "$nome: file .desktop non trovato"; continue; }
  vm_ssh "sync; echo 3 > /proc/sys/vm/drop_caches" >/dev/null 2>&1
  d=$(app_open_ms "$f" "$q")
  if [ -n "$d" ]; then m "app.$nome.freddo" "$(python3 -c "print('%.2f' % (${d% *}/1000))")" s "cache del disco svuotate${d#"${d% *}"}"; else rec FAIL "$nome: nessuna finestra entro 120 s (a freddo)"; fi
  sleep 4; shot "02-$nome"
  app_close "$proc"; sleep 3
  d=$(app_open_ms "$f" "$q")
  if [ -n "$d" ]; then m "app.$nome.riapertura" "$(python3 -c "print('%.2f' % (${d% *}/1000))")" s "subito dopo la chiusura${d#"${d% *}"}"; else rec FAIL "$nome: nessuna finestra entro 120 s (riapertura)"; fi
  sleep 3; app_close "$proc"; sleep 2
  # tempo all'utilizzabilità (caricamento finito: CPU dell'app a riposo), riapertura
  r=$(misura gio "$(basename "$f")" "$q" "(^|/)$proc( |\$)")
  fu=$(campo utilizzabile "$r")
  if [ -n "$fu" ] && [ "$fu" != NA ]; then m "app.$nome.utilizzabile" "$(python3 -c "print('%.2f' % ($fu/1000))")" s "riapertura: finestra dopo $(campo finestra "$r") ms, caricamento finito"; else rec INFO "$nome: utilizzabilità non misurata ($r)"; fi
  app_close "$proc"; sleep 2
done
# app OMNI di sistema (dalla 0.4; nella 0.3.0 non esistono): stesso metodo, chiusura mirata
oclose() { vm_ssh "pkill -u $U -f 'omni-shell-prototipo --app $1'" >/dev/null 2>&1; sleep 3; }
for spec in "OMNI-Impostazioni|org.omnios.Settings|impostazioni|Impostazioni" "OMNI-Esplora-file|org.omnios.Explorer|explorer|Esplora" "OMNI-Gestione-attivita|org.omnios.TaskManager|attivita|attivit"; do
  IFS='|' read -r nome dsk arg q <<< "$spec"
  if ! vm_ssh "test -f /usr/share/applications/$dsk.desktop"; then m "app.$nome.freddo" assente "" "app non presente in questa versione"; continue; fi
  vm_ssh "sync; echo 3 > /proc/sys/vm/drop_caches" >/dev/null 2>&1
  r=$(misura gio "$dsk.desktop" "$q" "omni-shell-prototipo --app $arg")
  if [ -n "$(campo finestra "$r")" ]; then m "app.$nome.freddo" "$(python3 -c "print('%.2f' % ($(campo finestra "$r")/1000))")" s "cache svuotate; utilizzabile dopo $(campo utilizzabile "$r") ms"; else rec FAIL "$nome: nessuna finestra (a freddo: $r)"; fi
  sleep 3; shot "02-$nome"; oclose "$arg"
  r=$(misura gio "$dsk.desktop" "$q" "omni-shell-prototipo --app $arg")
  if [ -n "$(campo finestra "$r")" ]; then m "app.$nome.riapertura" "$(python3 -c "print('%.2f' % ($(campo finestra "$r")/1000))")" s "utilizzabile dopo $(campo utilizzabile "$r") ms"; else rec FAIL "$nome: nessuna finestra (riapertura: $r)"; fi
  oclose "$arg"
done
rec OK "tempi di apertura misurati (vedi tabella)"

# --- 6. consumo della shell: inattività e passaggio del mouse sul dock/barra ---
procs=(omni-shell-prot kwin_wayland plasmashell)
read_ticks() { cpu_ticks "${procs[@]}" | sort; }
b=$(read_ticks); sleep 20; a=$(read_ticks)
cpu_pct() { python3 - "$1" "$2" "$3" <<'PY'
import sys
b = dict(l.split() for l in sys.argv[1].splitlines() if l.strip())
a = dict(l.split() for l in sys.argv[2].splitlines() if l.strip())
secs = float(sys.argv[3])
print(" ".join(f"{k}={(int(a[k]) - int(b[k])) / secs:.1f}%" for k in sorted(a) if k in b))
PY
}
m cpu.inattivo "$(cpu_pct "$b" "$a" 20)" "% di una CPU" "20 s senza input"
b=$(read_ticks); t1=$(date +%s.%N)
for i in $(seq 0 39); do qmp move "$(( W * 3 / 10 + W * 4 * i / 390 ))" "$(( H - H * 6 / 100 ))" "$W" "$H"; sleep 0.15; done
t2=$(date +%s.%N); a=$(read_ticks)
m cpu.mouse-sul-dock "$(cpu_pct "$b" "$a" "$(sec "$t2" "$t1")")" "% di una CPU" "40 movimenti sul dock/barra"
for p in "${procs[@]}"; do r=$(rss_mb "$p"); [ -n "$r" ] && m "memoria.$p" "$r" MB "RSS"; done

# --- 7. disconnessione e secondo accesso (accesso tipico) ---
vm_ssh "loginctl terminate-session $SID" >> "$LOG" 2>&1; sleep 30
shot 03-dopo-disconnessione
if sess_login; then
  sess_env
  if t=$(ready_after); then m accesso.successivo "$t" s "dall'Invio alla shell pronta"; rec OK "secondo accesso: $t s"; else rec FAIL "shell non pronta dopo il secondo accesso"; fi
else rec FAIL "secondo accesso"; fi
sleep 10; shot 04-secondo-accesso

# --- 8. spegnimento e riavvio (solo la VM di prova) ---
if [ "${SPEGNIMENTO:-1}" = 1 ]; then
  u_sh "setsid -f konsole >/dev/null 2>&1 </dev/null; setsid -f dolphin >/dev/null 2>&1 </dev/null"; sleep 15
  pid=$(cat "$w/qemu.pid"); t1=$(date +%s)
  u_sh "gdbus call --session --dest org.kde.Shutdown --object-path /Shutdown --method org.kde.Shutdown.logoutAndShutdown" >> "$LOG" 2>&1
  off=""
  for _ in $(seq 1 120); do kill -0 "$pid" 2>/dev/null || { off=$(( $(date +%s) - t1 )); break; }; sleep 2; done
  if [ -n "$off" ]; then m spegnimento.org.kde.Shutdown "$off" s "con Konsole e Dolphin aperte"; rec OK "spegnimento completato in $off s"
  else shot 05-spegnimento-bloccato; rec FAIL "spegnimento non completato entro 240 s"; kill "$pid" 2>/dev/null; sleep 3; fi
  # nuovo avvio dello stesso disco dopo lo spegnimento
  rm -f "$w/qmp.sock"
  bash tests/vm/boot_vm.sh "$w/disk.raw" "$w" uefi >/dev/null
  if vm_ready "$w"; then rec OK "riavvio dopo lo spegnimento: sistema pronto"; m avvio.dopo-spegnimento "$(vm_ssh "systemd-analyze" 2>/dev/null | head -1 | tr '\t' ' ')" "" ""; else rec FAIL "il sistema non riparte dopo lo spegnimento"; fi
fi
vm_ssh "userdel -r -f $U" >/dev/null 2>&1 || true
vm_stop "$w"
{ echo; echo "### Misure ($etichetta)"; echo; echo "| Misura | Valore | Unità | Nota |"; echo "|---|---|---|---|"
  tail -n +2 "$M" | awk -F'\t' '{printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4}'; } >> "$RESULTS"
res_end
