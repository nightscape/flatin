#!/usr/bin/env bash
# The stall rule of run_5x_macos.sh may open the app only while this run's own
# app is up. Draws runs that start no app while a latin_practice app from some
# other checkout runs, and asserts the wrapper never opens an app for them.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$repo/target"
work=$(mktemp -d "$repo/target/stall-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
printf '#!/usr/bin/env bash\necho "$*" >>"%s/open-calls"\n' "$work" >"$work/bin/open"
printf '#!/usr/bin/env bash\necho building\nsleep 25\n' >"$work/silent-flutter"
chmod +x "$work/bin/open" "$work/silent-flutter"

foreign_app_paths() {
  local seed=$1 prefixes=(/tmp/checkout-a /tmp/checkout-$((seed * 7 % 500)) /opt/ci/w$seed)
  echo "${prefixes[$((seed % 3))]}/build/macos/Build/Products/Debug/latin_practice.app/Contents/MacOS/latin_practice"
}

for seed in 0 1 2; do
  foreign=$(foreign_app_paths "$seed")
  (exec -a "$foreign" sleep 60) &
  foreign_pid=$!
  rm -f "$work/open-calls"
  (cd "$repo" && PATH="$work/bin:$PATH" FLUTTER="$work/silent-flutter" STALL_AFTER=10 \
    bash integration_test/run_5x_macos.sh 1 >/dev/null)
  kill "$foreign_pid"
  if [ -s "$work/open-calls" ]; then
    echo "FAIL seed $seed: run started no app, foreign app $foreign, wrapper opened: $(head -1 "$work/open-calls")"
    exit 1
  fi
  echo "ok seed $seed"
done
