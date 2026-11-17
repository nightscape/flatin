#!/usr/bin/env bash
# Runs the macOS BDD suite RUNS times (default 5); every run must pass, since a
# step that fails once in several runs is flaky. Run from the repository root.
# The suite does not cover the app's accessibility behaviour.
# FLUTTER overrides the flutter binary; RUN_TIMEOUT (seconds, default 900) kills a hung run.
set -u

runs=${1:-5}
flutter_bin=${FLUTTER:-flutter}
run_timeout=${RUN_TIMEOUT:-900}
stall_after=${STALL_AFTER:-45}
app=$PWD/build/macos/Build/Products/Debug/latin_practice.app
mkdir -p target
failed=0

kill_tree() {
  local child
  for child in $(pgrep -P "$1"); do kill_tree "$child" "$2"; done
  kill -"$2" "$1" 2>/dev/null
}

for i in $(seq 1 "$runs"); do
  log="target/bdd-macos-$i.log"
  "$flutter_bin" test integration_test/ -d macos >"$log" 2>&1 &
  pid=$!
  started=$SECONDS
  # macOS stops frames of an unfocused window, so a run that prints nothing for
  # stall_after seconds gets its app brought to the front; App Nap off does not help.
  while kill -0 "$pid" 2>/dev/null; do
    sleep 5
    idle=$(( $(date +%s) - $(stat -f %m "$log") ))
    if [ "$idle" -ge "$stall_after" ] && pgrep -f "$app/Contents/MacOS" >/dev/null; then
      echo "STALL: opened app after $idle s" >>"$log"
      open "$app"
    fi
    if [ $((SECONDS - started)) -ge "$run_timeout" ]; then
      echo "WATCHDOG: run exceeded $run_timeout s" >>"$log"
      kill_tree "$pid" TERM
      sleep 3
      kill_tree "$pid" KILL
      break
    fi
  done
  if wait "$pid"; then
    echo "run $i: pass"
  else
    failed=$((failed + 1))
    echo "run $i: FAIL -- $log"
    grep -E 'WATCHDOG|The following|Expected:|Actual:' "$log" | head -5
  fi
done

echo "$failed of $runs runs failed"
[ "$failed" -eq 0 ]
