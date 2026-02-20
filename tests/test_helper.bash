#!/usr/bin/env bash
# Shared setup loaded by every .bats file via: load '../test_helper'

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
LAKEUP="$REPO_ROOT/lakeup"

# Load bats-support and bats-assert helpers
load "$TESTS_DIR/libs/bats-support/load.bash"
load "$TESTS_DIR/libs/bats-assert/load.bash"

# Run lakeup in an isolated temp directory.
# Usage: run_lakeup_in_tmpdir [args...]
# After this function: $TEST_TMPDIR is the isolated dir, $LAKEUP_COPY is the path to lakeup inside it.
run_lakeup_in_tmpdir() {
  TEST_TMPDIR="$(mktemp -d)"
  LAKEUP_COPY="$TEST_TMPDIR/lakeup"
  cp "$LAKEUP" "$LAKEUP_COPY"
  chmod +x "$LAKEUP_COPY"
  run bash "$LAKEUP_COPY" "$@"
}

# Cleanup $TEST_TMPDIR if set (call from teardown)
cleanup_tmpdir() {
  [[ -n "${TEST_TMPDIR:-}" ]] && rm -rf "$TEST_TMPDIR"
}
