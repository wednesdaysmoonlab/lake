#!/usr/bin/env bats
# Unit tests for: Laravel Octane install prompt in lakeup
#
# _confirm reads from /dev/tty, so the tests use a wrapper-script pattern:
# a small inline script redefines _confirm and _say, sets up fake .lake/ shims
# that log their calls, then runs only the Octane block.

load '../test_helper'

setup() {
  TEST_TMPDIR="$(mktemp -d)"

  # Fake composer shim — records invocations
  mkdir -p "$TEST_TMPDIR/.lake"
  printf '#!/usr/bin/env bash\necho "composer $*" >> "%s/calls.log"\n' \
    "$TEST_TMPDIR" > "$TEST_TMPDIR/.lake/composer"
  chmod +x "$TEST_TMPDIR/.lake/composer"

  # Fake php shim — records invocations
  printf '#!/usr/bin/env bash\necho "php $*" >> "%s/calls.log"\n' \
    "$TEST_TMPDIR" > "$TEST_TMPDIR/.lake/php"
  chmod +x "$TEST_TMPDIR/.lake/php"
}

teardown() { cleanup_tmpdir; }

# Helper: build the octane section as a standalone test script.
# $1 = confirm answer: 0 (yes) or 1 (no)
# $2 = path to composer.json to use (optional; defaults to none)
_make_octane_script() {
  local confirm_exit="$1"
  local composer_json="${2:-}"
  cat > "$TEST_TMPDIR/octane_test.sh" <<SCRIPT
#!/usr/bin/env bash
TOOLS_DIR="$TEST_TMPDIR/.lake"
_say()     { printf '✦ %s\n' "\$*"; }
_confirm() { return $confirm_exit; }

# ---- octane section (mirrors lakeup exactly) ----
if grep -q '"laravel/octane"' ${composer_json:-/dev/null} 2>/dev/null; then
    _say "Laravel Octane already installed, skipping."
else
    echo ""
    _say "Laravel Octane supercharges FrankenPHP performance."
    if _confirm "Install Laravel Octane (with FrankenPHP driver)?"; then
        _say "Installing laravel/octane..."
        "\$TOOLS_DIR/composer" require laravel/octane
        _say "Configuring Octane for FrankenPHP..."
        "\$TOOLS_DIR/php" artisan octane:install --server=frankenphp --no-interaction
        _say "Laravel Octane installed and configured."
    else
        _say "Skipped Laravel Octane."
    fi
fi
SCRIPT
  chmod +x "$TEST_TMPDIR/octane_test.sh"
}

@test "octane: runs composer and artisan when user accepts" {
  _make_octane_script 0   # _confirm returns 0 = yes
  run bash "$TEST_TMPDIR/octane_test.sh"
  assert_success
  assert_output --partial "Installing laravel/octane"
  assert_output --partial "Laravel Octane installed and configured"
  run grep -q "composer require laravel/octane" "$TEST_TMPDIR/calls.log"
  assert_success
  run grep -q "php artisan octane:install --server=frankenphp --no-interaction" \
    "$TEST_TMPDIR/calls.log"
  assert_success
}

@test "octane: skips install when user declines" {
  _make_octane_script 1   # _confirm returns 1 = no
  run bash "$TEST_TMPDIR/octane_test.sh"
  assert_success
  assert_output --partial "Skipped Laravel Octane"
  run test -f "$TEST_TMPDIR/calls.log"
  assert_failure   # calls.log must NOT exist — no commands were run
}

@test "octane: skips prompt when laravel/octane already in composer.json" {
  # Write a minimal composer.json that already contains laravel/octane
  printf '{"require": {"laravel/octane": "^2.0"}}\n' \
    > "$TEST_TMPDIR/composer.json"
  _make_octane_script 0 "$TEST_TMPDIR/composer.json"   # confirm=yes, but should never be reached
  run bash "$TEST_TMPDIR/octane_test.sh"
  assert_success
  assert_output --partial "already installed, skipping"
  run test -f "$TEST_TMPDIR/calls.log"
  assert_failure   # calls.log must NOT exist — no commands were run
}
