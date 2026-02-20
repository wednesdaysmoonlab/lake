#!/usr/bin/env bats
# Unit tests for: ./lakeup help / --help / -h
#
# Verifies the help flag works in all its forms and outputs expected sections.
# Does NOT require a network connection or any downloads.

load '../test_helper'

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------

@test "help: exits 0 with 'help' subcommand" {
  run bash "$LAKEUP" help
  assert_success
}

@test "help: exits 0 with '--help' flag" {
  run bash "$LAKEUP" --help
  assert_success
}

@test "help: exits 0 with '-h' flag" {
  run bash "$LAKEUP" -h
  assert_success
}

# ---------------------------------------------------------------------------
# Output content
# ---------------------------------------------------------------------------

@test "help: output contains 'Usage:'" {
  run bash "$LAKEUP" help
  assert_output --partial "Usage:"
}

@test "help: output lists 'purge' command" {
  run bash "$LAKEUP" help
  assert_output --partial "purge"
}

@test "help: output lists 'clean' command" {
  run bash "$LAKEUP" help
  assert_output --partial "clean"
}

@test "help: output lists 'update' command" {
  run bash "$LAKEUP" help
  assert_output --partial "update"
}

@test "help: output lists 'version' command" {
  run bash "$LAKEUP" help
  assert_output --partial "version"
}

@test "help: output mentions FRANKEN_VERSION env override" {
  run bash "$LAKEUP" help
  assert_output --partial "FRANKEN_VERSION"
}

@test "help: output mentions LAKE_PORT env override" {
  run bash "$LAKEUP" help
  assert_output --partial "LAKE_PORT"
}

@test "help: all three flags produce identical output" {
  run bash "$LAKEUP" help;    out_help="$output"
  run bash "$LAKEUP" --help;  out_long="$output"
  run bash "$LAKEUP" -h;      out_short="$output"

  [ "$out_help" = "$out_long" ]
  [ "$out_help" = "$out_short" ]
}
