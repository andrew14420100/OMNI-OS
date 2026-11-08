#!/usr/bin/env bash
# T1: l'obbligo di firma resta in vigore negli aggiornamenti successivi?
# T2: aggiornamenti automatici (servizio del gestore), errori e politica di firma.
# Chiavi cosign effimere, registro locale solo loopback.
# Prerequisiti: registro attivo; immagini locali localhost/omni-os:v011, v012, v013; $COSIGN.
# Uso: managers_test.sh <bootc|rpm-ostree> <dir-di-lavoro>
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=tests/vm/lib.sh
. tests/vm/lib.sh
c=$1 w=$2; mkdir -p "$w"
LOG=$w/managers-$c.log; : > "$LOG"
res_init "$w/managers-$c.md" "T1 e T2 — firma negli aggiornamenti successivi e aggiornamenti automatici con $c"
V1=0.1.1-m1-dev V2=0.1.2-m1-dev V3=0.1.3-m1-dev
R=$REG_VM/$REPO
K=$w/keys
case "$c" in
  bootc)      SVC=bootc-fetch-apply-updates.service ;;
  rpm-ostree) SVC=rpm-ostreed-automatic.service ;;
esac

keys_new "$K"
vm_fresh "$w" || { rec FAIL "avvio VM"; res_end; exit 1; }
vm_containers_config signed "$K/prova.pub"
# Isolamento del test: nessun timer automatico deve partire da solo durante le prove.
vm_ssh "systemctl list-timers --all --no-pager | grep -E 'rpm-ostreed-automatic|bootc-fetch' || true" >> "$w/managers-$c-timer.txt" 2>&1
echo "INFO stato predefinito dei timer: $(vm_ssh "systemctl is-enabled rpm-ostreed-automatic.timer bootc-fetch-apply-updates.timer 2>&1 | tr '\n' ' '")" | tee -a "$LOG"
vm_ssh "systemctl stop rpm-ostreed-automatic.timer bootc-fetch-apply-updates.timer" >/dev/null 2>&1 || true

# ---------------- T1 ----------------
d=$(reg_push localhost/omni-os:v011 stable) && sign_digest "$K" "$d" && rec OK "T1.0 immagine $V1 firmata pubblicata come :stable"
if mgr_switch "$c" "$R:stable" signed >> "$LOG" 2>&1; then rec OK "T1.1 passaggio a :stable con verifica della firma"; else rec FAIL "T1.1 passaggio con verifica della firma"; fi
{ echo "--- prima del riavvio T1.1"; vm_ssh "ostree admin status; systemctl status ostree-finalize-staged.service --no-pager 2>&1 | head -8"; } >> "$LOG" 2>&1
if vm_reboot "$w"; then rec OK "T1.1 riavvio"; else rec FAIL "T1.1 riavvio"; fi
check_booted "$V1" "T1.1"
mgr_status "$c" > "$w/managers-$c-status-T1.json" 2>&1
vm_ssh "rpm-ostree status" >> "$LOG" 2>&1

# L'etichetta :stable viene sostituita da un'immagine NON firmata.
d2=$(reg_push localhost/omni-os:v012 stable) && rec OK "T1.2 :stable sostituita da $V2 NON firmata ($d2)"
expect_fail "T1.2 aggiornamento successivo verso immagine NON firmata" mgr_upgrade "$c"
if [ -z "$(staged_version)" ]; then rec OK "T1.2 nessun aggiornamento preparato"; else rec FAIL "T1.2 preparato $(staged_version)"; fi
if [ "$c" = bootc ]; then
  if vm_ssh "bootc upgrade --check" >> "$LOG" 2>&1; then echo "INFO T1.2 'bootc upgrade --check' ha risposto senza errore" | tee -a "$LOG"; else echo "INFO T1.2 'bootc upgrade --check' ha restituito errore" | tee -a "$LOG"; fi
fi

# Osservazione (non è un esito atteso): passaggio ESPLICITO alla modalità non verificata.
if mgr_switch "$c" "$R:stable" unsigned >> "$LOG" 2>&1; then
  rec INFO "T1.3 osservazione: un passaggio esplicito in modalità non verificata ACCETTA l'immagine non firmata (richiede root)"
else
  rec INFO "T1.3 osservazione: anche il passaggio esplicito in modalità non verificata viene RIFIUTATO dalla policy"
fi
# eventuale aggiornamento preparato dall'osservazione viene scartato: il deployment avviato resta verificato
vm_ssh "rpm-ostree cleanup -p" >> "$LOG" 2>&1 || true

# La stessa immagine viene firmata: l'aggiornamento ora deve riuscire.
if sign_digest "$K" "$d2"; then rec OK "T1.4 immagine $V2 firmata"; else rec FAIL "T1.4 firma di $V2"; fi
expect_ok "T1.4 aggiornamento successivo verso immagine firmata" mgr_upgrade "$c"
if vm_reboot "$w"; then rec OK "T1.4 riavvio"; else rec FAIL "T1.4 riavvio"; fi
check_booted "$V2" "T1.4"

# ---------------- T2: aggiornamenti automatici ----------------
if [ "$c" = rpm-ostree ]; then
  vm_ssh "sed -i -E 's/^#?AutomaticUpdatePolicy=.*/AutomaticUpdatePolicy=stage/' /etc/rpm-ostreed.conf; grep -q '^AutomaticUpdatePolicy=stage' /etc/rpm-ostreed.conf || printf '[Daemon]\nAutomaticUpdatePolicy=stage\n' >> /etc/rpm-ostreed.conf; rpm-ostree reload" >> "$LOG" 2>&1
  echo "INFO politica automatica: $(vm_ssh "grep AutomaticUpdatePolicy /etc/rpm-ostreed.conf")" | tee -a "$LOG"
fi
echo "INFO servizio: $(vm_ssh "systemctl cat $SVC 2>/dev/null | grep -E '^ExecStart' | tr '\n' ' '")" | tee -a "$LOG"

# auto_run: avvia il servizio automatico e attende la fine (o il riavvio della VM).
# Imposta AUTO_RESULT (Result del servizio o 'riavvio') e AUTO_REBOOT (0/1).
auto_run() {
  AUTO_REBOOT=0; AUTO_RESULT=""
  vm_ssh "systemctl reset-failed $SVC; systemctl start --no-block $SVC" >> "$LOG" 2>&1
  for _ in $(seq 1 60); do
    sleep 5
    if ! out=$(vm_ssh "systemctl show -p ActiveState -p Result -p SubState $SVC" 2>/dev/null); then
      AUTO_REBOOT=1; vm_ready "$w"; AUTO_RESULT=riavvio; return 0
    fi
    st=$(echo "$out" | sed -n 's/^ActiveState=//p')
    case "$st" in inactive|failed) AUTO_RESULT=$(echo "$out" | sed -n 's/^Result=//p'); return 0 ;; esac
  done
  AUTO_RESULT=timeout
}
vm_ssh "journalctl --rotate; journalctl --vacuum-time=1s" >/dev/null 2>&1 || true

# T2.1: nuova immagine NON firmata su :stable.
d3=$(reg_push localhost/omni-os:v013 stable) && rec OK "T2.1 :stable sostituita da $V3 NON firmata ($d3)"
auto_run
echo "INFO T2.1 esito del servizio: $AUTO_RESULT" | tee -a "$LOG"
if [ "$AUTO_REBOOT" = 0 ] && [ -z "$(staged_version)" ] && [ "$(vm_version)" = "$V2" ]; then
  rec OK "T2.1 aggiornamento automatico verso immagine NON firmata rifiutato (servizio: $AUTO_RESULT), sistema invariato su $V2"
else
  rec FAIL "T2.1 immagine non firmata: riavvio=$AUTO_REBOOT preparato='$(staged_version)' versione=$(vm_version)"
fi
vm_ssh "journalctl -u $SVC --no-pager -n 15 -o cat" >> "$LOG" 2>&1

# T2.2: registro non raggiungibile.
registry_stop
auto_run
echo "INFO T2.2 esito del servizio: $AUTO_RESULT" | tee -a "$LOG"
if [ "$AUTO_REBOOT" = 0 ] && [ -z "$(staged_version)" ] && [ "$(vm_version)" = "$V2" ]; then
  rec OK "T2.2 registro irraggiungibile: errore gestito (servizio: $AUTO_RESULT), sistema invariato"
else
  rec FAIL "T2.2 registro irraggiungibile: riavvio=$AUTO_REBOOT preparato='$(staged_version)'"
fi
registry_resume || rec FAIL "T2.2 riavvio del registro"

# T2.3: la stessa immagine firmata: l'aggiornamento automatico deve applicarsi.
if sign_digest "$K" "$d3"; then rec OK "T2.3 immagine $V3 firmata"; else rec FAIL "T2.3 firma"; fi
auto_run
echo "INFO T2.3 esito del servizio: $AUTO_RESULT, riavvio automatico: $AUTO_REBOOT" | tee -a "$LOG"
if [ "$c" = rpm-ostree ]; then
  if [ "$(staged_version)" = "$V3" ]; then rec OK "T2.3 aggiornamento automatico preparato ($V3, politica 'stage')"; else rec FAIL "T2.3 nessun aggiornamento preparato ('$(staged_version)')"; fi
  if vm_reboot "$w"; then rec OK "T2.3 riavvio"; else rec FAIL "T2.3 riavvio"; fi
else
  if [ "$AUTO_REBOOT" = 1 ]; then rec OK "T2.3 aggiornamento automatico applicato con riavvio automatico"; else rec FAIL "T2.3 nessun riavvio automatico (servizio: $AUTO_RESULT)"; fi
fi
check_booted "$V3" "T2.3"
vm_ssh "journalctl -u $SVC --no-pager -n 20 -o cat" >> "$LOG" 2>&1

keys_destroy "$K"
if [ ! -e "$K" ]; then rec OK "chiavi effimere distrutte"; else rec FAIL "distruzione chiavi"; fi
vm_stop "$w"
res_end
