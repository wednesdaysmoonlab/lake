#!/usr/bin/env bats
# Integration tests for: ./lakeup clean
#
# Verifies that clean removes Laravel app files but keeps .lake/ (the binaries).
# Each test runs in a fresh isolated tmpdir.

load '../test_helper'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  LAKEUP_COPY="$TEST_TMPDIR/lakeup"
  cp "$LAKEUP" "$LAKEUP_COPY"
  chmod +x "$LAKEUP_COPY"
}

teardown() {
  cleanup_tmpdir
}

_seed_project() {
  mkdir -p "$TEST_TMPDIR/vendor/laravel"
  mkdir -p "$TEST_TMPDIR/.lake"
  mkdir -p "$TEST_TMPDIR/app/Http"
  mkdir -p "$TEST_TMPDIR/database"
  touch "$TEST_TMPDIR/composer.json"
  touch "$TEST_TMPDIR/composer.lock"
  touch "$TEST_TMPDIR/artisan"
  touch "$TEST_TMPDIR/.env"
  touch "$TEST_TMPDIR/README.md"
  touch "$TEST_TMPDIR/.gitignore"
  touch "$TEST_TMPDIR/CLAUDE.md"
  touch "$TEST_TMPDIR/.lake/frankenphp"
  touch "$TEST_TMPDIR/.lake/composer.phar"
  git -C "$TEST_TMPDIR" init -q
}

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------

@test "clean: exits 0" {
  run bash "$LAKEUP_COPY" clean
  assert_success
}

# ---------------------------------------------------------------------------
# .lake/ is preserved (this is the key distinction from purge)
# ---------------------------------------------------------------------------

@test "clean: preserves .lake/ directory" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -d "$TEST_TMPDIR/.lake" ]
}

@test "clean: preserves .lake/frankenphp binary" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -f "$TEST_TMPDIR/.lake/frankenphp" ]
}

@test "clean: preserves .lake/composer.phar" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -f "$TEST_TMPDIR/.lake/composer.phar" ]
}

# ---------------------------------------------------------------------------
# Protected files preserved (same as purge)
# ---------------------------------------------------------------------------

@test "clean: preserves lakeup itself" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -f "$TEST_TMPDIR/lakeup" ]
}

@test "clean: preserves .git directory" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -d "$TEST_TMPDIR/.git" ]
}

@test "clean: preserves .gitignore" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -f "$TEST_TMPDIR/.gitignore" ]
}

@test "clean: preserves README.md" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -f "$TEST_TMPDIR/README.md" ]
}

@test "clean: preserves CLAUDE.md" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ -f "$TEST_TMPDIR/CLAUDE.md" ]
}

# ---------------------------------------------------------------------------
# Laravel files ARE removed
# ---------------------------------------------------------------------------

@test "clean: removes vendor/ directory" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ ! -d "$TEST_TMPDIR/vendor" ]
}

@test "clean: removes composer.json" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ ! -f "$TEST_TMPDIR/composer.json" ]
}

@test "clean: removes artisan" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ ! -f "$TEST_TMPDIR/artisan" ]
}

@test "clean: removes .env" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ ! -f "$TEST_TMPDIR/.env" ]
}

@test "clean: removes app/ directory" {
  _seed_project
  bash "$LAKEUP_COPY" clean
  [ ! -d "$TEST_TMPDIR/app" ]
}

# ---------------------------------------------------------------------------
# Output messaging
# ---------------------------------------------------------------------------

@test "clean: output mentions 'Cleaning'" {
  run bash "$LAKEUP_COPY" clean
  assert_output --partial "Cleaning"
}

@test "clean: output tells user to re-run lakeup" {
  run bash "$LAKEUP_COPY" clean
  assert_output --partial "lakeup"
}
