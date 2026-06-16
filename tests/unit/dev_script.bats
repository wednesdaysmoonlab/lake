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

# A faithful composer.json: the dev script is a JSON string whose inner commands
# are wrapped in ESCAPED quotes (\"), exactly as Laravel's skeleton ships it
# (e.g. `... \"php artisan serve --host=localhost\" ...`). The quoted heredoc
# keeps backslashes literal so the on-disk bytes match a real composer.json.
_write_real_composer() {
  cat > "$TEST_TMPDIR/composer.json" <<'EOF'
{
    "name": "laravel/laravel",
    "autoload": { "psr-4": { "App\\": "app/" } },
    "scripts": {
        "dev": [
            "Composer\\Config::disableProcessTimeout",
            "npx concurrently -c \"#93c5fd,#c4b5fd\" \"php artisan serve --host=localhost\" \"php artisan queue:listen --tries=1 --timeout=0\" \"npm run dev\" --names=server,queue,vite --kill-others"
        ]
    }
}
EOF
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

# ---------------------------------------------------------------------------
# Escaped-quote regression — the bug that corrupted composer.json into the
# 109-byte stub. The serve command sits inside escaped quotes (`...localhost\"`);
# a value class that matched the backslash ate the escape, unbalanced the
# quotes, and produced invalid JSON. The patch MUST leave valid JSON.
# ---------------------------------------------------------------------------

@test "patch: real escaped-quote composer.json stays valid JSON" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  _write_real_composer
  # Sanity: fixture is valid JSON before patching.
  python3 -c "import json; json.load(open('$TEST_TMPDIR/composer.json'))"
  _run_patch
  assert_success
  run python3 -c "import json; json.load(open('$TEST_TMPDIR/composer.json'))"
  assert_success
}

@test "patch: real composer.json preserves the escaped closing quote" {
  _write_real_composer
  _run_patch
  assert_success
  # Correct output keeps the backslash-escaped quote: ...frankenphp run\"
  grep -q 'frankenphp run\\"' "$TEST_TMPDIR/composer.json"
  # --host must be gone, queue command untouched.
  run grep -c -- '--host' "$TEST_TMPDIR/composer.json"
  assert_output "0"
  grep -q 'php artisan queue:listen' "$TEST_TMPDIR/composer.json"
}
