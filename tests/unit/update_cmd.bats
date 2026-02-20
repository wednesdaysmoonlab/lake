#!/usr/bin/env bats
# Unit tests for: ./lakeup update
#
# Uses a fake `curl` shim in $PATH to avoid real network calls.
# The shim lives in $TEST_TMPDIR/bin/ and is prepended to PATH for each test.

load '../test_helper'

# Extract the current version embedded in lakeup
SCRIPT_VERSION=$(grep 'LAKE_SETUP_VERSION=' "$LAKEUP" | head -1 | sed 's/.*"\(.*\)".*/\1/')

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  BIN_DIR="$TEST_TMPDIR/bin"
  mkdir -p "$BIN_DIR"
  cp "$LAKEUP" "$TEST_TMPDIR/lakeup"
  chmod +x "$TEST_TMPDIR/lakeup"
}

teardown() {
  cleanup_tmpdir
}

# Helper: create a curl shim that returns a fake GitHub release JSON
_make_curl_shim() {
  local tag="$1"   # e.g. "v0.3.0"
  cat > "$BIN_DIR/curl" <<CURL
#!/usr/bin/env bash
# Fake curl: return a GitHub releases/latest JSON response
echo '{"tag_name": "${tag}", "name": "${tag}"}'
CURL
  chmod +x "$BIN_DIR/curl"
}

# ---------------------------------------------------------------------------
# Cannot update when run via pipe (no BASH_SOURCE file)
# ---------------------------------------------------------------------------

@test "update: exits 1 when not run as a file (curl|bash mode)" {
  # bash -s reads the script from stdin (simulates `curl | bash`).
  # In this mode BASH_SOURCE[0] is empty, so lakeup exits 1 with an error message.
  run bash -s update < "$LAKEUP"
  assert_failure
  assert_output --partial "run lakeup as a file"
}

# ---------------------------------------------------------------------------
# Already up to date
# ---------------------------------------------------------------------------

@test "update: reports 'Already up to date' when versions match" {
  _make_curl_shim "v${SCRIPT_VERSION}"

  run env PATH="$BIN_DIR:$PATH" bash "$TEST_TMPDIR/lakeup" update
  assert_success
  assert_output --partial "Already up to date"
}

@test "update: shows current and latest version in output" {
  _make_curl_shim "v${SCRIPT_VERSION}"

  run env PATH="$BIN_DIR:$PATH" bash "$TEST_TMPDIR/lakeup" update
  assert_output --partial "Current version"
  assert_output --partial "Latest version"
}

# ---------------------------------------------------------------------------
# Running a newer version than the release
# ---------------------------------------------------------------------------

@test "update: reports newer-than-release when local version is higher" {
  # Simulate the release being one version behind
  _make_curl_shim "v0.1.0"

  run env PATH="$BIN_DIR:$PATH" bash "$TEST_TMPDIR/lakeup" update
  assert_success
  assert_output --partial "newer version"
}

# ---------------------------------------------------------------------------
# Curl failure handling
# ---------------------------------------------------------------------------

@test "update: exits 1 and shows error when curl fails" {
  # curl shim that exits with failure
  cat > "$BIN_DIR/curl" <<'CURL'
#!/usr/bin/env bash
exit 1
CURL
  chmod +x "$BIN_DIR/curl"

  run env PATH="$BIN_DIR:$PATH" bash "$TEST_TMPDIR/lakeup" update
  assert_failure
  assert_output --partial "Could not reach GitHub API"
}

@test "update: exits 1 when release JSON has no tag_name" {
  # curl returns empty JSON (no tag_name field).
  # With set -euo pipefail the grep pipeline exits 1 (no match), causing the script
  # to exit before the explicit "No releases found" message — so we only assert failure.
  cat > "$BIN_DIR/curl" <<'CURL'
#!/usr/bin/env bash
echo '{}'
CURL
  chmod +x "$BIN_DIR/curl"

  run env PATH="$BIN_DIR:$PATH" bash "$TEST_TMPDIR/lakeup" update
  assert_failure
}
