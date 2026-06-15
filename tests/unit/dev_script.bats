#!/usr/bin/env bats
# Unit tests for the dev-script patch.
#
# Tests the standalone wrapper at tests/helpers/patch_dev_script,
# which mirrors the inline `php artisan serve` → `.lake/frankenphp run`
# replacement in lakeup. If you change that sed in lakeup, update
# helpers/patch_dev_script to match.

load '../test_helper'

HELPER="$TESTS_DIR/helpers/patch_dev_script"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  cleanup_tmpdir
}

# Write a composer.json whose dev script's server slot is $1.
_write_composer() {
  cat > "$TEST_TMPDIR/composer.json" <<EOF
{
    "scripts": {
        "dev": [
            "Composer\\\\Config::disableProcessTimeout",
            "npx concurrently \"$1\" \"php artisan queue:listen\" --names=server,queue"
        ]
    }
}
EOF
}

_run_patch() {
  run bash -c "cd '$TEST_TMPDIR' && bash '$HELPER'"
}

# ---------------------------------------------------------------------------
# Flag stripping — the regression this fix addresses
# ---------------------------------------------------------------------------

@test "patch: strips trailing --host flag (the original bug)" {
  _write_composer 'php artisan serve --host=localhost'
  _run_patch
  assert_success
  grep -q '\.lake/frankenphp run' "$TEST_TMPDIR/composer.json"
  run grep -c -- '--host' "$TEST_TMPDIR/composer.json"
  assert_output "0"
}

@test "patch: strips both --host and --port flags" {
  _write_composer 'php artisan serve --host=localhost --port=8090'
  _run_patch
  assert_success
  grep -q '\.lake/frankenphp run' "$TEST_TMPDIR/composer.json"
  run grep -c -- '--host' "$TEST_TMPDIR/composer.json"
  assert_output "0"
  run grep -c -- '--port' "$TEST_TMPDIR/composer.json"
  assert_output "0"
}

@test "patch: strips flags regardless of order (--port before --host)" {
  _write_composer 'php artisan serve --port=8090 --host=127.0.0.1'
  _run_patch
  assert_success
  run grep -c -- '--host' "$TEST_TMPDIR/composer.json"
  assert_output "0"
  run grep -c -- '--port' "$TEST_TMPDIR/composer.json"
  assert_output "0"
}

# ---------------------------------------------------------------------------
# Plain serve (no flags) still works
# ---------------------------------------------------------------------------

@test "patch: replaces bare 'php artisan serve'" {
  _write_composer 'php artisan serve'
  _run_patch
  assert_success
  grep -q '\.lake/frankenphp run' "$TEST_TMPDIR/composer.json"
  run grep -c 'php artisan serve' "$TEST_TMPDIR/composer.json"
  assert_output "0"
}

# ---------------------------------------------------------------------------
# Other 'php artisan' commands must be left untouched
# ---------------------------------------------------------------------------

@test "patch: leaves 'php artisan queue:listen' untouched" {
  _write_composer 'php artisan serve --host=localhost'
  _run_patch
  assert_success
  grep -q 'php artisan queue:listen' "$TEST_TMPDIR/composer.json"
}

# ---------------------------------------------------------------------------
# No-op when there is nothing to patch
# ---------------------------------------------------------------------------

@test "patch: no-op when composer.json has no 'php artisan serve'" {
  _write_composer '.lake/frankenphp run'
  _run_patch
  assert_success
  grep -q '\.lake/frankenphp run' "$TEST_TMPDIR/composer.json"
}
