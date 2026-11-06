#!/usr/bin/env bash
# T3: tempi di aggiornamento, riavvio e rollback di un gestore, con ripetizioni.
# Prerequisiti: registro locale con i tag v0.1.1 e v0.1.2 (immagini non firmate:
# qui si misurano i tempi, la firma è provata da P9/T1/T2).
# Uso: timing_test.sh <bootc|rpm-ostree> <dir-di-lavoro> <ripetizioni>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
c=$1 w=$2 reps=${3:-3}; mkdir -p "$w"
LOG=$w/timing-$c.log; : > "$LOG"
csv=$w/timing-$c.csv; echo "gestore,ripetizione,fase,secondi,versione_attesa,versione_ottenuta" > "$csv"
res_init "$w/timing-$c.md" "T3 — tempi con $c ($reps ripetizioni)"
V0=0.1.0-m1-dev
R=$REG_VM/$REPO

{
  echo "- CPU del runner: $(lscpu | sed -n 's/^Model name:[[:space:]]*//p')"
  echo "- CPU/RAM della VM: ${VM_CPUS:-2} vCPU, ${VM_MEM:-6144} MiB, KVM"
  echo "- Trasporto: registro locale su loopback (immagini non firmate)"
} > "$w/timing-$c-condizioni.md"

vm_fresh "$w" || { rec FAIL "avvio VM"; res_end; exit 1; }
vm_containers_config unsigned
check_booted "$V0" "avvio iniziale"
case "$c" in bootc) rb="bootc rollback" ;; rpm-ostree) rb="rpm-ostree rollback" ;; esac

timed() { local t0 t1; t0=$(date +%s.%N); "$@" >> "$LOG" 2>&1; local rc=$?; t1=$(date +%s.%N); ELAPSED=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}'); return $rc; }
prev=$V0
for i in $(seq 1 "$reps"); do
  if [ $((i % 2)) = 1 ]; then tag=v0.1.1; v=0.1.1-m1-dev; else tag=v0.1.2; v=0.1.2-m1-dev; fi
  if timed mgr_switch "$c" "$R:$tag" unsigned; then
    echo "$c,$i,preparazione,$ELAPSED,$v," >> "$csv"
  else rec FAIL "rip. $i: preparazione verso $v"; continue; fi
  vm_reboot "$w" || { rec FAIL "rip. $i: riavvio"; continue; }
  got=$(vm_version); echo "$c,$i,riavvio_dopo_aggiornamento,$REBOOT_S,$v,$got" >> "$csv"
  if [ "$got" = "$v" ]; then rec OK "rip. $i: aggiornamento a $v (preparazione ${ELAPSED%.*} s, riavvio $REBOOT_S s)"; else rec FAIL "rip. $i: versione $got invece di $v"; fi
  if timed vm_ssh "$rb"; then echo "$c,$i,rollback,$ELAPSED,$prev," >> "$csv"; else rec FAIL "rip. $i: rollback"; continue; fi
  vm_reboot "$w" || { rec FAIL "rip. $i: riavvio dopo rollback"; continue; }
  got=$(vm_version); echo "$c,$i,riavvio_dopo_rollback,$REBOOT_S,$prev,$got" >> "$csv"
  if [ "$got" = "$prev" ]; then rec OK "rip. $i: rollback a $prev (comando ${ELAPSED%.*} s, riavvio $REBOOT_S s)"; else rec FAIL "rip. $i: dopo rollback $got invece di $prev"; fi
done

python3 -I - "$csv" >> "$w/timing-$c.md" <<'PY'
import csv, statistics, sys
rows = list(csv.DictReader(open(sys.argv[1])))
phases = ["preparazione", "riavvio_dopo_aggiornamento", "rollback", "riavvio_dopo_rollback"]
print("\n| Fase | n | media (s) | min | max | dev. std |\n|---|---|---|---|---|---|")
for p in phases:
    v = [float(r["secondi"]) for r in rows if r["fase"] == p]
    if v:
        sd = statistics.stdev(v) if len(v) > 1 else 0.0
        print(f"| {p} | {len(v)} | {statistics.mean(v):.1f} | {min(v):.1f} | {max(v):.1f} | {sd:.1f} |")
PY
vm_stop "$w"
res_end
