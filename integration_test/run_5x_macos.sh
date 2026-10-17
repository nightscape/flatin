#!/usr/bin/env bash
# Repeats the macOS BDD run. A step that fails once in several runs is flaky,
# and one green run says nothing about it. Run from the repository root.
# A failed run whose log lacks "SemanticsHandle was active" is an infra failure
# (build or launch), not the semantics flake. FLUTTER overrides the flutter binary.
set -u

runs=${1:-5}
flutter_bin=${FLUTTER:-flutter}
mkdir -p target
failed=0
semantics=0

for i in $(seq 1 "$runs"); do
  log="target/bdd-macos-$i.log"
  if "$flutter_bin" test integration_test/ -d macos >"$log" 2>&1; then
    echo "run $i: pass"
  else
    failed=$((failed + 1))
    if grep -q 'SemanticsHandle was active' "$log"; then
      semantics=$((semantics + 1))
      echo "SEMANTICS-HANDLE-FLAKE run $i -- $log"
    else
      echo "run $i: INFRA-FAIL -- $log"
    fi
    grep -E 'The following|Expected:|Actual:' "$log" | head -5
  fi
done

echo "$failed of $runs runs failed ($semantics semantics-handle, $((failed - semantics)) infra)"
[ "$failed" -eq 0 ]
