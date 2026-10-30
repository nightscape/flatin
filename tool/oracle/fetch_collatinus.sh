#!/usr/bin/env bash
# Downloads the Collatinus inflection data that test/oracle compares our forms
# against, into .dart_tool/oracle/collatinus/ (git-ignored).
#
# The data is third-party and GPL-2-or-later: it is never committed, never
# bundled into the app, and only ever read by the oracle test. The commit is
# pinned and every file is checked against its SHA-256, so the oracle compares
# against one fixed version of Collatinus.
#
# Files are copied from the cache dir ${COLLATINUS_CACHE:-~/.cache/latin-oracle/collatinus}
# when present there, and downloaded (then cached) otherwise. A file with the
# wrong SHA-256 is deleted and downloaded anew.
#
# Run the oracle with the one command: tool/oracle/run.sh
set -euo pipefail

commit=e1fef78818b5c5f8e7f9754cf58f50062b30abff
target="$(cd "$(dirname "$0")/../.." && pwd)/.dart_tool/oracle/collatinus"
cache="${COLLATINUS_CACHE:-$HOME/.cache/latin-oracle/collatinus}"

files=(
  "modeles.la 6f462eed98fe6e16389c52222700ae4de354de759d04b4987ef0cabae39a1697"
  "lemmes.la  0b926602f943f80d3ab04819532f5400e1a37c896c523177f7ca589fa52fe135"
  "morphos.en 62604c3b486f3dd5e1514863f6bf6c1a076923e129673bf2f4708fe7adf3514c"
  "irregs.la  957e1ba45af28c50cc4f3d4d5f49c5ab7e6dc8bcd4a505f9309af6145a7f7791"
)

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | cut -d' ' -f1; }
else
  sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

mkdir -p "$target"
for entry in "${files[@]}"; do
  read -r name want <<<"$entry"
  out="$target/$name"
  if [ ! -f "$out" ] && [ -f "$cache/$name" ]; then
    cp "$cache/$name" "$out"
  fi
  if [ -f "$out" ] && [ "$(sha256 "$out")" != "$want" ]; then
    rm -f "$out"
  fi
  if [ ! -f "$out" ]; then
    curl -fsSL -o "$out" \
      "https://raw.githubusercontent.com/biblissima/collatinus/$commit/bin/data/$name" ||
      { rm -f "$out"; echo "$name: download failed" >&2; exit 1; }
    got="$(sha256 "$out")"
    if [ "$got" != "$want" ]; then
      rm -f "$out"
      echo "$name: SHA-256 $got, expected $want for commit $commit" >&2
      exit 1
    fi
    mkdir -p "$cache"
    cp "$out" "$cache/$name"
  fi
done

echo "Collatinus $commit in $target"
