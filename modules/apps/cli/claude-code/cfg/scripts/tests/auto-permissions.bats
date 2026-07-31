#!/usr/bin/env bats
# Regression tests for auto-permissions.sh, the CLI that manages
# auto-gate.sh's pre-authorized-folders file and reports sentinel status.
# Validation rules must stay identical to auto-gate.sh's own (see both
# files' headers) -- these tests pin that a bad entry is refused with a
# non-zero exit, not silently accepted.

BIN="${BATS_TEST_DIRNAME}/../auto-permissions.sh"

setup() {
  export HOME="${BATS_TEST_TMPDIR}/home"
  export CLAUDE_CONFIG_DIR="${HOME}/.claude"
  mkdir -p "$HOME"
  ROOTS_FILE="${CLAUDE_CONFIG_DIR}/auto-safe-roots"
  SENTINEL="${CLAUDE_CONFIG_DIR}/.auto-mode-active"
  # Outside /tmp on purpose -- see auto-gate.bats for why: bats fixtures live
  # under system /tmp, which is itself a universal safe root in auto-gate.sh,
  # so a "should be refused/absent" fixture has to live somewhere else.
  FOLDER=/opt/nixerator-bats-fixture/auto-permissions
}

run_bin() { bash "$BIN" "$@"; }

@test "list on an empty/missing file says so" {
  run run_bin list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No pre-authorized folders"* ]]
}

@test "add a valid folder, then list shows it active" {
  run run_bin add "$FOLDER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pre-authorized: $FOLDER"* ]]

  run run_bin list
  [[ "$output" == *"$FOLDER -- active"* ]]
}

@test "add is idempotent: re-adding the same folder is a no-op, not a duplicate line" {
  run_bin add "$FOLDER"
  run run_bin add "$FOLDER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already pre-authorized"* ]]
  [ "$(grep -c "$FOLDER" "$ROOTS_FILE")" -eq 1 ]
}

@test "add refuses a catastrophic entry with a non-zero exit and writes nothing" {
  run run_bin add /
  [ "$status" -ne 0 ]
  [[ "$output" == *"catastrophic"* ]]
  [ ! -s "$ROOTS_FILE" ]

  run run_bin add "$HOME"
  [ "$status" -ne 0 ]
  [[ "$output" == *"catastrophic"* ]]
}

@test "add refuses a too-shallow entry with a non-zero exit" {
  run run_bin add /opt
  [ "$status" -ne 0 ]
  [[ "$output" == *"too shallow"* || "$output" == *"shallow"* ]]
  [ ! -s "$ROOTS_FILE" ]
}

@test "remove drops the entry; a second remove reports nothing found" {
  run_bin add "$FOLDER"
  run run_bin remove "$FOLDER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed: $FOLDER"* ]]

  run run_bin list
  [[ "$output" == *"No pre-authorized folders"* ]]

  run run_bin remove "$FOLDER"
  [[ "$output" == *"Not found"* ]]
}

@test "remove preserves comments and other entries" {
  mkdir -p "$CLAUDE_CONFIG_DIR"
  printf '# a comment\n%s\n/opt/other-fixture/x/y\n' "$FOLDER" >"$ROOTS_FILE"
  run_bin remove "$FOLDER"
  [[ "$(cat "$ROOTS_FILE")" == *"# a comment"* ]]
  [[ "$(cat "$ROOTS_FILE")" == *"/opt/other-fixture/x/y"* ]]
  ! grep -q "$FOLDER" "$ROOTS_FILE"
}

@test "list flags a hand-edited catastrophic or shallow entry as ignored" {
  mkdir -p "$CLAUDE_CONFIG_DIR"
  printf '%s\n%s\n' "/" "/opt" >"$ROOTS_FILE"
  run run_bin list
  [[ "$output" == *"IGNORED (catastrophic"* ]]
  [[ "$output" == *"IGNORED (too shallow"* ]]
}

@test "status with no sentinel file says so" {
  run run_bin status
  [ "$status" -eq 0 ]
  [[ "$output" == *"No autonomous session sentinel active"* ]]
}

@test "status reports active for a matching session id" {
  mkdir -p "$CLAUDE_CONFIG_DIR"
  jq -nc --arg sid abc123 --arg goal "test" '{session_id: $sid, goal: $goal, started: "2026-01-01T00:00:00Z"}' >"$SENTINEL"
  export CLAUDE_CODE_SESSION_ID=abc123
  run run_bin status
  [[ "$output" == *"Active for THIS session"* ]]
}

@test "status reports inert for a mismatched session id" {
  mkdir -p "$CLAUDE_CONFIG_DIR"
  jq -nc --arg sid abc123 '{session_id: $sid}' >"$SENTINEL"
  export CLAUDE_CODE_SESSION_ID=someone-else
  run run_bin status
  [[ "$output" == *"Does NOT match this session"* ]]
}

@test "no arguments and an unknown subcommand both print usage" {
  run run_bin
  [[ "$output" == *"Usage:"* ]]

  run run_bin bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown subcommand"* ]]
}
