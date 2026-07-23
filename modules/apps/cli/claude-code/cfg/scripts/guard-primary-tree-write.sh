# PreToolUse hard block for agent-initiated git writes in the PRIMARY checkout.
#
# Epic #252 invariant #1: the shared primary checkout is read-only for agent
# task work, which belongs in per-issue worktrees. The github-issue worktree
# flow already isolates issue work, but nothing stopped an agent doing ad-hoc
# work (a flake bump, a secrets-template edit, a quick commit) from mutating the
# shared primary tree, where a second live session would then trip over the
# dirty tree or a moved HEAD. This denies the mutating git op BEFORE it runs,
# unlike the warn-level PostToolUse bash-guard in settings.json, which only
# notes a default-branch commit after the write has already landed.
#
# Covered ops (the ones that write the index or tree): commit, push, reset,
# merge, rebase, cherry-pick, add, rm, mv, clean. Not blanket read-only:
# git pull, git branch, git checkout/restore, and gh are intentionally NOT
# matched, so the SessionStart git-sync and the git-cleanup flow keep working.
# (Hooks and the github-issue CLI run git internally, not through the Bash
# tool, so this guard never sees their git; it only gates git the model runs
# as a Bash tool call.)
#
# Concurrent-session behaviour: two agents must never both mutate the primary
# tree. This guard makes that a hard failure rather than a warning. Agents work
# in linked worktrees (git-dir != git-common-dir), which are always allowed; the
# primary checkout (git-dir == git-common-dir) is denied unless the command
# carries the sanctioned marker below.
#
# Override: a user-directed flow (the /commit skill, git-cleanup) opts a single
# command in by prefixing it with `CLAUDE_SANCTIONED_GIT=1 git ...`. The marker
# rides on the one command and cannot leak into the rest of the session, unlike
# a session sentinel file that stays live until removed. It is a cooperative
# guardrail, not a security boundary: the point is to stop accidental and
# unsupervised writes, matching the single-user threat model and the stash
# guard, which is itself bypassable through plumbing. The marker frees the whole
# tool call it leads, not just the segment it prefixes; the sanctioned flows
# issue one git write per command, so a `marker git commit && git push` compound
# is not something they emit.
#
# Fails open on ambiguity: only a positive primary-tree match denies. If the
# target working tree cannot be resolved, the path is not a repo, or git errors,
# the command proceeds. The verb match is anchored to a command position (start
# of the line or right after a `; & | (` or backtick), so a git verb merely
# quoted or echoed in prose (`echo git commit`) never trips it. Mirrors
# guard-git-stash.sh.
#
# A PreToolUse "deny" can never be overridden by another hook's "allow", so this
# composes safely with the /auto auto-gate (auto-gate.sh) and the stash guard.
#
# wired into settings.json PreToolUse at activation (cfg/activation.nix),
# stripped on capture (cfg/fish.nix).

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

# Sanctioned override: a `CLAUDE_SANCTIONED_GIT=1` env assignment that LEADS the
# whole command and is immediately followed by git. The /commit and git-cleanup
# flows set this when the user explicitly directs a primary-tree write, and they
# always emit the marker as the first token of the command (one git write per
# Bash call). Anchoring to start-of-command is deliberate: grep is not
# shell-quote-aware, so honouring the marker after a `;` or `(` would let the
# phrase appear inside a quoted commit message (git commit -m "...; \
# CLAUDE_SANCTIONED_GIT=1 git ...") and wrongly free the write. Requiring the
# marker to lead, with git right after it, closes that. Allow and get out.
if grep -qE '^[[:space:]]*CLAUDE_SANCTIONED_GIT=1[[:space:]]+git([[:space:]]|$)' <<<"$cmd"; then
  exit 0
fi

# Match a mutating git subcommand at a command position. The leading class is the
# command-boundary set (start of string, or right after ; & | ( or a backtick),
# NOT a bare space, so a git verb sitting inside prose or a quoted argument does
# not match. Between the boundary and git, allow env-assignment prefixes
# (FOO=bar, including GIT_AUTHOR_DATE=...) and the common wrappers env/sudo/time/
# nice/nohup, so a wrapped or backdated write is still caught. Then allow
# `git -C <dir>` / `git -c k=v` / `git --git-dir=<d>` option prefixes and a
# quoted subcommand.
git_verb='(commit|push|reset|merge|rebase|cherry-pick|add|rm|mv|clean)'
git_lead='(([A-Za-z_][A-Za-z0-9_]*=\S+|sudo|env|time|nice|nohup)\s+)*'
if ! grep -qP "(^|[;&|(\`])\s*${git_lead}git(\s+-\S+(\s+[^-]\S*)?)*\s+[\"']?${git_verb}\b" <<<"$cmd"; then
  exit 0
fi

# Resolve the working tree the command would touch. Explicit repo targeting
# (`git -C`, `--work-tree`, `--git-dir`) wins over a leading `cd`, which wins
# over the hook's cwd. Ambiguity falls through to the hook cwd, and a git
# failure there fails open below.
strip_quotes() {
  local s="$1"
  s="${s%\"}"; s="${s#\"}"
  s="${s%\'}"; s="${s#\'}"
  printf '%s' "$s"
}

inspect_dir=""
gitdir_flag=""
if [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
  inspect_dir="$(strip_quotes "${BASH_REMATCH[1]}")"
elif [[ "$cmd" =~ --work-tree[=[:space:]]([^[:space:]]+) ]]; then
  inspect_dir="$(strip_quotes "${BASH_REMATCH[1]}")"
elif [[ "$cmd" =~ (^|[[:space:];&|])[[:space:]]*cd[[:space:]]+([^[:space:];&|]+) ]]; then
  inspect_dir="$(strip_quotes "${BASH_REMATCH[2]}")"
fi
if [[ "$cmd" =~ --git-dir[=[:space:]]([^[:space:]]+) ]]; then
  gitdir_flag="$(strip_quotes "${BASH_REMATCH[1]}")"
fi

git_args=()
[[ -n "$inspect_dir" ]] && git_args+=(-C "$inspect_dir")
[[ -n "$gitdir_flag" ]] && git_args+=(--git-dir "$gitdir_flag")

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
    permissionDecisionReason: "This is the shared primary checkout, which is read-only for agent task work (epic #252 invariant 1). A commit/push/reset/merge/rebase/cherry-pick/add/rm/mv/clean here can clobber another live session. Isolate the work in a linked worktree (github-issue setup <N>, or git worktree add) and run the git command there. If the user explicitly directed this primary-tree write, the sanctioned /commit and git-cleanup flows carry the CLAUDE_SANCTIONED_GIT=1 marker that allows it."
  }
}'
exit 0
