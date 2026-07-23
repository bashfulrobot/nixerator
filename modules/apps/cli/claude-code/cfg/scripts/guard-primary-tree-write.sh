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
# merge, rebase, revert, cherry-pick, am, apply, add, rm, mv, clean. revert/am
# are commit-creating siblings of cherry-pick, and apply writes the working
# tree; a read-only `apply --check`/`--stat` is denied too, which is a safe
# annoyance (use a worktree or the marker). Not blanket read-only: git pull,
# git branch, git checkout/restore, and gh are intentionally NOT matched, so
# the SessionStart git-sync and the git-cleanup flow keep working.
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
# guard, which is itself bypassable through plumbing. The marker frees only the
# single git invocation it directly leads, checked per invocation, so a marked
# read cannot free a later unmarked primary write in the same command; the
# sanctioned flow issues one marked write per Bash call anyway.
#
# Fails open on ambiguity: only a positive primary-tree match denies. If the
# target working tree cannot be resolved, the path is not a repo, or git errors,
# the command proceeds. The verb match is anchored to a command position (start
# of the line, right after a `; & | ( ) { ` or backtick, or after a compound head
# like if/while), so a git verb merely quoted or echoed in prose
# (`echo git commit`) never trips it. Mirrors guard-git-stash.sh.
#
# A PreToolUse "deny" can never be overridden by another hook's "allow", so this
# composes safely with the /auto auto-gate (auto-gate.sh) and the stash guard.
#
# wired into settings.json PreToolUse at activation (cfg/activation.nix),
# stripped on capture (cfg/fish.nix).

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

# The sanctioned override (a `CLAUDE_SANCTIONED_GIT=1 git ...` prefix) is NOT
# handled here as a whole-command short-circuit. That would let a marked read
# free a later unmarked primary write in the same command
# (`CLAUDE_SANCTIONED_GIT=1 git status && git -C <primary> commit`). It is
# checked per verb-bearing invocation in the loop below, so the marker frees
# only the single git write it directly leads, matching what /commit emits (one
# marked write per Bash call).

# Match a mutating git subcommand at a command position. The leading class is the
# command-boundary set (start of string, or right after a metacharacter that
# opens a new simple command: ; & | ( ) ` or {), NOT a bare space, so a git verb
# sitting inside prose or a quoted argument does not match. `&&` and `||` are
# covered because the second `&`/`|` is itself a boundary char; `)` covers a
# `case` pattern body. Between the boundary and git, git_lead consumes what can
# sit in front of the command word: env-assignment prefixes (FOO=bar, including
# GIT_AUTHOR_DATE=...), the plain wrappers (env/sudo/time/nice/nohup/command/exec/
# xargs), the compound-command heads (if/then/elif/else/while/until/do), and the
# arg-taking wrappers timeout/stdbuf with their option and duration tokens, so
# `if git ... commit`, `command git commit`, `timeout 5 git commit`, and a
# backdated or wrapped write are all still caught. An optional leading backslash
# catches `\git` (the alias-bypassing form). Then allow `git -C <dir>` /
# `git -c k=v` / `git --git-dir=<d>` option prefixes and a quoted subcommand.
# A git write hidden inside an `eval "..."` string or a here-doc body is not
# modelled (it needs nested-command parsing); that residual fails open under the
# cooperative single-user model.
git_verb='(commit|push|reset|merge|rebase|revert|cherry-pick|am|apply|add|rm|mv|clean)'
git_lead='(([A-Za-z_][A-Za-z0-9_]*=\S+|sudo|env|time|nice|nohup|command|exec|xargs|if|then|elif|else|while|until|do)\s+|(timeout|stdbuf)(\s+(-{1,2}\S+|[0-9]\S*))*\s+)*'
verb_re="(^|[;&|()\`{])\s*${git_lead}\\\\?git(\s+-\S+(\s+[^-]\S*)?)*\s+[\"']?${git_verb}\b"

# Per-invocation sanction marker: the marker must lead the segment (after an
# optional boundary char), immediately before git. Kept in a single-quoted
# variable so the literal backtick in the boundary class does not open a command
# substitution inside `[[ =~ ]]`.
marker_re='^[;&|()`{]?[[:space:]]*CLAUDE_SANCTIONED_GIT=1[[:space:]]+git([[:space:]]|$)'

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
      permissionDecisionReason: "This is the shared primary checkout, which is read-only for agent task work (epic #252 invariant 1). A commit/push/reset/merge/rebase/revert/cherry-pick/am/apply/add/rm/mv/clean here can clobber another live session. Isolate the work in a linked worktree (github-issue setup <N>, or git worktree add) and run the git command there. If the user explicitly directed this primary-tree write, the sanctioned /commit flow carries the CLAUDE_SANCTIONED_GIT=1 marker that allows it."
    }
  }'
}

# A bare git verb (one that names no repo of its own) runs in whatever tree the
# shell's cwd points at when it executes. Rather than guess from the nearest
# textual `cd`, collect every navigation event with its byte offset and REPLAY
# them left to right up to each verb, so the resolved cwd matches real execution
# order for cd, pushd/popd (a directory stack), and subshells (a `( ... )` group
# whose cwd change is discarded at the closing `)`). This gets both mirror forms
# right: `cd <primary> && (cd <wt> && ...) && git commit` denies (the subshell cd
# is discarded at `)` before the commit), and `cd <wt> && (cd <primary> && git
# commit)` denies (the commit sits inside the group where the primary cd is live).
#
# Events: OPEN `(` / CLOSE `)` for subshell scope, CD/PUSH with a target dir, POP.
# Leading cd/pushd options (`-P`, `-L`, `--`) are skipped so the path, not the
# flag, is captured. Any `(`/`)` counts as a subshell boundary, which also treats
# `$(...)` command substitution as a scope (correct: a cd there does not escape
# either). Residual limits, from space-delimited, non-shell-quote-aware
# tokenisation:
#   - A `(` or `)` inside a quoted string is still counted as a scope boundary.
#     So quoted parens bracketing a real `cd <primary>` (for example
#     `echo "(" && cd <primary> && echo ")" && git commit`) discard that cd at
#     the fake CLOSE and resolve to the hook's own cwd. When the agent already
#     sits in the primary that fallback is the primary and still DENIES
#     (fail-safe); only from a non-primary cwd does it wrongly allow, and it
#     needs balanced literal parens straddling the cd, which no ordinary command
#     emits by accident.
#   - A `cd`/`git -C` argument quoted with an embedded space is not resolved;
#     the invocation falls through to fail open.
cd_re='(cd|pushd)([[:space:]]+-[^[:space:];&|]+)*[[:space:]]+([^[:space:];&|]+)'
nav_offsets=()
nav_types=()
nav_dirs=()
add_nav() {
  nav_offsets+=("$1")
  nav_types+=("$2")
  nav_dirs+=("${3:-}")
}
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  off="${line%%:*}"
  m="${line#*:}"
  if [[ "$m" =~ $cd_re ]]; then
    if [[ "${BASH_REMATCH[1]}" == pushd ]]; then
      add_nav "$off" PUSH "$(strip_quotes "${BASH_REMATCH[3]}")"
    else
      add_nav "$off" CD "$(strip_quotes "${BASH_REMATCH[3]}")"
    fi
  fi
done < <(grep -boP "(^|[;&|(])[[:space:]]*${cd_re}" <<<"$cmd" || true)
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  add_nav "${line%%:*}" POP
done < <(grep -boP '(^|[;&|(])[[:space:]]*popd\b' <<<"$cmd" || true)
while IFS= read -r line; do [[ -n "$line" ]] || continue; add_nav "${line%%:*}" OPEN; done < <(grep -boP '\(' <<<"$cmd" || true)
while IFS= read -r line; do [[ -n "$line" ]] || continue; add_nav "${line%%:*}" CLOSE; done < <(grep -boP '\)' <<<"$cmd" || true)

# Sort priority at an equal offset: OPEN before CD/PUSH/POP before CLOSE. The
# cd-event offset points at the `(` boundary for a subshell-leading cd, so it
# ties with that `(`'s OPEN; OPEN must win so the scope is entered before the cd
# runs inside it.
nav_prio() { case "$1" in OPEN) printf 0 ;; CLOSE) printf 2 ;; *) printf 1 ;; esac; }

# Replay all navigation events with offset < $1 in (offset, priority) order and
# print the resolved cwd (empty means the hook's own cwd).
cwd_at() {
  local target="$1" cwd="" i order
  local -a pstack=() sstack=()
  # The for-loop's own exit status is non-zero whenever the last-indexed event is
  # at or past target (common: any `)` after the verb), which pipefail propagates.
  # `|| true` keeps that expected non-zero from aborting under errexit regardless
  # of how cwd_at is called; the pipeline's stdout (the sorted indices) is intact.
  order="$(for i in "${!nav_offsets[@]}"; do
    ((nav_offsets[i] < target)) && printf '%s %s %s\n' "${nav_offsets[i]}" "$(nav_prio "${nav_types[i]}")" "$i"
  done | sort -n -k1,1 -k2,2 | cut -d' ' -f3)" || true
  while IFS= read -r i; do
    [[ -n "$i" ]] || continue
    case "${nav_types[i]}" in
      OPEN) sstack+=("$cwd") ;;
      CLOSE) ((${#sstack[@]})) && { cwd="${sstack[-1]}"; unset 'sstack[-1]'; } ;;
      CD) cwd="${nav_dirs[i]}" ;;
      PUSH)
        pstack+=("$cwd")
        cwd="${nav_dirs[i]}"
        ;;
      POP) ((${#pstack[@]})) && { cwd="${pstack[-1]}"; unset 'pstack[-1]'; } ;;
    esac
  done <<<"$order"
  printf '%s' "$cwd"
}

# Resolve the working tree PER verb-bearing git invocation, not once for the
# whole line, so a compound that mixes trees (git -C <worktree> ... && git commit
# in the primary cwd) is judged on the invocation that actually carries the
# mutating verb. Deny as soon as any such invocation resolves to the primary
# checkout. The invocation's own repo targeting (`git -C`, `--work-tree`,
# `--git-dir`, applied cumulatively as git does) layers on top of the replayed
# cwd at that offset, which sits on top of the hook cwd. Fail open per
# invocation: a git error (not a repo) skips it. If nothing matches a mutating
# verb, the loop runs zero times, and the command is allowed.
while IFS= read -r match; do
  [[ -n "$match" ]] || continue
  moff="${match%%:*}"
  seg="${match#*:}"

  # Per-invocation sanctioned override: skip only the write the marker directly
  # leads. The marker must sit right before git (allowing the leading boundary
  # char), the form /commit emits. It is not honoured from a later `-c k=v`
  # value or the commit message, both of which come after the verb and so are
  # outside this segment, which prevents smuggling the marker through an option.
  if [[ "$seg" =~ $marker_re ]]; then
    continue
  fi

  # Base dir is the shell cwd replayed to this offset (empty = hook cwd). git
  # applies every -C cumulatively, each relative to the previous, and --work-tree
  # / --git-dir on top, so collect all of them from the segment IN ORDER and hand
  # them to our own rev-parse. git then resolves exactly as the real command
  # would, including a later -C that overrides an earlier one.
  git_args=()
  base_cwd="$(cwd_at "$moff")"
  [[ -n "$base_cwd" ]] && git_args+=(-C "$base_cwd")
  while IFS= read -r flag; do
    [[ -n "$flag" ]] || continue
    case "$flag" in
      -C*) d="${flag#-C}" ;;
      --work-tree*) d="${flag#--work-tree}" ;;
      --git-dir*) d="${flag#--git-dir}" ;;
      *) continue ;;
    esac
    d="${d#[=[:space:]]}"
    d="${d#"${d%%[![:space:]]*}"}"
    d="$(strip_quotes "$d")"
    [[ -n "$d" ]] || continue
    case "$flag" in
      -C*) git_args+=(-C "$d") ;;
      --work-tree*) git_args+=(--work-tree "$d") ;;
      --git-dir*) git_args+=(--git-dir "$d") ;;
    esac
  done < <(grep -oP '(-C[[:space:]]+[^[:space:]]+|--work-tree[=[:space:]][^[:space:]]+|--git-dir[=[:space:]][^[:space:]]+)' <<<"$seg" || true)

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
