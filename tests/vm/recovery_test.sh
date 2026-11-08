#!/usr/bin/env bash
# AC-M1-05: R2 (deployment fissato: protezione e ripristino) e R3 (ritorno a
# un'immagine precedente conservata nel registro temporaneo), per un gestore.
# Prerequisiti (preparati dal workflow): registro locale attivo con i tag
# v0.1.0, v0.1.1, v0.1.2; file $VMWORK/d-0.1.1 con il digest di v0.1.1.
# Uso: recovery_test.sh <bootc|rpm-ostree> <dir-di-lavoro>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
c=$1 w=$2; mkdir -p "$w"
LOG=$w/recovery-$c.log; : > "$LOG"
res_init "$w/recovery-$c.md" "AC-M1-05 — R2 e R3 con $c"
V0=0.1.0-m1-dev V1=0.1.1-m1-dev V2=0.1.2-m1-dev
R=$REG_VM/$REPO

status_json() { vm_ssh "rpm-ostree status --json" 2>/dev/null; }
# idx_of <versione>: indice (come in 'ostree admin status') del primo deployment con quella versione
idx_of() { status_json | jq -r --arg v "$1" '[.deployments | to_entries[] | select(.value.version == $v) | .key][0] // empty'; }
versions() { status_json | jq -r '[.deployments[] | "\(.version)\(if .booted then "*" else "" end)\(if .pinned then "(fissato)" else "" end)"] | join(", ")'; }
count_deps() { status_json | jq '.deployments | length'; }
go() { # go <riferimento> <descrizione>: aggiorna con il gestore e riavvia
  if mgr_switch "$c" "$1" unsigned >> "$LOG" 2>&1; then rec OK "$2: preparato"; else rec FAIL "$2: preparazione"; return 1; fi
  if vm_reboot "$w"; then rec OK "$2: riavvio (${REBOOT_S} s)"; else rec FAIL "$2: riavvio"; return 1; fi
}

vm_fresh "$w" || { rec FAIL "avvio VM"; res_end; exit 1; }
vm_containers_config unsigned
check_booted "$V0" "avvio iniziale"

# ---------------- R2: deployment fissato ----------------
go "$R:v0.1.1" "R2.1 aggiornamento a $V1"; check_booted "$V1" "R2.1"
i=$(idx_of "$V0")
if [ -n "$i" ] && vm_ssh "ostree admin pin $i" >> "$LOG" 2>&1; then rec OK "R2.2 deployment $V0 fissato (ostree admin pin $i)"; else rec FAIL "R2.2 pin del deployment $V0"; fi
if [ "$(status_json | jq -r --arg v "$V0" '[.deployments[] | select(.version==$v)][0].pinned')" = true ]; then rec OK "R2.2 stato 'fissato' confermato"; else rec FAIL "R2.2 stato 'fissato' non confermato"; fi
echo "INFO deployment: $(versions)" | tee -a "$LOG"

go "$R:v0.1.2" "R2.3 aggiornamento a $V2"; check_booted "$V2" "R2.3"
echo "INFO deployment: $(versions)" | tee -a "$LOG"
if [ -n "$(idx_of "$V0")" ]; then rec OK "R2.3 protezione: $V0 fissato ancora presente dopo due aggiornamenti"; else rec FAIL "R2.3 $V0 fissato eliminato"; fi

# Prova di controllo: un deployment NON fissato più vecchio viene eliminato.
go "$R:v0.1.1" "R2.4 controllo: nuovo aggiornamento a $V1"; check_booted "$V1" "R2.4"
echo "INFO deployment: $(versions)" | tee -a "$LOG"
n=$(status_json | jq --arg v "$V1" '[.deployments[] | select(.version==$v)] | length')
if [ "$n" = 1 ] && [ -n "$(idx_of "$V0")" ] && [ "$(count_deps)" = 3 ]; then
  rec OK "R2.4 controllo: il vecchio $V1 non fissato è stato eliminato, $V0 fissato è rimasto (3 deployment)"
else
  rec FAIL "R2.4 controllo inatteso: $(versions)"
fi

# Ripristino del deployment fissato come predefinito.
i=$(idx_of "$V0")
if [ -n "$i" ] && vm_ssh "ostree admin set-default $i" >> "$LOG" 2>&1; then rec OK "R2.5 deployment fissato $V0 impostato come predefinito (ostree admin set-default $i)"; else rec FAIL "R2.5 set-default"; fi
if vm_reboot "$w"; then rec OK "R2.5 riavvio (${REBOOT_S} s)"; else rec FAIL "R2.5 riavvio"; fi
check_booted "$V0" "R2.5 ripristino del deployment fissato"
i=$(idx_of "$V0")
if vm_ssh "ostree admin pin --unpin $i" >> "$LOG" 2>&1; then rec OK "R2.6 deployment sbloccato (pulizia)"; else rec FAIL "R2.6 unpin"; fi
echo "INFO deployment: $(versions)" | tee -a "$LOG"

# ---------------- R3: ritorno a immagini precedenti nel registro ----------------
go "$R:v0.1.2" "R3.1 aggiornamento a $V2 dal registro"; check_booted "$V2" "R3.1"
d1=$(cat "$VMWORK/d-0.1.1")
go "$R@$d1" "R3.2 ritorno a $V1 per digest ($d1)"; check_booted "$V1" "R3.2 ritorno per digest"
go "$R:v0.1.0" "R3.3 ritorno a $V0 per tag"; check_booted "$V0" "R3.3 ritorno per tag"
echo "INFO deployment finali: $(versions)" | tee -a "$LOG"
mgr_status "$c" > "$w/recovery-$c-status.json" 2>&1 || true

vm_stop "$w"
res_end
