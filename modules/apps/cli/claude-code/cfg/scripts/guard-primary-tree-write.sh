# PreToolUse hard block for agent-initiated git writes in the PRIMARY checkout.
#
# Epic #252 invariant #1: the shared primary checkout is read-only for agents,
# and all task work happens in per-issue worktrees. The github-issue worktree
# flow already isolates issue work, but nothing stopped an agent doing ad-hoc
# work (a flake bump, a secrets-template edit, a quick commit) from mutating the
# shared primary tree, where a second live session would then trip over the
# dirty tree or a moved HEAD. This denies the mutating git op BEFORE it runs,
# unlike the warn-level PostToolUse bash-guard in settings.json, which only
# notes a default-branch commit after the write has already landed.
#
# Concurrent-session behaviour: two agents must never both mutate the primary
# tree. This guard makes that a hard failure rather than a warning. Agents work
# in linked worktrees (git-dir != git-common-dir), which are always allowed; the
# primary checkout (git-dir == git-common-dir) is denied unless the command
# carries the sanctioned marker below.
#
# Override: a user-directed flow (the /commit skill, git-cleanup) opts a single
# command in by prefixing it with `CLAUDE_SANCTIONED_GIT=1`. The marker rides on
# the one command and cannot leak into the rest of the session, unlike a session
# sentinel file that stays live until removed. It is a cooperative guardrail,
# not a security boundary: the point is to stop accidental and unsupervised
# writes, matching the single-user threat model and the stash guard, which is
# itself bypassable through plumbing.
#
# Fails open on ambiguity: only a positive primary-tree match denies. If the
# target working tree cannot be resolved, the path is not a repo, or git errors,
# the command proceeds. Mirrors guard-git-stash.sh.
#
# A PreToolUse "deny" can never be overridden by another hook's "allow", so this
# composes safely with the /auto auto-gate (auto-gate.sh) and the stash guard.
#
# wired into settings.json PreToolUse at activation (cfg/activation.nix),
# stripped on capture (cfg/fish.nix).

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

# Sanctioned override: a leading `CLAUDE_SANCTIONED_GIT=1` env assignment on the
# command (optionally after a `cd ... &&` or a separator). The /commit and
# git-cleanup flows set this when the user explicitly directs a primary-tree
# write. Allow and get out of the way.
if grep -qE '(^|;|&&|\|\||\||\()[[:space:]]*CLAUDE_SANCTIONED_GIT=1[[:space:]]' <<<"$cmd"; then
  exit 0
fi

# Match a mutating git subcommand. Allow `git -C <dir>` / `git -c k=v` option
# prefixes and a quoted subcommand. The verb set is exactly the one the issue
# names: commit, push, reset, merge, rebase, cherry-pick, add. git pull,
# git branch, and gh are intentionally excluded so the SessionStart git-sync and
# git-cleanup's branch deletion keep working.
git_verb='(commit|push|reset|merge|rebase|cherry-pick|add)'
if ! grep -qP "(^|\s|;|&&|\|\||\||\(|\`)git(\s+-\S+(\s+[^-]\S*)?)*\s+[\"']?${git_verb}\b" <<<"$cmd"; then
  exit 0
fi

# Resolve the target working tree the command would touch. Prefer an explicit
# `git -C <dir>`, else a leading `cd <dir>`, else the hook's cwd. Ambiguity
# (unresolvable) falls through to the hook cwd, and a git failure there fails
# open below.
target_dir=""
if [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
  target_dir="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ (^|[[:space:]]|;|&&)[[:space:]]*cd[[:space:]]+([^[:space:]&|;]+) ]]; then
  target_dir="${BASH_REMATCH[2]}"
fi
# Strip surrounding quotes a shell would remove.
target_dir="${target_dir%\"}"; target_dir="${target_dir#\"}"
target_dir="${target_dir%\'}"; target_dir="${target_dir#\'}"

git_args=()
[[ -n "$target_dir" ]] && git_args=(-C "$target_dir")

# In a linked worktree --git-dir is .../.git/worktrees/<name> while
# --git-common-dir is .../.git; in the primary checkout they resolve equal.
# Absolute path format so the comparison is exact.
gd="$(git "${git_args[@]}" rev-parse --path-format=absolute --git-dir 2>/dev/null || true)"
gcd="$(git "${git_args[@]}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"

# Fail open: not a repo, or either lookup failed.
[[ -n "$gd" && -n "$gcd" ]] || exit 0

# Linked worktree: allow.
[[ "$gd" != "$gcd" ]] && exit 0

# Primary checkout with a mutating git op and no sanction marker: deny.
jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "This is the shared primary checkout, which is read-only for agents (epic #252 invariant 1). A commit/push/reset/merge/rebase/cherry-pick/add here can clobber another live session. Isolate the work in a linked worktree (github-issue setup <N>, or git worktree add) and run the git command there. If the user explicitly directed this primary-tree write, the sanctioned /commit and git-cleanup flows carry the CLAUDE_SANCTIONED_GIT=1 marker that allows it."
  }
}'
exit 0
