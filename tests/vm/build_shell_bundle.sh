#!/usr/bin/env bash
# Compila OMNI Shell V2 per Fedora 45 in un container temporaneo (quay.io/fedora/fedora:45)
# con la stessa versione di Qt dell'immagine OMNI di prova, ed esegue i test.
# Produce <uscita>/omni-shell-f45.tar.gz (bin/, qml/, fonts/, qt-build.txt, test.txt).
# Il container è usa e getta: l'immagine OMNI e il disco della VM NON vengono modificati.
# Uso: build_shell_bundle.sh <immagine-omni> <uscita>
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
img=$1 out=$2; mkdir -p "$out"
# Versione di Qt nell'immagine OMNI (sola lettura): l'immagine Kinoite non contiene dnf,
# quindi la compilazione avviene in quay.io/fedora/fedora:45 con la STESSA versione di Qt.
qb=$(sudo podman run --rm "$img" rpm -q --qf '%{VERSION}-%{RELEASE}' qt6-qtbase)
qd=$(sudo podman run --rm "$img" rpm -q --qf '%{VERSION}-%{RELEASE}' qt6-qtdeclarative)
qg=$(sudo podman run --rm "$img" rpm -q --qf '%{VERSION}-%{RELEASE}' kf6-kglobalaccel)
echo "Qt nell'immagine OMNI: qt6-qtbase-$qb qt6-qtdeclarative-$qd" | tee "$out/qt-image.txt"
sudo podman run --rm --security-opt label=disable -e qb="$qb" -e qd="$qd" -e qg="$qg" -v "$PWD/ui":/src:ro -v "$out":/out quay.io/fedora/fedora:45 bash -euo pipefail -c '
  echo "Qt richiesto: qt6-qtbase-$qb qt6-qtdeclarative-$qd"
  # pacchetti di sviluppo della STESSA versione di Qt presente nell immagine, se ancora nei repository
  if dnf -y -q install --setopt=install_weak_deps=False cmake gcc-c++ rsms-inter-fonts dbus-daemon dbus-tools glib2 \
       "qt6-qtbase-$qb" "qt6-qtdeclarative-$qd" "qt6-qtbase-devel-$qb" "qt6-qtdeclarative-devel-$qd" "kf6-kglobalaccel-devel-$qg" >/tmp/dnf.log 2>&1; then
    echo "pacchetti di sviluppo: stessa versione dell immagine" > /out/qt-build-match.txt
  else
    tail -5 /tmp/dnf.log
    echo "AVVISO: versione esatta non disponibile, uso la piu recente di Fedora 45"
    dnf -y -q install --setopt=install_weak_deps=False cmake gcc-c++ rsms-inter-fonts dbus-daemon dbus-tools glib2 qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kglobalaccel-devel >/dev/null
    echo "pacchetti di sviluppo: versione piu recente (diversa dall immagine)" > /out/qt-build-match.txt
  fi
  rpm -q qt6-qtbase qt6-qtbase-devel qt6-qtdeclarative qt6-qtdeclarative-devel kf6-kglobalaccel-devel gcc-c++ cmake > /out/qt-build.txt
  cmake -S /src -B /tmp/b -DCMAKE_BUILD_TYPE=Release >/dev/null
  cmake --build /tmp/b -j"$(nproc)" 2>&1 | grep -E "error|warning: |KGlobalAccel" || true
  grep -q OMNI_HAVE_KGLOBALACCEL /tmp/b/CMakeFiles/omni-shell-prototipo.dir/flags.make || { echo "KGlobalAccel non trovato: tasto Meta non collegato"; exit 1; }
  QT_QPA_PLATFORM=offscreen ctest --test-dir /tmp/b --output-on-failure > /out/test.txt 2>&1 || { cat /out/test.txt; exit 1; }
  tail -3 /out/test.txt
  mkdir -p /out/pkg/bin /out/pkg/fonts
  install -m 0755 /tmp/b/omni-shell-prototipo /out/pkg/bin/
  cp -r /src/qml /out/pkg/qml
  cp /usr/share/fonts/rsms-inter*/*.otf /out/pkg/fonts/ 2>/dev/null || cp -r /usr/share/fonts/rsms-inter* /out/pkg/fonts/ || true
  cp /out/qt-build.txt /out/qt-build-match.txt /out/test.txt /out/qt-image.txt /out/pkg/
'
sudo chown -R "$(id -u):$(id -g)" "$out"
tar -C "$out/pkg" -czf "$out/omni-shell-f45.tar.gz" .
ls -l "$out/omni-shell-f45.tar.gz"; cat "$out/qt-image.txt" "$out/qt-build.txt" "$out/qt-build-match.txt"
