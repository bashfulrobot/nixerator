# PreToolUse hard block for manual `git stash` in worktree flows.
#
# The stash stack lives at refs/stash in the shared common git dir, so two
# agents in two worktrees push onto and pop the same stack. This denies a
# manual stash BEFORE it runs, unlike the warn-level PostToolUse bash-guard in
# settings.json (which fires after the command has already touched the stack).
# Recovery subcommands (pop/apply/list/show/drop) stay allowed so a human can
# retrieve an existing entry. Fails open on ambiguity: only a positive match
# denies, everything else proceeds.
#
# A PreToolUse "deny" can never be overridden by another hook's "allow", so
# this composes safely with the /auto auto-gate (see auto-gate.sh).
#
# wired into settings.json PreToolUse at activation (cfg/activation.nix).

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

# git [options] stash, with an optional quote before `stash`, unless the next
# token is a recovery subcommand. Catches quoted forms (git "stash"),
# option-prefixed forms (git -C /path stash), and substitution/subshell
# prefixes ($(git stash), `git stash`, (git stash)). The prefix class mirrors
# auto-gate.sh, plus a backtick. Recovery subcommands (including a quoted one)
# are allowed; `branch` reconstructs work from an entry, so it is recovery too,
# while `clear` stays denied because it discards the whole stack.
if grep -qP '(^|\s|;|&&|\||\(|`)git(\s+-\S+(\s+[^-]\S*)?)*\s+["'\'']?stash\b(?!\s+["'\'']?(pop|apply|list|show|drop|branch)\b)' <<<"$cmd"; then
  jq -nc '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "git stash is banned: the stash stack lives in the shared common git dir, so a second agent in another worktree can pop your entry. Commit in-progress work as a wip commit on the task branch (wip: summary), then git reset --soft HEAD^ to unwind. git stash pop/apply/list/show/drop stay allowed for recovery."
    }
  }'
  exit 0
fi
exit 0
