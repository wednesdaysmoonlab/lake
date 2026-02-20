#!/usr/bin/env bash
# Run the full lakeup test suite using BATS.
#
# Usage:
#   ./tests/run_tests.sh              # all tests
#   ./tests/run_tests.sh unit         # unit tests only
#   ./tests/run_tests.sh integration  # integration tests only
#   ./tests/run_tests.sh --filter "purge"  # filter by name pattern

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS="$TESTS_DIR/libs/bats-core/bin/bats"

if [[ ! -x "$BATS" ]]; then
  echo "ERROR: BATS not found at $BATS"
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

case "${1:-all}" in
  unit)         SUITE="$TESTS_DIR/unit" ;;
  integration)  SUITE="$TESTS_DIR/integration" ;;
  all)          SUITE=("$TESTS_DIR/unit" "$TESTS_DIR/integration") ;;
  --filter)     shift; exec "$BATS" --filter "$1" "$TESTS_DIR/unit" "$TESTS_DIR/integration" ;;
  *)            echo "Usage: $0 [unit|integration|all|--filter <pattern>]"; exit 1 ;;
esac

exec "$BATS" --recursive "${SUITE[@]}"
