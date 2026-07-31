#!/usr/bin/env bats
# Regression tests for auto-gate.sh, the PreToolUse hook that is the sole
# arbiter for rm/kill/pkill during a /auto or /github-issues-auto session.
#
# Covers: the session-bound sentinel gate (unchanged from the original
# design), the always-on catastrophic-target circuit breaker for rm, the
# dynamic safe root (session cwd -> git toplevel or the cwd itself), the
# pre-authorized-folders file (with its sanity filtering), the universal
# scratch roots, and that kill/pkill stay unscoped once the sentinel matches.
#
# decision() drives the hook exactly the way the real harness does: JSON on
# stdin carrying tool_input.command, cwd, and session_id. HOME is pinned to a
# controlled fixture dir for the whole suite so $HOME-relative assertions
# (bare ~, the catastrophic $HOME check, the universal ~/.claude roots) are
# deterministic regardless of where the suite actually runs.
#
# Every bats fixture lives under $BATS_TEST_TMPDIR, which bats itself places
# under the system /tmp -- and /tmp is one of this hook's universal safe
# roots. So any "should be outside every safe root" fixture has to live
# somewhere that is NOT under /tmp, or the universal-scratch rule quietly
# makes it safe regardless of what's actually under test. $OUTSIDE is such a
# path, deliberately never created on disk: the hook only ever calls
# `realpath -m` (no existence required) and `git rev-parse` (fails closed,
# harmlessly, off a nonexistent dir) against rm targets, never touches the
# filesystem for real.

HOOK="${BATS_TEST_DIRNAME}/../auto-gate.sh"
OUTSIDE=/opt/nixerator-bats-outside-fixture

setup() {
  export HOME="${BATS_TEST_TMPDIR}/home"
  export CLAUDE_CONFIG_DIR="${HOME}/.claude"
  mkdir -p "$CLAUDE_CONFIG_DIR"

  REPO="${BATS_TEST_TMPDIR}/repo"
  SCRATCH="${BATS_TEST_TMPDIR}/scratch"
  mkdir -p "$REPO/sub" "$SCRATCH"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.email t@t.t
  git -C "$REPO" config user.name t
  # Explicit no-sign, independent of whatever the ambient gitconfig would
  # otherwise inherit -- HOME is repointed to this fixture dir above, which
  # has no signing key, so relying on ambient config to already disable
  # signing would be fragile.
  git -C "$REPO" -c commit.gpgsign=false commit -q --allow-empty -m init

  SID="test-session"
}

write_sentinel() {
  local sid="${1:-$SID}"
  jq -nc --arg sid "$sid" '{session_id: $sid}' >"${CLAUDE_CONFIG_DIR}/.auto-mode-active"
}

# decision <command> <cwd> [session_id]
decision() {
  local cmd="$1" cwd="$2" sid="${3:-}"
  jq -nc --arg c "$cmd" --arg cwd "$cwd" --arg sid "$sid" \
    '{tool_input: {command: $c}, cwd: $cwd} + (if $sid == "" then {} else {session_id: $sid} end)' \
    | bash "$HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // "none"'
}

@test "no sentinel: rm/kill/pkill all ask" {
  [ "$(decision "rm -rf $REPO/sub/x" "$REPO/sub")" = ask ]
  [ "$(decision "kill -9 12345" "$REPO/sub")" = ask ]
  [ "$(decision "pkill -f foo" "$REPO/sub")" = ask ]
}

@test "sentinel active, wrong session id: still ask" {
  write_sentinel "$SID"
  [ "$(decision "rm -rf $REPO/sub/x" "$REPO/sub" "someone-else")" = ask ]
}

@test "sentinel active, cwd inside a repo: rm inside that repo's toplevel allows" {
  write_sentinel
  [ "$(decision "rm -rf $REPO/sub/x" "$REPO/sub" "$SID")" = allow ]
  # resolved against the repo toplevel from a nested cwd too
  [ "$(decision "rm -rf $REPO/x" "$REPO/sub" "$SID")" = allow ]
}

@test "sentinel active, rm target outside the repo and outside every safe root: ask" {
  write_sentinel
  [ "$(decision "rm -rf $OUTSIDE/x" "$REPO/sub" "$SID")" = ask ]
}

@test "sentinel active, non-repo cwd (scratch dir): rm inside it allows" {
  write_sentinel
  [ "$(decision "rm -rf $SCRATCH/x" "$SCRATCH" "$SID")" = allow ]
}

@test "sentinel active, relative target with no cd in the command: resolves against session cwd" {
  write_sentinel
  [ "$(decision "rm -rf relfile" "$REPO/sub" "$SID")" = allow ]
}

@test "sentinel active, relative target but the command itself navigates: ambiguous, ask" {
  write_sentinel
  [ "$(decision "cd $SCRATCH && rm -rf relfile" "$REPO/sub" "$SID")" = ask ]
}

@test "sentinel active, compound command mixing a safe and an unsafe rm: whole call asks" {
  write_sentinel
  [ "$(decision "rm -rf $REPO/sub/a && rm -rf $OUTSIDE/b" "$REPO/sub" "$SID")" = ask ]
}

@test "sentinel active, rm mentioned only in quoted prose: not an invocation, decision unaffected by scoping" {
  write_sentinel
  [ "$(decision "echo 'please rm this note'" "$REPO/sub" "$SID")" = allow ]
}

@test "circuit breaker: bare root and bare HOME deny even with a matching sentinel" {
  write_sentinel
  [ "$(decision "rm -rf /" "$REPO/sub" "$SID")" = deny ]
  [ "$(decision "rm -rf ~" "$REPO/sub" "$SID")" = deny ]
}

@test "circuit breaker: system roots deny even with a matching sentinel" {
  write_sentinel
  for d in /etc /boot /nix /usr /var /root /sys /proc /bin /sbin /lib; do
    [ "$(decision "rm -rf $d/x" "$REPO/sub" "$SID")" = deny ]
  done
}

@test "circuit breaker: another user's home under /home denies" {
  write_sentinel
  [ "$(decision "rm -rf /home/someoneelse/x" "$REPO/sub" "$SID")" = deny ]
}

@test "circuit breaker: --no-preserve-root does not bypass it" {
  write_sentinel
  [ "$(decision "rm -rf --no-preserve-root /" "$REPO/sub" "$SID")" = deny ]
}

@test "circuit breaker: fires even with no sentinel at all" {
  [ "$(decision "rm -rf /etc/passwd" "$REPO/sub")" = deny ]
}

@test "kill/pkill: unscoped once the sentinel matches, regardless of cwd" {
  write_sentinel
  [ "$(decision "kill -9 99999" "$REPO/sub" "$SID")" = allow ]
  [ "$(decision "pkill -f some-unrelated-daemon" "$SCRATCH" "$SID")" = allow ]
}

@test "universal scratch roots: /tmp, jobs, and autonomous-runs dirs allow regardless of cwd" {
  write_sentinel
  [ "$(decision "rm -rf /tmp/whatever/x" "$REPO/sub" "$SID")" = allow ]
  [ "$(decision "rm -rf $HOME/.claude/jobs/abc/tmp/x" "$REPO/sub" "$SID")" = allow ]
  [ "$(decision "rm -rf $HOME/.claude/autonomous-runs/log.md" "$REPO/sub" "$SID")" = allow ]
}

@test "pre-authorized folders file: a listed folder allows rm outside cwd/repo" {
  write_sentinel
  local preauth="${HOME}/preauth"
  mkdir -p "$preauth"
  printf '# comment\n\n%s\n' "$preauth" >"${CLAUDE_CONFIG_DIR}/auto-safe-roots"
  [ "$(decision "rm -rf $preauth/x" "$REPO/sub" "$SID")" = allow ]
}

@test "pre-authorized folders file: a bare / entry is ignored, not honoured" {
  write_sentinel
  # If a bare "/" entry were accepted rather than filtered, path_has_prefix
  # would treat it as a prefix of literally everything, silently blessing
  # any target -- including one nowhere near /tmp, the repo, or $HOME. That's
  # exactly what this pins: without the is_catastrophic filter on load, this
  # would wrongly come back "allow".
  printf '%s\n' "/" >"${CLAUDE_CONFIG_DIR}/auto-safe-roots"
  [ "$(decision "rm -rf $OUTSIDE/randomfile" "$REPO/sub" "$SID")" = ask ]
}

@test "pre-authorized folders file: a too-shallow entry (depth < 3) is ignored" {
  write_sentinel
  # /opt alone is depth 1 (one path segment past root) -- below the floor.
  # Not under /tmp, so this isolates the depth filter from the universal
  # scratch-root rule.
  printf '%s\n' "/opt" >"${CLAUDE_CONFIG_DIR}/auto-safe-roots"
  [ "$(decision "rm -rf $OUTSIDE/randomfile" "$REPO/sub" "$SID")" = ask ]
}

@test "stale sentinel with a different session id never elevates this session" {
  write_sentinel "some-other-crashed-session"
  [ "$(decision "rm -rf $REPO/sub/x" "$REPO/sub" "$SID")" = ask ]
}
