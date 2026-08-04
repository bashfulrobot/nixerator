#!/usr/bin/env bats
# Regression tests for guard-enter-worktree-collision.sh, the PreToolUse deny
# hook that refuses an EnterWorktree(name=...) call whose name already
# resolves to an existing worktree directory or the branch EnterWorktree
# itself would create (worktree-<name>). EnterWorktree silently RESUMES on a
# name collision instead of erroring, so this hook is what makes a fresh
# worktree per spawn a guarantee rather than a best effort (1:1
# worktree:agent mapping, no accidental resume).
#
# decision() runs the hook with cwd set to $REPO (a real repo the test
# controls) unless a case overrides it, so the git-toplevel resolution is
# exercised for real rather than mocked.

HOOK="${BATS_TEST_DIRNAME}/../guard-enter-worktree-collision.sh"

setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  NONREPO="${BATS_TEST_TMPDIR}/nonrepo"
  mkdir -p "$NONREPO"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.email t@t.t
  git -C "$REPO" config user.name t
  git -C "$REPO" commit -q --allow-empty -m init
}

# Echo the hook's decision (deny/allow) for a given (name, path) tool_input,
# run from $REPO unless a 3rd arg overrides the cwd.
decision() {
  local name="$1" path="${2:-}" cwd="${3:-$REPO}" json out
  json="$(jq -nc --arg n "$name" --arg p "$path" '{tool_input: ({} + (if $n != "" then {name:$n} else {} end) + (if $p != "" then {path:$p} else {} end))}')"
  out="$(cd "$cwd" && printf '%s' "$json" | bash "$HOOK" 2>/dev/null)"
  if grep -q '"permissionDecision": *"deny"' <<<"$out"; then echo deny; else echo allow; fi
}

@test "allows a name with no existing worktree dir or branch" {
  [ "$(decision "fresh-name")" = allow ]
}

@test "denies a name matching an existing worktree directory" {
  mkdir -p "$REPO/.claude/worktrees/taken"
  [ "$(decision "taken")" = deny ]
}

@test "denies a name matching an existing worktree-<name> branch with no directory" {
  git -C "$REPO" branch worktree-orphan-branch
  [ "$(decision "orphan-branch")" = deny ]
}

@test "the deny reason names the collision and suggests an alternative" {
  mkdir -p "$REPO/.claude/worktrees/taken"
  local json out reason
  json="$(jq -nc '{tool_input:{name:"taken"}}')"
  out="$(cd "$REPO" && printf '%s' "$json" | bash "$HOOK" 2>/dev/null)"
  reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$out")"
  [[ "$reason" == *"taken"* ]]
  [[ "$reason" == *"path"* ]]
}

@test "never denies a path-based call, even if name would have collided" {
  mkdir -p "$REPO/.claude/worktrees/taken"
  [ "$(decision "" "$REPO/.claude/worktrees/taken")" = allow ]
}

@test "allows when neither name nor path is set" {
  [ "$(decision "")" = allow ]
}

@test "fails open outside a git repo" {
  [ "$(decision "taken" "" "$NONREPO")" = allow ]
}
