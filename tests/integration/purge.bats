#!/usr/bin/env bats
# Integration tests for: ./lakeup purge
#
# Each test runs in a fresh isolated tmpdir containing a copy of lakeup.
# Verifies that purge removes the right files and preserves the right ones.

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

# Populate the tmpdir with a realistic post-install file tree
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

@test "purge: exits 0" {
  run bash "$LAKEUP_COPY" purge
  assert_success
}

# ---------------------------------------------------------------------------
# Protected files/dirs are preserved
# ---------------------------------------------------------------------------

@test "purge: preserves lakeup itself" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ -f "$TEST_TMPDIR/lakeup" ]
}

@test "purge: preserves .git directory" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ -d "$TEST_TMPDIR/.git" ]
}

@test "purge: preserves .gitignore" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ -f "$TEST_TMPDIR/.gitignore" ]
}

@test "purge: preserves README.md" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ -f "$TEST_TMPDIR/README.md" ]
}

@test "purge: preserves CLAUDE.md" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ -f "$TEST_TMPDIR/CLAUDE.md" ]
}

# ---------------------------------------------------------------------------
# Files/dirs that MUST be removed
# ---------------------------------------------------------------------------

@test "purge: removes .lake/ directory" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ ! -d "$TEST_TMPDIR/.lake" ]
}

@test "purge: removes vendor/ directory" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ ! -d "$TEST_TMPDIR/vendor" ]
}

@test "purge: removes composer.json" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ ! -f "$TEST_TMPDIR/composer.json" ]
}

@test "purge: removes composer.lock" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ ! -f "$TEST_TMPDIR/composer.lock" ]
}

@test "purge: removes artisan" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ ! -f "$TEST_TMPDIR/artisan" ]
}

@test "purge: removes .env" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ ! -f "$TEST_TMPDIR/.env" ]
}

@test "purge: removes app/ directory" {
  _seed_project
  bash "$LAKEUP_COPY" purge
  [ ! -d "$TEST_TMPDIR/app" ]
}

# ---------------------------------------------------------------------------
# Output messaging
# ---------------------------------------------------------------------------

@test "purge: output mentions 'Purging'" {
  run bash "$LAKEUP_COPY" purge
  assert_output --partial "Purging"
}

@test "purge: output mentions 'Done'" {
  run bash "$LAKEUP_COPY" purge
  assert_output --partial "Done"
}
