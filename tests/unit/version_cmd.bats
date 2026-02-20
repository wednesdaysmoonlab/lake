#!/usr/bin/env bats
# Unit tests for: ./lakeup version
#
# Verifies version output against the LAKE_SETUP_VERSION variable in lakeup
# and that Laravel detection works with/without composer.lock.

load '../test_helper'

# Extract the version string from lakeup at load time
SCRIPT_VERSION=$(grep 'LAKE_SETUP_VERSION=' "$LAKEUP" | head -1 | sed 's/.*"\(.*\)".*/\1/')

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------

@test "version: exits 0" {
  run bash "$LAKEUP" version
  assert_success
}

# ---------------------------------------------------------------------------
# Output content
# ---------------------------------------------------------------------------

@test "version: output contains 'lakeup'" {
  run bash "$LAKEUP" version
  assert_output --partial "lakeup"
}

@test "version: output contains the script version number" {
  run bash "$LAKEUP" version
  assert_output --partial "$SCRIPT_VERSION"
}

# ---------------------------------------------------------------------------
# Laravel detection (run from a directory without artisan/composer.lock)
# ---------------------------------------------------------------------------

@test "version: reports Laravel not installed when run in empty tmpdir" {
  TEST_TMPDIR="$(mktemp -d)"
  run bash "$LAKEUP" version
  assert_output --partial "not installed"
  rm -rf "$TEST_TMPDIR"
}

@test "version: reports Laravel installed when artisan file exists" {
  TEST_TMPDIR="$(mktemp -d)"
  touch "$TEST_TMPDIR/artisan"
  # Run from the tmpdir context (version reads from CWD)
  run bash -c "cd '$TEST_TMPDIR' && bash '$LAKEUP' version"
  assert_output --partial "installed"
  rm -rf "$TEST_TMPDIR"
}

@test "version: extracts Laravel version from composer.lock" {
  TEST_TMPDIR="$(mktemp -d)"
  # Write a minimal composer.lock with a known Laravel version
  cat > "$TEST_TMPDIR/composer.lock" <<'JSON'
{
    "packages": [
        {
            "name": "laravel/framework",
            "version": "v11.99.0"
        }
    ]
}
JSON
  run bash -c "cd '$TEST_TMPDIR' && bash '$LAKEUP' version"
  assert_output --partial "v11.99.0"
  rm -rf "$TEST_TMPDIR"
}
