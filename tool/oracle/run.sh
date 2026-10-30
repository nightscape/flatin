#!/usr/bin/env bash
# Fetches the Collatinus data and runs the oracle test; extra args go to flutter test.
set -euo pipefail

"$(dirname "$0")/fetch_collatinus.sh"
flutter test --tags oracle --run-skipped "$@"
