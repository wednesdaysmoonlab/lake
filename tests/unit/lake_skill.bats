#!/usr/bin/env bats
# Unit tests for the _install_lake_skill helper.
#
# Tests the standalone wrapper at tests/helpers/install_lake_skill,
# which mirrors the _install_lake_skill() implementation in lakeup.
# If you change _install_lake_skill in lakeup, update helpers/install_lake_skill to match.

load '../test_helper'

HELPER="$TESTS_DIR/helpers/install_lake_skill"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  cleanup_tmpdir
}

# Run the helper inside the tmpdir (it operates on the cwd).
_run_install() {
  run bash -c "cd '$TEST_TMPDIR' && bash '$HELPER'"
}

# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

@test "skill: exits 0" {
  _run_install
  assert_success
}

@test "skill: writes the Claude Code skill file" {
  _run_install
  [ -f "$TEST_TMPDIR/.claude/skills/lake/SKILL.md" ]
}

@test "skill: writes the Codex/OpenCode skill file" {
  _run_install
  [ -f "$TEST_TMPDIR/.agents/skills/lake/SKILL.md" ]
}

@test "skill: both files declare frontmatter name: lake" {
  _run_install
  grep -q '^name: lake$' "$TEST_TMPDIR/.claude/skills/lake/SKILL.md"
  grep -q '^name: lake$' "$TEST_TMPDIR/.agents/skills/lake/SKILL.md"
}

@test "skill: content tells agents to use the .lake/ shims" {
  _run_install
  grep -q '\.lake/php artisan' "$TEST_TMPDIR/.claude/skills/lake/SKILL.md"
  grep -q '\.lake/composer' "$TEST_TMPDIR/.agents/skills/lake/SKILL.md"
}

@test "skill: both files are byte-for-byte identical" {
  _run_install
  cmp -s "$TEST_TMPDIR/.claude/skills/lake/SKILL.md" \
         "$TEST_TMPDIR/.agents/skills/lake/SKILL.md"
}

# ---------------------------------------------------------------------------
# Idempotency / overwrite (Lake-owned dirs)
# ---------------------------------------------------------------------------

@test "skill: re-running leaves valid files (idempotent overwrite)" {
  _run_install
  _run_install
  assert_success
  grep -q '^name: lake$' "$TEST_TMPDIR/.claude/skills/lake/SKILL.md"
  grep -q '^name: lake$' "$TEST_TMPDIR/.agents/skills/lake/SKILL.md"
}

@test "skill: overwrites stale skill content on re-run" {
  mkdir -p "$TEST_TMPDIR/.claude/skills/lake"
  printf 'stale\n' > "$TEST_TMPDIR/.claude/skills/lake/SKILL.md"
  _run_install
  run cat "$TEST_TMPDIR/.claude/skills/lake/SKILL.md"
  refute_output --partial "stale"
  assert_output --partial "name: lake"
}
