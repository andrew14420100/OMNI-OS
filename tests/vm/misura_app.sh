#!/bin/bash
# Eseguito DENTRO la VM, come utente della sessione grafica (copiato da diagnosi/prestazioni).
# Avvia un'applicazione e misura, con l'orologio della VM:
#   finestra     ms dall'avvio alla prima finestra elencata da KWin (org.kde.krunner1 /WindowsRunner)
#   utilizzabile ms dall'avvio a quando i processi dell'app restano sotto il 10% di una CPU per
#                300 ms consecutivi dopo la comparsa della finestra (caricamento finito)
#   letti_mb     MB letti dal disco dai processi dell'app (/proc/<pid>/io read_bytes)
# Uso: misura_app.sh <modo> <file.desktop|comando> <parola-finestra> <regex-processi>
#   modo: gio (come il lanciatore OMNI 0.3), exec (eseguibile diretto), omni (OMNI Shell via D-Bus)
set -u
modo=$1 cosa=$2 q=$3 re=$4
m() { gdbus call --session --dest org.kde.KWin --object-path /WindowsRunner --method org.kde.krunner1.Match "$q" 2>/dev/null; }
ms() { date +%s%3N; }
pids() { pgrep -u "$(id -u)" -f "$re" 2>/dev/null; }
ticks() { local t=0 p; for p in $(pids); do read -r -a f < "/proc/$p/stat" 2>/dev/null || continue; t=$((t + f[13] + f[14])); done; echo $t; }
readb() { local b=0 p v; for p in $(pids); do v=$(awk '/^read_bytes/ {print $2}' "/proc/$p/io" 2>/dev/null); b=$((b + ${v:-0})); done; echo $b; }
m | grep -q "\[(" && { echo "ERRORE finestra già aperta"; exit 2; }
t0=$(ms)
case $modo in
  gio)  setsid -f gio launch "/usr/share/applications/$cosa" >/dev/null 2>&1 </dev/null ;;
  exec) setsid -f sh -c "$cosa" >/dev/null 2>&1 </dev/null ;;
  omni) gdbus call --session --dest org.omnios.Shell --object-path /Shell --method org.omnios.Shell.Launch "$cosa" >/dev/null 2>&1 ;;
esac
fin=""; end=$((t0 + 120000))
while [ "$(ms)" -lt $end ]; do
  if m | grep -q "\[("; then fin=$(( $(ms) - t0 )); break; fi
  sleep 0.05
done
[ -n "$fin" ] || { echo "ERRORE nessuna finestra entro 120 s"; exit 1; }
# utilizzabile: 3 campioni consecutivi da 100 ms con al più 1 tick (10% di una CPU)
quiet=0; prev=$(ticks); use=""
while [ "$(ms)" -lt $end ]; do
  sleep 0.1; cur=$(ticks)
  if [ $((cur - prev)) -le 1 ]; then quiet=$((quiet + 1)); else quiet=0; fi
  prev=$cur
  if [ $quiet -ge 3 ]; then use=$(( $(ms) - t0 - 300 )); break; fi
done
echo "finestra=$fin utilizzabile=${use:-NA} letti_mb=$(( $(readb) / 1048576 ))"
