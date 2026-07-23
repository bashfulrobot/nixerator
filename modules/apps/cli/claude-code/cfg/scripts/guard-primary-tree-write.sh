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
# Override: the user-directed /commit skill opts a single command in by
# prefixing it with `CLAUDE_SANCTIONED_GIT=1 git ...`. (The git-cleanup flow
# needs no marker: its writes land in a worktree, or run through the pull,
# branch, and gh-merge verbs this guard deliberately does not match.) The marker
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
# Bash call). This uses bash `[[ =~ ]]`, whose `^` anchors to the START OF THE
# STRING, not per line. grep `^` matches the start of any line, which would let
# the marker on a later line of a multiline command (or inside a quoted, newline
# bearing commit message) free an unmarked write on an earlier line. Anchoring
# to the string start, with git right after the marker, closes both the
# quoted-message and the multiline forms. Allow and get out.
if [[ "$cmd" =~ ^[[:space:]]*CLAUDE_SANCTIONED_GIT=1[[:space:]]+git([[:space:]]|$) ]]; then
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
verb_re="(^|[;&|(\`])\s*${git_lead}git(\s+-\S+(\s+[^-]\S*)?)*\s+[\"']?${git_verb}\b"

strip_quotes() {
  local s="$1"
  s="${s%\"}"; s="${s#\"}"
  s="${s%\'}"; s="${s#\'}"
  printf '%s' "$s"
}

emit_deny() {
  jq -nc '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "This is the shared primary checkout, which is read-only for agent task work (epic #252 invariant 1). A commit/push/reset/merge/rebase/cherry-pick/add/rm/mv/clean here can clobber another live session. Isolate the work in a linked worktree (github-issue setup <N>, or git worktree add) and run the git command there. If the user explicitly directed this primary-tree write, the sanctioned /commit flow carries the CLAUDE_SANCTIONED_GIT=1 marker that allows it."
    }
  }'
}

# Collect every cwd change (cd or pushd) with its byte offset. A bare git verb
# (one that names no repo of its own) runs in the tree set by the NEAREST cwd
# change before it, so tracking offsets lets
# `cd <wt> && git status && cd <primary> && git commit` resolve the commit
# against <primary>, not the first cd.
#
# Heuristic limits, all in the fail-open (allow) direction except where noted:
#   - A cwd change scoped inside a subshell `( ... )` does NOT persist to
#     commands after the group, so a match whose boundary char is `(` is not
#     added to the persistent list. This keeps
#     `cd <primary> && (cd <wt> && ...) && git commit` resolving to <primary>.
#     A git write INSIDE a subshell then falls back to an outer cd or the hook
#     cwd, which can wrongly DENY a subshelled worktree write (fail-safe), never
#     wrongly allow a primary one.
#   - Leading cd/pushd options (`-P`, `-L`, `--`) are skipped so the path, not
#     the flag, is captured; otherwise `cd -P <primary> && git commit` would
#     resolve `git -C -P`, error, and fail open on a primary write.
#   - popd is not modelled (it pops a stack this parser does not track), and a
#     directory or `git -C` argument quoted with an embedded space is not
#     resolved (tokenisation is space-delimited, not shell-quote aware). Both
#     leave the invocation to fail open.
cd_re='(cd|pushd)([[:space:]]+-[^[:space:];&|]+)*[[:space:]]+([^[:space:];&|]+)'
cd_offsets=()
cd_dirs=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  off="${line%%:*}"
  m="${line#*:}"
  # A subshell-scoped cwd change (boundary char `(`) does not outlive its group.
  [[ "${m:0:1}" == "(" ]] && continue
  if [[ "$m" =~ $cd_re ]]; then
    cd_offsets+=("$off")
    cd_dirs+=("$(strip_quotes "${BASH_REMATCH[3]}")")
  fi
done < <(grep -boP "(^|[;&|(])[[:space:]]*${cd_re}" <<<"$cmd" || true)

# The cd dir with the greatest offset still before $1 (empty if none).
last_cd_before() {
  local target="$1" i best_off=-1 best_dir=""
  for i in "${!cd_offsets[@]}"; do
    if ((cd_offsets[i] < target)) && ((cd_offsets[i] > best_off)); then
      best_off="${cd_offsets[i]}"
      best_dir="${cd_dirs[i]}"
    fi
  done
  printf '%s' "$best_dir"
}

# Resolve the working tree PER verb-bearing git invocation, not once for the
# whole line, so a compound that mixes trees (git -C <worktree> ... && git commit
# in the primary cwd) is judged on the invocation that actually carries the
# mutating verb. Deny as soon as any such invocation resolves to the primary
# checkout. Explicit repo targeting on that invocation (`git -C`, `--work-tree`,
# `--git-dir`) wins over the nearest preceding `cd`, which wins over the hook
# cwd. Fail open per invocation: a git error (not a repo) skips it. If nothing
# matches a mutating verb, the loop runs zero times and the command is allowed.
while IFS= read -r match; do
  [[ -n "$match" ]] || continue
  moff="${match%%:*}"
  seg="${match#*:}"
  inspect_dir=""
  gitdir_flag=""
  if [[ "$seg" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    inspect_dir="$(strip_quotes "${BASH_REMATCH[1]}")"
  elif [[ "$seg" =~ --work-tree[=[:space:]]([^[:space:]]+) ]]; then
    inspect_dir="$(strip_quotes "${BASH_REMATCH[1]}")"
  else
    inspect_dir="$(last_cd_before "$moff")"
  fi
  if [[ "$seg" =~ --git-dir[=[:space:]]([^[:space:]]+) ]]; then
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

  # Fail open for this invocation: not a repo, or a lookup failed.
  [[ -n "$gd" && -n "$gcd" ]] || continue

  # Primary checkout (git-dir == git-common-dir) with a mutating verb and no
  # sanction marker: deny the whole command.
  if [[ "$gd" == "$gcd" ]]; then
    emit_deny
    exit 0
  fi
done < <(grep -boP "$verb_re" <<<"$cmd" || true)

exit 0
