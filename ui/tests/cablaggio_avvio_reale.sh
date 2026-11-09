#!/usr/bin/env bash
# Prova del programma completo (Main.qml + C++), non dei soli componenti: con --real-launch
# l'interfaccia deve ricevere davvero l'AppLauncher (regressione: il binding in Main.qml
# risolveva la proprietà omonima di Shell, restando in modalità simulata).
# Uso: cablaggio_avvio_reale.sh <eseguibile> <cartella-qml>
set -euo pipefail
bin=$1 qml=$2
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/apps"
printf '[Desktop Entry]\nType=Application\nName=Prova\nExec=true\nIcon=utilities-terminal\n' > "$t/apps/prova.desktop"
run() { OMNI_QML_DIR=$qml QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 timeout 60 "$bin" --apps-dir "$t/apps" --dump-geometry "$t/g.json" --delay 300 "$@" 2>&1; }
out=$(run --real-launch); echo "$out" | grep -E "avvio delle applicazioni" || true
echo "$out" | grep -q "interfaccia: avvio delle applicazioni REALE" || { echo "FAIL: con --real-launch l'interfaccia non è in modalità reale"; exit 1; }
out=$(run); echo "$out" | grep -q "interfaccia: avvio delle applicazioni simulato" || { echo "FAIL: senza --real-launch l'interfaccia deve restare simulata"; exit 1; }
out=$(run --real-launch --demo-apps); echo "$out" | grep -q "interfaccia: avvio delle applicazioni simulato" || { echo "FAIL: con --demo-apps l'avvio reale deve restare disattivato"; exit 1; }
echo "OK: cablaggio dell'avvio reale verificato (reale / simulato / demo)"
