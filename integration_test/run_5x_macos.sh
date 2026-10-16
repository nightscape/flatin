#!/usr/bin/env bash
# Repeats the macOS BDD run. A step that fails once in several runs is flaky,
# and one green run says nothing about it. Run from the repository root.
set -u

runs=${1:-5}
mkdir -p target
failed=0

for i in $(seq 1 "$runs"); do
  log="target/bdd-macos-$i.log"
  if flutter test integration_test/ -d macos >"$log" 2>&1; then
    echo "run $i: pass"
  else
    failed=$((failed + 1))
    echo "run $i: FAIL -- $log"
    grep -E 'The following|Expected:|Actual:' "$log" | head -5
  fi
done

echo "$failed of $runs runs failed"
[ "$failed" -eq 0 ]
