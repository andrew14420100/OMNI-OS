#!/usr/bin/env bash
# Diagnosi delle CAUSE dei tempi di apertura delle applicazioni (VM di test, 4K scala 200%,
# grafica software). Per ogni app separa: primo avvio dopo l'accesso, riapertura, avvio a
# freddo (cache svuotate), a freddo con lettura anticipata dei file, avvio diretto senza gio,
# e (Impostazioni) rendering Qt Quick software; misura finestra, utilizzabilità e MB letti.
# Uso: diagnosi_avvio.sh <dir-di-lavoro> <etichetta>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
# shellcheck source=tests/vm/sessione_lib.sh
. tests/vm/sessione_lib.sh
w=$1 etichetta=$2; mkdir -p "$w/schermate"
LOG=$w/diagnosi.log; : > "$LOG"; : > "$w/diagnosi-sistema.txt"
D=$w/diagnosi.tsv; printf 'app\tvariante\tfinestra_ms\tutilizzabile_ms\tletti_mb\tnota\n' > "$D"
res_init "$w/diagnosi.md" "Diagnosi dell'apertura delle applicazioni: $etichetta"
export VM_TABLET=1 VM_RES=${VM_RES:-3840x2160} VM_MEM=${VM_MEM:-8192} VM_CPUS=${VM_CPUS:-4}
W=${VM_RES%x*} H=${VM_RES#*x}
vm_fresh "$w" || { rec FAIL "avvio della VM"; res_end; exit 1; }
rec OK "VM avviata ($(vm_version))"
sess_user_create omnidiag || { rec FAIL "utente"; vm_stop "$w"; res_end; exit 1; }
GREETER_WAIT=45 sess_greeter
sess_login || { rec FAIL "accesso"; vm_stop "$w"; res_end; exit 1; }
sess_env; sleep 25
out=$(u_sh "kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print \$3; exit}'")
u_sh "kscreen-doctor output.$out.mode.${W}x${H}@60 output.$out.scale.2" >> "$LOG" 2>&1; sleep 8
vm_scp tests/vm/misura_app.sh tests/vm/prefetch_app.sh root@127.0.0.1:/tmp/ >> "$LOG" 2>&1 || vm_ssh "true"
vm_ssh "chmod 755 /tmp/misura_app.sh /tmp/prefetch_app.sh" >> "$LOG" 2>&1
misura() { u_sh "bash /tmp/misura_app.sh $(printf '%q ' "$@")" 2>>"$LOG" | tail -1; }
rec_tsv() { # app variante risultato nota
  local f u r
  f=$(sed -n 's/.*finestra=\([0-9]*\).*/\1/p' <<< "$3"); u=$(sed -n 's/.*utilizzabile=\([0-9NA]*\).*/\1/p' <<< "$3"); r=$(sed -n 's/.*letti_mb=\([0-9]*\).*/\1/p' <<< "$3")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "${f:-ERR}" "${u:-ERR}" "${r:-ERR}" "${4:-}" >> "$D"
  echo "MISURA $1 $2: $3 ${4:-}" | tee -a "$LOG"
}
chiudi() { local r; r=$(printf '%q' "$1"); vm_ssh "pkill -u $U -f $r" >/dev/null 2>&1; for _ in $(seq 1 20); do vm_ssh "pgrep -u $U -f $r" >/dev/null 2>&1 || break; sleep 1; done; vm_ssh "pkill -9 -u $U -f $r" >/dev/null 2>&1; sleep 3; }
svuota() { vm_ssh "sync; echo 3 > /proc/sys/vm/drop_caches" >/dev/null 2>&1; sleep 2; }

# nome;regex file .desktop;parola finestra;regex processi;eseguibile;cartelle dati
for spec in "Konsole;org.kde.konsole;konsole;(^|/)konsole( |\$);/usr/bin/konsole;" \
            "Dolphin;org.kde.dolphin;dolphin;(^|/)dolphin( |\$);/usr/bin/dolphin;" \
            "Firefox;org.mozilla.firefox|firefox;firefox;firefox;/usr/lib64/firefox/firefox;/usr/lib64/firefox" \
            "Impostazioni;systemsettings|org.kde.systemsettings;settings;(^|/)systemsettings( |\$);/usr/bin/systemsettings;/usr/share/kpackage/kcms"; do
  IFS=';' read -r nome dsk q re bin dati <<< "$spec"
  f=$(app_desktop "$dsk"); [ -n "$f" ] || { rec FAIL "$nome: file .desktop non trovato"; continue; }
  rec_tsv "$nome" primo-dopo-accesso "$(misura gio "$f" "$q" "$re")" "prima apertura nella sessione, senza svuotare le cache"; chiudi "$re"
  rec_tsv "$nome" riapertura "$(misura gio "$f" "$q" "$re")"; chiudi "$re"
  rec_tsv "$nome" riapertura-diretta "$(misura exec "$bin" "$q" "$re")" "eseguibile avviato direttamente, senza gio"; chiudi "$re"
  rec_tsv "$nome" riapertura-da-OMNI "$(misura omni "$f" "$q" "$re")" "avvio dalla shell OMNI (come un clic in Start o nella barra)"
  e=$(vm_ssh "for p in \$(pgrep -u $U -f '$re'); do tr '\\0' '\\n' < /proc/\$p/environ 2>/dev/null | grep -m1 '^QT_QUICK_BACKEND='; done | sort -u" 2>/dev/null)
  echo "INFO $nome avviata da OMNI: ${e:-QT_QUICK_BACKEND non impostato}" | tee -a "$LOG" >> "$w/diagnosi-sistema.txt"
  chiudi "$re"
  svuota; rec_tsv "$nome" freddo "$(misura gio "$f" "$q" "$re")" "cache del disco svuotate"; chiudi "$re"
  svuota; p=$(u_sh "bash /tmp/prefetch_app.sh $bin $dati" | tail -1)
  rec_tsv "$nome" freddo+lettura-anticipata "$(misura gio "$f" "$q" "$re")" "$p"; chiudi "$re"
  if [ "$nome" = Impostazioni ]; then
    rec_tsv "$nome" riapertura-qtquick-software "$(misura exec "QT_QUICK_BACKEND=software $bin" "$q" "$re")" "Qt Quick con renderer software invece di OpenGL llvmpipe"; chiudi "$re"
  fi
done
rec OK "misure completate"

{ echo "=== processi di Plasma non necessari nella sessione OMNI"
  vm_ssh "ps -u $U -o pid,ppid,rss,comm,args --sort=-rss | grep -E 'plasma-welcome|plasma-keyboard|xwaylandvideo|DiscoverNotif' | grep -v grep"
  echo "=== origine della tastiera su schermo"
  vm_ssh "p=\$(pgrep -u $U -x plasma-keyboard | head -1); [ -n \"\$p\" ] && ps -o pid,ppid,comm -p \$(awk '{print \$4}' /proc/\$p/stat) 2>/dev/null"
  u_sh "kreadconfig6 --file kwinrc --group Wayland --key InputMethod; cat /etc/xdg/kwinrc 2>/dev/null | head -20"
  echo "=== Centro di benvenuto: unità"; u_sh "systemctl --user list-units --all --no-legend 'app-org.kde.plasma-welcome*' 2>&1 | head"
  echo "=== moduli kded caricati"; u_sh "gdbus call --session --dest org.kde.kded6 --object-path /kded --method org.kde.kded6.loadedModules 2>&1 | head -5"
  echo "=== criteri di Firefox"; vm_ssh "ls -la /etc/firefox/policies/ 2>&1"
  echo "=== systemd-analyze --user blame (sessione)"; u_sh "systemd-analyze --user blame --no-pager | head -30"
  echo "=== critical-chain plasma-workspace.target"; u_sh "systemd-analyze --user critical-chain plasma-workspace.target --no-pager"
  echo "=== servizi utente in esecuzione"; u_sh "systemctl --user list-units --type=service --state=running --no-legend --no-pager"
  echo "=== processi dell'utente per memoria"; vm_ssh "ps -u $U -o rss,pcpu,comm --sort=-rss | head -30"
  echo "=== servizi di sistema: blame"; vm_ssh "systemd-analyze blame --no-pager | head -30"
  echo "=== errori dell'avvio"; vm_ssh "journalctl -b -p err --no-pager -o short-monotonic | tail -40"
  echo "=== renderer"; vm_ssh "journalctl -b _UID=$UID_ -o cat --no-pager | grep -m3 -iE 'renderer|OpenGL'"
  echo "=== file desktop DBusActivatable"; vm_ssh "grep -l DBusActivatable=true /usr/share/applications/*.desktop | head -20"
} >> "$w/diagnosi-sistema.txt" 2>&1
{ echo; echo "### Tempi ($etichetta)"; echo; echo "| App | Variante | Finestra (ms) | Utilizzabile (ms) | Letti (MB) | Nota |"; echo "|---|---|---|---|---|---|"
  tail -n +2 "$D" | awk -F'\t' '{printf "| %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6}'; } >> "$RESULTS"
vm_ssh "userdel -r -f $U" >/dev/null 2>&1 || true
vm_stop "$w"
res_end
