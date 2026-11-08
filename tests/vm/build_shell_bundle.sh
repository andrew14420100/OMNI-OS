#!/usr/bin/env bash
# Compila OMNI Shell V2 per Fedora 45 in un container temporaneo creato dall'immagine OMNI
# di prova (stessa versione di Qt del sistema nella VM) ed esegue i test.
# Produce <uscita>/omni-shell-f45.tar.gz (bin/, qml/, fonts/, qt-build.txt, test.txt).
# Il container è usa e getta: l'immagine OMNI e il disco della VM NON vengono modificati.
# Uso: build_shell_bundle.sh <immagine-omni> <uscita>
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
img=$1 out=$2; mkdir -p "$out"
sudo podman run --rm --security-opt label=disable -v "$PWD/ui":/src:ro -v "$out":/out "$img" bash -euo pipefail -c '
  qb=$(rpm -q --qf "%{VERSION}-%{RELEASE}" qt6-qtbase); qd=$(rpm -q --qf "%{VERSION}-%{RELEASE}" qt6-qtdeclarative)
  echo "Qt nell immagine OMNI: qt6-qtbase-$qb qt6-qtdeclarative-$qd"
  # pacchetti di sviluppo della STESSA versione di Qt presente nell immagine, se ancora nei repository
  if dnf -y -q install --setopt=install_weak_deps=False cmake gcc-c++ rsms-inter-fonts \
       "qt6-qtbase-devel-$qb" "qt6-qtdeclarative-devel-$qd" >/tmp/dnf.log 2>&1; then
    echo "pacchetti di sviluppo: stessa versione dell immagine" > /out/qt-build-match.txt
  else
    tail -5 /tmp/dnf.log
    echo "AVVISO: versione esatta non disponibile, uso la piu recente di Fedora 45"
    dnf -y -q install --setopt=install_weak_deps=False cmake gcc-c++ rsms-inter-fonts qt6-qtbase-devel qt6-qtdeclarative-devel >/dev/null
    echo "pacchetti di sviluppo: versione piu recente (diversa dall immagine)" > /out/qt-build-match.txt
  fi
  rpm -q qt6-qtbase qt6-qtbase-devel qt6-qtdeclarative qt6-qtdeclarative-devel gcc-c++ cmake > /out/qt-build.txt
  cmake -S /src -B /tmp/b -DCMAKE_BUILD_TYPE=Release >/dev/null
  cmake --build /tmp/b -j"$(nproc)" 2>&1 | grep -E "error|warning: " || true
  QT_QPA_PLATFORM=offscreen ctest --test-dir /tmp/b --output-on-failure > /out/test.txt 2>&1 || { cat /out/test.txt; exit 1; }
  tail -3 /out/test.txt
  mkdir -p /out/pkg/bin /out/pkg/fonts
  install -m 0755 /tmp/b/omni-shell-prototipo /out/pkg/bin/
  cp -r /src/qml /out/pkg/qml
  cp /usr/share/fonts/rsms-inter*/*.otf /out/pkg/fonts/ 2>/dev/null || cp -r /usr/share/fonts/rsms-inter* /out/pkg/fonts/ || true
  cp /out/qt-build.txt /out/qt-build-match.txt /out/test.txt /out/pkg/
'
sudo chown -R "$(id -u):$(id -g)" "$out"
tar -C "$out/pkg" -czf "$out/omni-shell-f45.tar.gz" .
ls -l "$out/omni-shell-f45.tar.gz"; cat "$out/qt-build.txt" "$out/qt-build-match.txt"
