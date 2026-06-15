#!/usr/bin/env bats
# Unit tests for the _seed_boost_php_path helper.
#
# Tests the standalone wrapper at tests/helpers/seed_boost_php_path,
# which mirrors the _seed_boost_php_path() implementation in lakeup.
# If you change _seed_boost_php_path in lakeup, update helpers/seed_boost_php_path to match.

load '../test_helper'

HELPER="$TESTS_DIR/helpers/seed_boost_php_path"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  cleanup_tmpdir
}

# Project tree with Laravel Boost installed and a typical .env.
_seed_with_boost() {
  mkdir -p "$TEST_TMPDIR/vendor/laravel/boost"
  mkdir -p "$TEST_TMPDIR/.lake"
  printf 'APP_NAME=Lake\nAPP_ENV=local\n' > "$TEST_TMPDIR/.env"
}

# Run the helper inside the tmpdir (it operates on the cwd).
_run_seed() {
  run bash -c "cd '$TEST_TMPDIR' && bash '$HELPER'"
}

# ---------------------------------------------------------------------------
# Happy path: Boost present + .env present
# ---------------------------------------------------------------------------

@test "seed: exits 0 when Boost is installed" {
  _seed_with_boost
  _run_seed
  assert_success
}

@test "seed: adds BOOST_PHP_EXECUTABLE_PATH to .env" {
  _seed_with_boost
  _run_seed
  grep -q '^BOOST_PHP_EXECUTABLE_PATH=' "$TEST_TMPDIR/.env"
}

@test "seed: value is an absolute path ending in /.lake/php" {
  _seed_with_boost
  _run_seed
  run grep '^BOOST_PHP_EXECUTABLE_PATH=' "$TEST_TMPDIR/.env"
  assert_output --partial "=\"/"
  assert_output --partial "/.lake/php\""
}

@test "seed: preserves existing .env lines" {
  _seed_with_boost
  _run_seed
  grep -q '^APP_NAME=Lake$' "$TEST_TMPDIR/.env"
  grep -q '^APP_ENV=local$' "$TEST_TMPDIR/.env"
}

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------

@test "seed: running twice leaves exactly one BOOST_PHP_EXECUTABLE_PATH line" {
  _seed_with_boost
  _run_seed
  _run_seed
  run grep -c '^BOOST_PHP_EXECUTABLE_PATH=' "$TEST_TMPDIR/.env"
  assert_output "1"
}

@test "seed: replaces a stale BOOST_PHP_EXECUTABLE_PATH value" {
  _seed_with_boost
  printf 'BOOST_PHP_EXECUTABLE_PATH=php\n' >> "$TEST_TMPDIR/.env"
  _run_seed
  run grep -c '^BOOST_PHP_EXECUTABLE_PATH=' "$TEST_TMPDIR/.env"
  assert_output "1"
  run grep '^BOOST_PHP_EXECUTABLE_PATH=' "$TEST_TMPDIR/.env"
  assert_output --partial "/.lake/php\""
}

@test "seed: appends a trailing newline before adding when .env lacks one" {
  mkdir -p "$TEST_TMPDIR/vendor/laravel/boost" "$TEST_TMPDIR/.lake"
  printf 'APP_NAME=Lake' > "$TEST_TMPDIR/.env"   # no trailing newline
  _run_seed
  grep -q '^APP_NAME=Lake$' "$TEST_TMPDIR/.env"
  grep -q '^BOOST_PHP_EXECUTABLE_PATH=' "$TEST_TMPDIR/.env"
}

# ---------------------------------------------------------------------------
# No-op guards
# ---------------------------------------------------------------------------

@test "seed: no-op when Boost is NOT installed" {
  mkdir -p "$TEST_TMPDIR/.lake"
  printf 'APP_NAME=Lake\n' > "$TEST_TMPDIR/.env"
  _run_seed
  assert_success
  run grep -c '^BOOST_PHP_EXECUTABLE_PATH=' "$TEST_TMPDIR/.env"
  assert_output "0"
}

@test "seed: no-op (and no .env created) when .env is absent" {
  mkdir -p "$TEST_TMPDIR/vendor/laravel/boost" "$TEST_TMPDIR/.lake"
  _run_seed
  assert_success
  [ ! -f "$TEST_TMPDIR/.env" ]
}
