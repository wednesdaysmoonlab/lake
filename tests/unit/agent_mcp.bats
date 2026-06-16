#!/usr/bin/env bats
# Unit tests for the _patch_agent_mcp_php helper.
#
# Tests the standalone wrapper at tests/helpers/patch_agent_mcp, which mirrors
# the _patch_agent_mcp_php() implementation in lakeup. If you change that
# function in lakeup, update helpers/patch_agent_mcp to match.

load '../test_helper'

HELPER="$TESTS_DIR/helpers/patch_agent_mcp"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  cleanup_tmpdir
}

# Run the helper inside the tmpdir (it operates on the cwd).
_run_patch() {
  run bash -c "cd '$TEST_TMPDIR' && bash '$HELPER'"
}

# Expected absolute shim path the helper writes (matches $(pwd)/.lake/php).
_expected() {
  # macOS resolves /tmp → /private/tmp; mirror the helper's own $(pwd).
  ( cd "$TEST_TMPDIR" && printf '%s/.lake/php' "$(pwd)" )
}

# ---------------------------------------------------------------------------
# JSON string command form (.mcp.json, Zed, Amp, Cursor, Copilot, ...)
# ---------------------------------------------------------------------------

@test "patch: rewrites .mcp.json string command php → .lake/php" {
  cat > "$TEST_TMPDIR/.mcp.json" <<'EOF'
{
    "mcpServers": {
        "laravel-boost": {
            "command": "php",
            "args": ["artisan", "boost:mcp"]
        }
    }
}
EOF
  _run_patch
  assert_success
  run cat "$TEST_TMPDIR/.mcp.json"
  assert_output --partial "\"command\": \"$(_expected)\""
  refute_output --partial "\"command\": \"php\""
}

@test "patch: rewrites Zed and Amp string command form" {
  mkdir -p "$TEST_TMPDIR/.zed" "$TEST_TMPDIR/.amp"
  printf '{ "context_servers": { "x": { "command": "php" } } }\n' > "$TEST_TMPDIR/.zed/settings.json"
  printf '{ "amp.mcpServers": { "x": { "command": "php" } } }\n' > "$TEST_TMPDIR/.amp/settings.json"
  _run_patch
  assert_success
  run cat "$TEST_TMPDIR/.zed/settings.json"
  assert_output --partial "$(_expected)"
  run cat "$TEST_TMPDIR/.amp/settings.json"
  assert_output --partial "$(_expected)"
}

# ---------------------------------------------------------------------------
# JSON array command form (OpenCode) — the php element is on its own line
# ---------------------------------------------------------------------------

@test "patch: rewrites OpenCode array command php element" {
  cat > "$TEST_TMPDIR/opencode.json" <<'EOF'
{
    "mcp": {
        "laravel-boost": {
            "command": [
                "php",
                "artisan",
                "boost:mcp"
            ]
        }
    }
}
EOF
  _run_patch
  assert_success
  run cat "$TEST_TMPDIR/opencode.json"
  assert_output --partial "\"$(_expected)\","
  # The artisan/boost args must be left untouched.
  assert_output --partial "\"artisan\""
  assert_output --partial "\"boost:mcp\""
}

# ---------------------------------------------------------------------------
# TOML command form (Codex)
# ---------------------------------------------------------------------------

@test "patch: rewrites Codex TOML command php → .lake/php" {
  mkdir -p "$TEST_TMPDIR/.codex"
  cat > "$TEST_TMPDIR/.codex/config.toml" <<'EOF'
[mcp_servers.laravel-boost]
command = "php"
args = ["artisan", "boost:mcp"]
EOF
  _run_patch
  assert_success
  run cat "$TEST_TMPDIR/.codex/config.toml"
  assert_output --partial "command = \"$(_expected)\""
  refute_output --partial 'command = "php"'
}

# ---------------------------------------------------------------------------
# Idempotency & safety
# ---------------------------------------------------------------------------

@test "patch: leaves an already-correct config untouched" {
  abs="$(_expected)"
  printf '{ "mcpServers": { "x": { "command": "%s" } } }\n' "$abs" > "$TEST_TMPDIR/.mcp.json"
  before="$(cat "$TEST_TMPDIR/.mcp.json")"
  _run_patch
  assert_success
  run cat "$TEST_TMPDIR/.mcp.json"
  assert_output "$before"
}

@test "patch: exits 0 and is a no-op when no agent configs exist" {
  _run_patch
  assert_success
  refute_output --partial "Patched"
}

@test "patch: does not touch a non-command \"php\" value" {
  # A stray "php" string that is NOT an MCP command must be preserved.
  printf '{ "language": "php", "mcpServers": { "x": { "command": "php" } } }\n' > "$TEST_TMPDIR/.mcp.json"
  _run_patch
  assert_success
  run cat "$TEST_TMPDIR/.mcp.json"
  assert_output --partial '"language": "php"'
  assert_output --partial "\"command\": \"$(_expected)\""
}
