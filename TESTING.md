# Testing Guide

Lake uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) to test `lakeup`. All tests run without network access, FrankenPHP, PHP, or Composer — making them fast, self-contained, and CI-friendly.

---

## Quick start

```bash
# One-time setup: pull the BATS submodules
git submodule update --init --recursive

# Run all tests
./tests/run_tests.sh

# Run only unit tests
./tests/run_tests.sh unit

# Run only integration tests
./tests/run_tests.sh integration

# Run tests matching a name pattern
./tests/run_tests.sh --filter "purge"
```

---

## Directory structure

```
tests/
├── libs/
│   ├── bats-core/       # BATS framework (git submodule)
│   ├── bats-support/    # Output helpers (git submodule)
│   └── bats-assert/     # Assertion helpers (git submodule)
├── helpers/
│   └── version_gt       # Standalone wrapper for the _version_gt function
├── unit/
│   ├── help.bats        # ./lakeup help / --help / -h
│   ├── version_cmd.bats # ./lakeup version
│   ├── version_gt.bats  # _version_gt semver comparison helper
│   └── update_cmd.bats  # ./lakeup update (network calls stubbed with fake curl)
├── integration/
│   ├── purge.bats       # ./lakeup purge (isolated tmpdir)
│   └── clean.bats       # ./lakeup clean (isolated tmpdir)
├── test_helper.bash     # Shared setup: loads bats-assert, defines helpers
└── run_tests.sh         # Test runner
```

---

## Test tiers

| Tier | Location | What it covers | Speed |
|---|---|---|---|
| **Unit** | `tests/unit/` | Individual commands and pure functions | < 5 s |
| **Integration** | `tests/integration/` | Filesystem mutations in isolated tmpdirs | < 10 s |
| **E2E** *(future)* | *(CI only)* | Full bootstrap including downloads | Minutes |

Unit and integration tests run on every push and PR via GitHub Actions (`.github/workflows/test.yml`).

---

## Writing tests for a new feature

### 1. Identify the test tier

| What you're testing | Tier | Example |
|---|---|---|
| Pure bash function | Unit | `_version_gt`, `_say` |
| CLI subcommand (no downloads) | Unit | `help`, `version`, `update` |
| Filesystem side-effects | Integration | `purge`, `clean` |
| Full bootstrap (requires network) | E2E | `./lakeup` |

### 2. Create the test file

**Unit test skeleton** (`tests/unit/<feature>.bats`):

```bash
#!/usr/bin/env bats
# Unit tests for: ./lakeup <feature>
# Brief description of what is being tested.

load '../test_helper'

setup() {
  # Runs before each @test block.
  # Use this to create tmpdirs, mock binaries, etc.
}

teardown() {
  # Runs after each @test block — always, even on failure.
  cleanup_tmpdir   # removes $TEST_TMPDIR if set
}

@test "<feature>: exits 0 on success" {
  run bash "$LAKEUP" <feature>
  assert_success
}

@test "<feature>: output contains expected text" {
  run bash "$LAKEUP" <feature>
  assert_output --partial "expected text"
}
```

**Integration test skeleton** (`tests/integration/<feature>.bats`):

```bash
#!/usr/bin/env bats
# Integration tests for: ./lakeup <feature>

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

@test "<feature>: files are created correctly" {
  run bash "$LAKEUP_COPY" <feature>
  assert_success
  [ -f "$TEST_TMPDIR/expected-file" ]
}
```

### 3. Mock network calls

Never make real HTTP requests in tests. Stub `curl` with a fake binary prepended to `$PATH`:

```bash
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  BIN_DIR="$TEST_TMPDIR/bin"
  mkdir -p "$BIN_DIR"
  cp "$LAKEUP" "$TEST_TMPDIR/lakeup"
  chmod +x "$TEST_TMPDIR/lakeup"
}

# Create a curl shim that returns a fixed response
_make_curl_shim() {
  cat > "$BIN_DIR/curl" <<'CURL'
#!/usr/bin/env bash
echo '{"tag_name": "v1.0.0"}'
CURL
  chmod +x "$BIN_DIR/curl"
}

@test "something that calls curl" {
  _make_curl_shim
  run env PATH="$BIN_DIR:$PATH" bash "$TEST_TMPDIR/lakeup" update
  assert_success
}
```

### 4. Test helper: pure functions

When testing a pure bash function (like `_version_gt`) that cannot be cleanly sourced from `lakeup` (because the script runs code at the top level on source), add a standalone wrapper in `tests/helpers/`:

```bash
#!/usr/bin/env bash
# tests/helpers/my_function
#
# Mirror of my_function() from lakeup.
# Keep in sync with lakeup when the function changes.

my_function() {
  # ... exact copy of the function body ...
}

my_function "$@"
```

Then test it:

```bash
HELPER="$TESTS_DIR/helpers/my_function"

@test "my_function: does the thing" {
  run bash "$HELPER" arg1 arg2
  assert_success
}
```

> **Important:** When you change a helper function in `lakeup`, update the matching file in `tests/helpers/` and re-run the tests.

---

## Assertion reference

These come from `bats-assert` (loaded via `test_helper.bash`):

```bash
assert_success                        # status == 0
assert_failure                        # status != 0
assert_output "exact string"          # full output matches
assert_output --partial "substring"   # output contains substring
assert_output --regexp "pattern"      # output matches regex
refute_output --partial "substring"   # output does NOT contain substring

# Raw bash assertions also work inside @test:
[ -f "$path" ]          # file exists
[ -d "$path" ]          # directory exists
[ ! -f "$path" ]        # file does not exist
[ "$a" = "$b" ]         # string equality
```

---

## Checklist: adding a new `lakeup` command

When you add a new subcommand (e.g., `./lakeup foo`), create tests that verify:

- [ ] **Exit code** — exits 0 on success, 1 on error
- [ ] **Output messages** — key `_say` lines appear in output
- [ ] **Side effects** — files/dirs created or removed as expected
- [ ] **Edge cases** — missing files, bad input, env override flags
- [ ] **Idempotency** — running twice is safe (if applicable)
- [ ] **Isolation** — tests use `$TEST_TMPDIR`, never the real project directory

---

## Checklist: modifying an existing command

- [ ] Run the existing tests first: `./tests/run_tests.sh`
- [ ] Update or add tests to cover your change
- [ ] If you changed a helper function (e.g., `_version_gt`), update `tests/helpers/` too
- [ ] All 64+ tests must pass before merging

---

## CI

Tests run automatically on every push to `main` or `pre-release` and on every PR targeting `main`. See `.github/workflows/test.yml`.

To run the same check locally before pushing:

```bash
./tests/run_tests.sh
```

---

## set -euo pipefail gotchas

`lakeup` runs under `set -euo pipefail`. Be aware of these when writing tests:

| Gotcha | Impact on tests |
|---|---|
| `grep` exits 1 when no match found | Pipelines involving grep on unmatched input may kill the script silently — test for `assert_failure` not a specific message |
| `read -r` from `/dev/tty` | Interactive prompts cannot be tested directly; design tests to take paths that avoid `_confirm`/`_ask` |
| Command substitution `$(...)` | In some bash versions, a failing pipeline inside `$()` triggers `set -e` on the enclosing script |

---

## BATS submodule maintenance

The BATS libraries are pinned via git submodules. To update them:

```bash
git submodule update --remote tests/libs/bats-core
git submodule update --remote tests/libs/bats-support
git submodule update --remote tests/libs/bats-assert
git add tests/libs
git commit -m "chore: update BATS submodules"
```
