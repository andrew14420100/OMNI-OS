#!/usr/bin/env bash
# Scarica uno strumento di lint con versione e integrita' fissate.
# 1) file di release GitHub (checksum fissato);
# 2) ripiego: binario estratto da un layer dell'immagine ufficiale del progetto,
#    scaricato per digest dal registry (il digest del layer e' verificato) e
#    controllato con un checksum fissato del binario.
# Nessun ripiego senza checksum: se entrambe le fonti falliscono, lo script fallisce.
set -euo pipefail

dest_dir=${RUNNER_TEMP:-/tmp}/bin
mkdir -p "$dest_dir"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

dl() { curl -sSLf --retry 4 --retry-delay 5 --retry-all-errors "$@"; }

# registry_blob REGISTRY REPO DIGEST OUT
registry_blob() {
  local reg=$1 repo=$2 digest=$3 out=$4 tok
  case $reg in
    ghcr.io) tok=$(dl "https://ghcr.io/token?scope=repository:${repo}:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])') ;;
    registry-1.docker.io) tok=$(dl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])') ;;
    *) echo "registry non ammesso: $reg" >&2; return 1 ;;
  esac
  dl -H "Authorization: Bearer $tok" -o "$out" "https://${reg}/v2/${repo}/blobs/${digest}"
  echo "${digest#sha256:}  $out" | sha256sum -c - >/dev/null
}

case ${1:-} in
  hadolint)
    # v2.12.0
    if dl -o "$tmp/hadolint" https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64; then
      src="GitHub Releases"
    else
      echo "::warning::GitHub Releases non disponibile per hadolint: uso il layer dell'immagine ufficiale ghcr.io/hadolint/hadolint:v2.12.0 (indice sha256:30a8fd2e...)"
      registry_blob ghcr.io hadolint/hadolint \
        sha256:550d38d05a884e3077755a0c12432ea5039b9517195d2e2afd7c91793e4a2d16 "$tmp/layer.tgz"
      tar -xzf "$tmp/layer.tgz" -C "$tmp" bin/hadolint
      mv "$tmp/bin/hadolint" "$tmp/hadolint"
      src="ghcr.io (layer per digest)"
    fi
    # Stesso checksum per entrambe le fonti: il binario dell'immagine e' identico al file di release.
    echo "56de6d5e5ec427e17b74fa48d51271c7fc0d61244bf5c90e828aab8362d55010  $tmp/hadolint" | sha256sum -c -
    install -m 0755 "$tmp/hadolint" "$dest_dir/hadolint"
    ;;
  shellcheck)
    # v0.10.0
    if dl -o "$tmp/sc.tar.xz" https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz; then
      echo "6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87  $tmp/sc.tar.xz" | sha256sum -c -
      tar -xJf "$tmp/sc.tar.xz" -C "$tmp"
      mv "$tmp/shellcheck-v0.10.0/shellcheck" "$tmp/shellcheck"
      src="GitHub Releases"
    else
      echo "::warning::GitHub Releases non disponibile per shellcheck: uso il layer dell'immagine ufficiale docker.io/koalaman/shellcheck:v0.10.0 (indice sha256:2097951f...)"
      registry_blob registry-1.docker.io koalaman/shellcheck \
        sha256:d48cce4175428e21f94f062cc7a9ef6572fa5ec206219ff4231f8271110e06d6 "$tmp/layer.tgz"
      tar -xzf "$tmp/layer.tgz" -C "$tmp" bin/shellcheck
      mv "$tmp/bin/shellcheck" "$tmp/shellcheck"
      echo "f35ae15a4677945428bdfe61ccc297490d89dd1e544cc06317102637638c6deb  $tmp/shellcheck" | sha256sum -c -
      src="docker.io (layer per digest)"
    fi
    install -m 0755 "$tmp/shellcheck" "$dest_dir/shellcheck"
    "$dest_dir/shellcheck" --version | grep -qx 'version: 0.10.0'
    ;;
  *) echo "uso: $0 hadolint|shellcheck" >&2; exit 2 ;;
esac
echo "$1: installato da $src in $dest_dir"
