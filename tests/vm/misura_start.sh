#!/bin/bash
# Eseguito DENTRO la VM, come utente della sessione OMNI. Reattività del menu Start:
# ms fra la richiesta (la stessa del tasto Meta: org.kde.plasmashell activateLauncherMenu) e
# il momento in cui la shell riporta il contenuto di Start come visibile (DumpGeometry), e
# lo stesso per la chiusura. Ripetuto N volte; stampa mediana e massimo.
# Uso: misura_start.sh [ripetizioni]
set -u
n=${1:-7}
f=/tmp/omni-start-$$.json
ms() { date +%s%3N; }
aperto() { gdbus call --session --dest org.omnios.Shell --object-path /Shell --method org.omnios.Shell.DumpGeometry "$f" >/dev/null 2>&1 && grep -q '"start:search"' "$f"; }
richiesta() { gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell --method org.kde.PlasmaShell.activateLauncherMenu >/dev/null 2>&1; }
aperture=() chiusure=()
aperto && richiesta && sleep 1
for _ in $(seq 1 "$n"); do
  t0=$(ms); richiesta; ok=""
  for _ in $(seq 1 100); do aperto && { ok=1; break; }; sleep 0.01; done
  [ -n "$ok" ] || { echo "ERRORE Start non aperto"; exit 1; }
  aperture+=($(( $(ms) - t0 ))); sleep 0.8
  t0=$(ms); richiesta; ok=""
  for _ in $(seq 1 100); do aperto || { ok=1; break; }; sleep 0.01; done
  [ -n "$ok" ] || { echo "ERRORE Start non chiuso"; exit 1; }
  chiusure+=($(( $(ms) - t0 ))); sleep 0.8
done
rm -f "$f"
stat() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END {printf "%d %d", a[int((NR+1)/2)], a[NR]}'; }
read -r am aM <<< "$(stat "${aperture[@]}")"; read -r cm cM <<< "$(stat "${chiusure[@]}")"
echo "apertura_mediana=$am apertura_max=$aM chiusura_mediana=$cm chiusura_max=$cM n=$n"
