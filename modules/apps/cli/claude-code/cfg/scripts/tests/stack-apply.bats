#!/usr/bin/env bats
# Regression tests for stack-apply.sh, the wrapper cfg/activation.nix calls
# when apps.cli.claude-code.stackApply.enable is on.
#
# What these pin, and why each one is a real risk rather than a tautology:
#
#   1. The @VAR@ values reach apply through a FILE, never inline on the
#      command line. `--vars` accepts both, and inline is the shorter thing to
#      write; a process argument list is readable by every other user through
#      `ps`, and the values include the declared `env` block.
#   2. No value from the vars file is printed, on the success path or on a
#      failure. apply itself prints key names and counts only, and this
#      wrapper must not undo that by echoing the file it builds.
#   3. XDG_RUNTIME_DIR is added from a real `id -u` at run time. Nix cannot
#      supply it: eval can run cross-host (`just build-host`) and would bake
#      in the wrong UID.
#   4. --write and --host are both passed. A dry run would make activation a
#      silent no-op; a missing --host would apply whatever `hostname -s` says,
#      which is wrong under apps.cli.claude-code.stackHost.
#   5. A missing claude_stack.py or resolved host file fails with a message
#      naming the fix, instead of a python traceback.
#   6. apply is retried once. apply reports SETTINGS_RACE and writes nothing
#      when Claude Code rewrote settings.json mid-merge, which a rebuild with
#      a live session open can hit; it is idempotent, so a retry is free.
#
# The real claude_stack.py lives in the claude-skills flake input and is not
# available here, so these drive a stub that records its own argv. The stub
# contract is apply's: `apply --write --host <h> --vars <v> --claude-dir <d>`.

WRAPPER="${BATS_TEST_DIRNAME}/../stack-apply.sh"

# A sentinel that must never appear in the wrapper's output. Put in the vars
# file as a var value, the same position a real env entry sits in.
SENTINEL="s3nt1nel-must-not-be-printed"

setup() {
  ROOT="${BATS_TEST_TMPDIR}/claude-skills"
  CLAUDE_DIR="${BATS_TEST_TMPDIR}/claude"
  ARGV_LOG="${BATS_TEST_TMPDIR}/argv.log"
  STUB_STATE="${BATS_TEST_TMPDIR}/stub-state"
  mkdir -p "$ROOT/scripts" "$ROOT/claude-stack/resolved" "$CLAUDE_DIR"

  printf '{"host":"testhost","vars":[]}\n' > "$ROOT/claude-stack/resolved/testhost.json"

  # The stub stands in for claude_stack.py. It appends its argv to $ARGV_LOG,
  # copies the vars file it was handed to $ARGV_LOG.vars so a test can assert
  # on the content, and exits with whatever $STUB_STATE says (empty = 0).
  cat > "$ROOT/scripts/claude_stack.py" <<'STUB'
import os
import shutil
import sys

with open(os.environ["ARGV_LOG"], "a") as fh:
    fh.write("\0".join(sys.argv[1:]) + "\n")
if "--vars" in sys.argv:
    src = sys.argv[sys.argv.index("--vars") + 1]
    if os.path.isfile(src):
        shutil.copyfile(src, os.environ["ARGV_LOG"] + ".vars")
state = os.environ.get("STUB_STATE", "")
fails = 0
if state and os.path.isfile(state):
    fails = int(open(state).read().strip() or "0")
calls = sum(1 for _ in open(os.environ["ARGV_LOG"]))
if calls <= fails:
    print("FAIL  SETTINGS_RACE  settings.json  changed during the merge")
    sys.exit(1)
print("host: testhost  (write)")
sys.exit(0)
STUB

  VARS="${BATS_TEST_TMPDIR}/vars.json"
  printf '{"LINUX_PATH":"/run/wrappers/bin","STATUSLINE_COMMAND":"%s"}\n' \
    "$SENTINEL" > "$VARS"

  export ARGV_LOG STUB_STATE
}

# The wrapper sleeps 1s between attempts; override sleep so the retry case
# does not cost a real second.
run_wrapper() {
  run env PATH="${BATS_TEST_TMPDIR}/bin:$PATH" bash "$WRAPPER" "$@"
}

fast_sleep() {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  printf '#!/bin/sh\nexit 0\n' > "${BATS_TEST_TMPDIR}/bin/sleep"
  chmod +x "${BATS_TEST_TMPDIR}/bin/sleep"
}

@test "passes --vars as a file path, not inline JSON" {
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  argv="$(tr '\0' '\n' < "$ARGV_LOG")"
  # The token after --vars is a readable file, and is not itself JSON.
  vars_arg="$(awk '/^--vars$/{getline; print; exit}' <<<"$argv")"
  [ -n "$vars_arg" ]
  case "$vars_arg" in
    '{'*) false ;;
    *) true ;;
  esac
}

@test "the vars file carries every supplied value plus XDG_RUNTIME_DIR" {
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  [ -f "${ARGV_LOG}.vars" ]
  run jq -r '.XDG_RUNTIME_DIR' "${ARGV_LOG}.vars"
  [ "$output" = "/run/user/$(id -u)" ]
  run jq -r '.LINUX_PATH' "${ARGV_LOG}.vars"
  [ "$output" = "/run/wrappers/bin" ]
}

@test "prints no value from the vars file" {
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"$SENTINEL"* ]]
}

@test "prints no value from the vars file when apply keeps failing" {
  fast_sleep
  printf '9\n' > "$STUB_STATE"
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" != *"$SENTINEL"* ]]
}

@test "passes --write, --host and --claude-dir" {
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  argv="$(tr '\0' ' ' < "$ARGV_LOG")"
  [[ "$argv" == *" --write "* ]]
  [[ "$argv" == *" --host testhost "* ]]
  [[ "$argv" == *" --claude-dir ${CLAUDE_DIR}"* ]]
  [[ "$argv" == "apply "* ]]
}

@test "defaults the claude dir to ~/.claude when the 4th argument is absent" {
  HOME="${BATS_TEST_TMPDIR}/fakehome" run_wrapper "$ROOT" testhost "$VARS"
  [ "$status" -eq 0 ]
  argv="$(tr '\0' ' ' < "$ARGV_LOG")"
  [[ "$argv" == *"--claude-dir ${BATS_TEST_TMPDIR}/fakehome/.claude"* ]]
}

@test "removes the vars file it created" {
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  vars_arg="$(tr '\0' '\n' < "$ARGV_LOG" | awk '/^--vars$/{getline; print; exit}')"
  [ ! -e "$vars_arg" ]
}

@test "retries once, then succeeds" {
  fast_sleep
  printf '1\n' > "$STUB_STATE"
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$ARGV_LOG")" -eq 2 ]
}

@test "gives up after the second failure" {
  fast_sleep
  printf '9\n' > "$STUB_STATE"
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 1 ]
  [ "$(wc -l < "$ARGV_LOG")" -eq 2 ]
  [[ "$output" == *"apply failed twice"* ]]
}

@test "keeps the pre-apply settings.json as settings.json.nix-backup, once" {
  printf '{"model":"before"}\n' > "$CLAUDE_DIR/settings.json"
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  run jq -r '.model' "$CLAUDE_DIR/settings.json.nix-backup"
  [ "$output" = "before" ]

  # A second run must not overwrite it: the backup is the PRE-stackApply file,
  # not the last apply's output.
  printf '{"model":"after"}\n' > "$CLAUDE_DIR/settings.json"
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  run jq -r '.model' "$CLAUDE_DIR/settings.json.nix-backup"
  [ "$output" = "before" ]
}

@test "makes no backup when there is no settings.json yet" {
  rm -f "$CLAUDE_DIR/settings.json"
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 0 ]
  [ ! -e "$CLAUDE_DIR/settings.json.nix-backup" ]
}

@test "a root without claude_stack.py names the fix" {
  rm -f "$ROOT/scripts/claude_stack.py"
  run_wrapper "$ROOT" testhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"re-lock the claude-skills flake input"* ]]
}

@test "an unresolved host names the fix" {
  run_wrapper "$ROOT" nosuchhost "$VARS" "$CLAUDE_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"resolved/nosuchhost.json"* ]]
}
