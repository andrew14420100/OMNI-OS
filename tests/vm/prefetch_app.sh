#!/bin/bash
# Eseguito DENTRO la VM: legge in anticipo (cache del disco) i file di un'applicazione:
# eseguibile, librerie condivise (ldd) e cartelle di dati indicate. Stampa MB e ms.
# Uso: prefetch_app.sh <eseguibile> [cartella...]
set -u
t0=$(date +%s%3N)
bin=$(command -v "$1" 2>/dev/null || echo "$1"); shift
{
  echo "$bin"
  ldd "$bin" 2>/dev/null | awk '/=> \// {print $3} /^\s*\// {print $1}'
  for d in "$@"; do [ -d "$d" ] && find "$d" -type f; done
} | sort -u > /tmp/prefetch-$$.txt
bytes=0
while read -r f; do
  [ -f "$f" ] || continue
  s=$(stat -c %s "$f" 2>/dev/null || echo 0); bytes=$((bytes + s))
  cat "$f" > /dev/null 2>&1
done < /tmp/prefetch-$$.txt
rm -f /tmp/prefetch-$$.txt
echo "prefetch_mb=$((bytes / 1048576)) prefetch_ms=$(( $(date +%s%3N) - t0 ))"
