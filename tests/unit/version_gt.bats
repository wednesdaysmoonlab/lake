#!/usr/bin/env bats
# Unit tests for the _version_gt semver comparison helper.
#
# Tests the standalone wrapper at tests/helpers/version_gt,
# which mirrors the _version_gt() implementation in lakeup.
# If you change _version_gt in lakeup, update helpers/version_gt to match.

load '../test_helper'

HELPER="$TESTS_DIR/helpers/version_gt"

# ---------------------------------------------------------------------------
# Greater-than cases (should return exit 0)
# ---------------------------------------------------------------------------

@test "_version_gt: major bump (1.0.0 > 0.9.9)" {
  run bash "$HELPER" "1.0.0" "0.9.9"
  assert_success
}

@test "_version_gt: minor bump (0.4.0 > 0.3.9)" {
  run bash "$HELPER" "0.4.0" "0.3.9"
  assert_success
}

@test "_version_gt: patch bump (0.3.1 > 0.3.0)" {
  run bash "$HELPER" "0.3.1" "0.3.0"
  assert_success
}

@test "_version_gt: large major diff (2.0.0 > 1.99.99)" {
  run bash "$HELPER" "2.0.0" "1.99.99"
  assert_success
}

@test "_version_gt: pre-release vs release (1.0.0 > 0.99.99)" {
  run bash "$HELPER" "1.0.0" "0.99.99"
  assert_success
}

# ---------------------------------------------------------------------------
# Less-than cases (should return exit 1)
# ---------------------------------------------------------------------------

@test "_version_gt: older major is NOT greater (0.9.9 < 1.0.0)" {
  run bash "$HELPER" "0.9.9" "1.0.0"
  assert_failure
}

@test "_version_gt: older minor is NOT greater (0.2.0 < 0.3.0)" {
  run bash "$HELPER" "0.2.0" "0.3.0"
  assert_failure
}

@test "_version_gt: older patch is NOT greater (0.3.0 < 0.3.1)" {
  run bash "$HELPER" "0.3.0" "0.3.1"
  assert_failure
}

# ---------------------------------------------------------------------------
# Equal cases (should return exit 1 — equal is NOT greater-than)
# ---------------------------------------------------------------------------

@test "_version_gt: equal versions are NOT greater (0.3.0 == 0.3.0)" {
  run bash "$HELPER" "0.3.0" "0.3.0"
  assert_failure
}

@test "_version_gt: equal patch zero (1.0.0 == 1.0.0)" {
  run bash "$HELPER" "1.0.0" "1.0.0"
  assert_failure
}
