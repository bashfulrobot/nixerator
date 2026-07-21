#!/usr/bin/env bash
# fleet-status -- a read-only, worktree-aware resume board.
#
# Walks every task worktree on the machine under the shared worktree root
# (the per-repo namespaced layout <root>/<repo>/<worktree>), reads each
# .worktree-state.json, and for each worktree prints: repo, issue number,
# branch, workflow step (plus the latest step_history note), dirty count,
# ahead/behind vs the branch base, the claim owner, and the exact command to
# resume it -- `work <repo>#<N>`.
#
# It flags:
#   ORPHAN  a worktree (or a .setup-issue-N.lock claim) with no matching open
#           issue -- nothing backing it on the forge.
#   STALE   a claim whose owner is not the current host, or whose issue is
#           closed on the forge.
#
# It generalizes `branch-status` (single branch, current dir) to the whole
# fleet of worktrees across every repo.
#
# Usage:
#   fleet-status.sh [options]
#
# Options:
#   --root PATH   Shared worktree root to scan. Default: $WORKTREE_ROOT, else
#                 $HOME/git/.worktrees.
#   --json        Emit a JSON array instead of the human-readable board.
#   --no-remote   Skip forge issue lookups (offline / fast). Issue state shows
#                 as "unknown"; the closed-issue stale flag is not evaluated.
#   -h, --help    Show this help.
#
# Read-only: this tool never creates, edits, or removes a worktree, branch,
# issue, or state file. It runs `git status`/`git rev-list`/`git remote` and
# `forge issue-json` (all read-only) plus `jq`/`find`. It does not fetch, so
# ahead/behind is computed against local remote-tracking refs.
#
# Host awareness: worktrees can span more than one git host (GitHub and a
# self-hosted Forgejo). `forge` detects the host from each repo's origin
# remote, so every `forge issue-json` runs with the current directory inside
# that specific worktree. A repo on neither host, or a failed lookup, degrades
# to issue state "unknown" for that row -- the listing never crashes.

set -uo pipefail

# ── help ──────────────────────────────────────────────────────────────────────
show_help() { sed -n '2,52p' "$0" | sed 's/^# \{0,1\}//'; }

# ── args ──────────────────────────────────────────────────────────────────────
ROOT="${WORKTREE_ROOT:-$HOME/git/.worktrees}"
JSON=0
REMOTE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --no-remote) REMOTE=0; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; show_help >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "fleet-status: jq is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "fleet-status: git is required" >&2; exit 1; }

HOST="$(hostname 2>/dev/null || printf '%s' "${HOSTNAME:-unknown}")"
HAVE_FORGE=0
if command -v forge >/dev/null 2>&1; then HAVE_FORGE=1; fi

# ── colors (human mode, TTY only) ─────────────────────────────────────────────
if [[ $JSON -eq 0 && -t 1 ]]; then
  C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RED=$'\033[0;31m'
  C_YEL=$'\033[1;33m'; C_GRN=$'\033[0;32m'; C_CYA=$'\033[0;36m'; C_NC=$'\033[0m'
else
  C_DIM=''; C_BOLD=''; C_RED=''; C_YEL=''; C_GRN=''; C_CYA=''; C_NC=''
fi

# ── default branch of a worktree (fallback when base_ref absent) ──────────────
default_branch_for() {
  local wt="$1" ref
  ref="$(git -C "$wt" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)" && {
    printf 'origin/%s' "${ref#refs/remotes/origin/}"; return
  }
  local cand
  for cand in main master; do
    if git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/${cand}"; then
      printf 'origin/%s' "$cand"; return
    fi
  done
  printf 'origin/main'
}

# ── query the forge for an issue's state (uppercased) ─────────────────────────
# Runs with cwd inside the worktree so `forge` picks the right host. Prints
# OPEN / CLOSED, or "unknown" on any failure (missing forge, unsupported host,
# network error, issue not found).
forge_issue_state() {
  local wt="$1" num="$2" out
  [[ $REMOTE -eq 1 && $HAVE_FORGE -eq 1 && -n "$num" ]] || { printf 'unknown'; return; }
  out="$(cd "$wt" && forge issue-json "$num" 2>/dev/null)" || { printf 'unknown'; return; }
  local st
  st="$(printf '%s' "$out" | jq -r '.state // empty' 2>/dev/null)" || st=""
  [[ -n "$st" ]] || { printf 'unknown'; return; }
  printf '%s' "$st" | tr '[:lower:]' '[:upper:]'
}

# ── collect rows as NDJSON, then render ───────────────────────────────────────
rows_json=""
emit_row() { rows_json+="$1"$'\n'; }

# Track which (repo,issue) pairs have a real worktree so leftover lock files
# can be reported as orphan claims.
declare -A claimed_by_worktree=()

scan_worktree() {
  local wt="$1" repo="$2"
  local state_file="${wt}/.worktree-state.json"

  local issue="" branch="" step="" note="" itype="" owner=""
  if [[ -f "$state_file" ]]; then
    issue="$(jq -r '.issue_number // empty' "$state_file" 2>/dev/null)"
    branch="$(jq -r '.branch // empty' "$state_file" 2>/dev/null)"
    step="$(jq -r '.workflow_step // empty' "$state_file" 2>/dev/null)"
    note="$(jq -r '.step_history[-1].note // empty' "$state_file" 2>/dev/null)"
    itype="$(jq -r '.type // empty' "$state_file" 2>/dev/null)"
    # Future-proof for an issue-side lease that records an owning host.
    owner="$(jq -r '.lease.host // .claimed_by // .host // .owner // empty' "$state_file" 2>/dev/null)"
  fi

  # Branch fallback for state-less worktrees.
  if [[ -z "$branch" ]]; then
    branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  fi
  # Derive an issue number from the dir/branch when no state file carries one.
  if [[ -z "$issue" ]]; then
    local base; base="$(basename "$wt")"
    if [[ "$base" =~ ^issue-([0-9]+) ]]; then issue="${BASH_REMATCH[1]}"
    elif [[ "$branch" =~ ^[a-z]+/([0-9]+)- ]]; then issue="${BASH_REMATCH[1]}"; fi
  fi

  # Worktrees are host-local; absent an explicit lease, the owner is this host.
  local owner_display="$owner"
  [[ -z "$owner_display" ]] && owner_display="$HOST"

  # git signals (read-only, no fetch).
  local dirty ahead="?" behind="?" base_ref counts
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [[ -n "$dirty" ]] || dirty=0
  base_ref="$(jq -r '.base_ref // empty' "$state_file" 2>/dev/null)"
  [[ -n "$base_ref" ]] || base_ref="$(default_branch_for "$wt")"
  counts="$(git -C "$wt" rev-list --left-right --count "${base_ref}...HEAD" 2>/dev/null || echo "")"
  if [[ -n "$counts" ]]; then
    behind="$(printf '%s' "$counts" | awk '{print $1}')"
    ahead="$(printf '%s' "$counts" | awk '{print $2}')"
  fi

  # Issue state + flags.
  local istate; istate="$(forge_issue_state "$wt" "$issue")"
  local orphan="false" stale="false" reasons=()
  if [[ -z "$issue" ]]; then
    orphan="true"; reasons+=("no issue number for worktree")
  elif [[ "$istate" == "CLOSED" ]]; then
    stale="true"; reasons+=("issue closed")
  fi
  if [[ -n "$owner" && "$owner" != "$HOST" ]]; then
    stale="true"; reasons+=("claimed by ${owner}, not ${HOST}")
  fi

  [[ -n "$issue" ]] && claimed_by_worktree["${repo}#${issue}"]=1

  local resume=""
  [[ -n "$issue" ]] && resume="work ${repo}#${issue}"

  emit_row "$(jq -nc \
    --arg repo "$repo" --arg issue "$issue" --arg branch "$branch" \
    --arg wt "$wt" --arg step "$step" --arg note "$note" --arg itype "$itype" \
    --arg dirty "$dirty" --arg ahead "$ahead" --arg behind "$behind" \
    --arg owner "$owner_display" --arg istate "$istate" \
    --arg orphan "$orphan" --arg stale "$stale" --arg resume "$resume" \
    --argjson reasons "$(printf '%s\n' "${reasons[@]:-}" | jq -R . | jq -sc 'map(select(. != ""))')" \
    '{repo:$repo, issue:$issue, branch:$branch, worktree:$wt, kind:"worktree",
      workflow_step:$step, last_note:$note, type:$itype,
      dirty:($dirty|tonumber), ahead:$ahead, behind:$behind,
      owner:$owner, issue_state:$istate,
      orphan:($orphan=="true"), stale:($stale=="true"), reasons:$reasons,
      resume:$resume}')"
}

# ── walk the fleet ────────────────────────────────────────────────────────────
if [[ ! -d "$ROOT" ]]; then
  if [[ $JSON -eq 1 ]]; then echo "[]"; else
    printf '%sNo worktree root at %s -- no in-flight task worktrees.%s\n' "$C_DIM" "$ROOT" "$C_NC"
  fi
  exit 0
fi

# Per-repo namespaced dirs hold the worktrees.
while IFS= read -r -d '' repo_dir; do
  repo="$(basename "$repo_dir")"
  # Worktrees are immediate subdirs that are git worktrees.
  while IFS= read -r -d '' wt; do
    [[ -e "${wt}/.git" || -f "${wt}/.worktree-state.json" ]] || continue
    scan_worktree "$wt" "$repo"
  done < <(find "$repo_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
done < <(find "$ROOT" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

# Leftover .setup-issue-N.lock claims with no backing worktree -> orphan claims.
# Repo-namespaced locks (<root>/<repo>/.setup-issue-N.lock) plus legacy
# root-level locks (<root>/.setup-issue-N.lock, repo unknown).
while IFS= read -r -d '' lock; do
  n="$(basename "$lock")"; n="${n#.setup-issue-}"; n="${n%.lock}"
  parent="$(dirname "$lock")"
  if [[ "$parent" == "$ROOT" ]]; then repo="(root)"; else repo="$(basename "$parent")"; fi
  [[ -n "${claimed_by_worktree[${repo}#${n}]:-}" ]] && continue
  resume=""
  [[ "$repo" != "(root)" ]] && resume="work ${repo}#${n}"
  emit_row "$(jq -nc --arg repo "$repo" --arg issue "$n" --arg lock "$lock" --arg resume "$resume" \
    '{repo:$repo, issue:$issue, branch:"", worktree:"", kind:"orphan-claim",
      workflow_step:"", last_note:"", type:"",
      dirty:0, ahead:"?", behind:"?", owner:"", issue_state:"unknown",
      orphan:true, stale:false,
      reasons:["setup lock with no matching worktree"], resume:$resume}')"
done < <(find "$ROOT" -mindepth 1 -maxdepth 2 -name '.setup-issue-*.lock' -print0 2>/dev/null)

# ── render ────────────────────────────────────────────────────────────────────
all_json="$(printf '%s' "$rows_json" | jq -sc 'sort_by(.repo, (.issue|tonumber? // 0))')"

if [[ $JSON -eq 1 ]]; then
  printf '%s\n' "$all_json" | jq .
  exit 0
fi

count="$(printf '%s' "$all_json" | jq 'length')"
printf '%sFleet status%s  %s(host: %s, root: %s)%s\n' \
  "$C_BOLD" "$C_NC" "$C_DIM" "$HOST" "$ROOT" "$C_NC"
if [[ "$count" -eq 0 ]]; then
  printf '%sNo task worktrees found.%s\n' "$C_DIM" "$C_NC"
  exit 0
fi
printf '%s%d worktree(s)/claim(s)%s\n\n' "$C_DIM" "$count" "$C_NC"

printf '%s' "$all_json" | jq -c '.[]' | while IFS= read -r row; do
  repo="$(jq -r '.repo' <<<"$row")"
  issue="$(jq -r '.issue' <<<"$row")"
  branch="$(jq -r '.branch' <<<"$row")"
  kind="$(jq -r '.kind' <<<"$row")"
  step="$(jq -r '.workflow_step' <<<"$row")"
  note="$(jq -r '.last_note' <<<"$row")"
  dirty="$(jq -r '.dirty' <<<"$row")"
  ahead="$(jq -r '.ahead' <<<"$row")"
  behind="$(jq -r '.behind' <<<"$row")"
  owner="$(jq -r '.owner' <<<"$row")"
  istate="$(jq -r '.issue_state' <<<"$row")"
  orphan="$(jq -r '.orphan' <<<"$row")"
  stale="$(jq -r '.stale' <<<"$row")"
  resume="$(jq -r '.resume' <<<"$row")"
  reasons="$(jq -r '.reasons | join("; ")' <<<"$row")"

  marker="$C_GRN●$C_NC"; flag=""
  if [[ "$orphan" == "true" ]]; then marker="$C_RED✖$C_NC"; flag=" ${C_RED}[ORPHAN]${C_NC}"; fi
  if [[ "$stale" == "true" ]]; then marker="$C_YEL⚠$C_NC"; flag="${flag} ${C_YEL}[STALE]${C_NC}"; fi

  handle="$repo"
  [[ -n "$issue" ]] && handle="${repo} ${C_CYA}#${issue}${C_NC}"
  printf '%s %s%s  %s%s\n' "$marker" "$C_BOLD" "$handle" "${branch:-(unknown branch)}" "$flag"
  if [[ "$kind" == "orphan-claim" ]]; then
    printf '    %sclaim lock, no worktree%s\n' "$C_DIM" "$C_NC"
  else
    if [[ -n "$step" || -n "$note" ]]; then
      printf '    step: %s%s%s' "$C_BOLD" "${step:-?}" "$C_NC"
      [[ -n "$note" ]] && printf ' %s— %s%s' "$C_DIM" "$note" "$C_NC"
      printf '\n'
    fi
    printf '    git:  %s dirty, %s ahead / %s behind\n' "$dirty" "$ahead" "$behind"
    printf '    issue: %s   owner: %s\n' "$istate" "$owner"
  fi
  [[ -n "$reasons" ]] && printf '    %s%s%s\n' "$C_YEL" "$reasons" "$C_NC"
  [[ -n "$resume" ]] && printf '    resume: %s%s%s\n' "$C_CYA" "$resume" "$C_NC"
  printf '\n'
done
