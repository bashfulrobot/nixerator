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
# Worktrees are the source of truth. Every row is a real worktree on disk; the
# tool never invents rows from leftover lock files (a stale `.setup-issue-N.lock`
# is not evidence of anything -- its producer historically never removed it, so
# it is ignored here; producer-side lock cleanup lives elsewhere).
#
# Row kinds:
#   worktree   a task worktree with a derivable issue number.
#   untracked  a healthy worktree whose branch carries no issue number (a
#              slug-only branch like `feat/arr-declarative-config`). This is a
#              benign, first-class state, not an error -- it is groundwork for
#              an issue-less sister workflow. Rendered as a normal row.
#
# Flags:
#   ORPHAN  a worktree whose referenced issue is CLOSED on the forge -- there
#           is no open issue backing it. (A numbered issue the forge cannot be
#           read for -- 404, transport, or auth -- degrades to issue state
#           "unknown", never a false orphan: `forge` reports not-found and a
#           network blip with the same non-zero exit, so we do not guess.)
#   STALE   a worktree whose issue is claimed by a DIFFERENT host, read from the
#           issue's `<!-- worktree-flow:claim -->` comments (worktree-flow's
#           issue-side lease). Re-attaching here would collide with that host.
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
#   --no-remote   Skip forge lookups (offline / fast). Issue state shows as
#                 "unknown"; neither the closed-issue orphan flag nor the
#                 foreign-host stale flag is evaluated.
#   -h, --help    Show this help.
#
# Read-only: this tool never creates, edits, or removes a worktree, branch,
# issue, or state file. It runs `git status`/`git rev-list`/`git remote` and
# `forge issue-json`/`forge issue-comments-json` (all read-only) plus
# `jq`/`find`. It does not fetch, so ahead/behind is computed against local
# remote-tracking refs.
#
# Host awareness: worktrees can span more than one git host (GitHub and a
# self-hosted Forgejo). `forge` detects the host from each repo's origin
# remote, so every forge call runs with the current directory inside that
# specific worktree. A repo on neither host, or a failed lookup, degrades to
# issue state "unknown" for that row -- the listing never crashes.

set -uo pipefail

# ── help ──────────────────────────────────────────────────────────────────────
# Print the leading comment header (everything from line 2 up to the first
# non-comment line), stripped of the leading "# ". Robust to header length.
show_help() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
}

# ── args ──────────────────────────────────────────────────────────────────────
ROOT="${WORKTREE_ROOT:-$HOME/git/.worktrees}"
JSON=0
REMOTE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="${2:?--root needs a path}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --no-remote) REMOTE=0; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; show_help >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "fleet-status: jq is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "fleet-status: git is required" >&2; exit 1; }

# Local host name. `uname -n` matches worktree-flow's issue-side lease
# convention (github-issue.sh uses `uname -n` for the claiming host), so the
# foreign-host comparison below is apples to apples.
LOCALHOST="$(uname -n 2>/dev/null || printf '%s' "${HOSTNAME:-unknown}")"
HAVE_FORGE=0
if command -v forge >/dev/null 2>&1; then HAVE_FORGE=1; fi

# Marker worktree-flow stamps on a live claim comment (github-issue.sh
# CLAIM_MARKER). A ceded claim carries a distinct cede marker instead, so
# filtering to this marker already excludes cedes during winner selection.
CLAIM_MARKER='<!-- worktree-flow:claim -->'

# ── colors (human mode, TTY only) ─────────────────────────────────────────────
if [[ $JSON -eq 0 && -t 1 ]]; then
  C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RED=$'\033[0;31m'
  C_YEL=$'\033[1;33m'; C_GRN=$'\033[0;32m'; C_CYA=$'\033[0;36m'; C_NC=$'\033[0m'
else
  C_DIM=''; C_BOLD=''; C_RED=''; C_YEL=''; C_GRN=''; C_CYA=''; C_NC=''
fi

# ── sanitize display fields for the TTY ───────────────────────────────────────
# State-file values (branch, note, step, owner, reasons) can carry ESC/OSC
# bytes. Strip control chars before printing to a terminal; keep tab, LF, CR.
# The --json path is NOT sanitized -- JSON encodes control chars safely.
san() { LC_ALL=C tr -d '\000-\010\013\014\016-\037'; }

# ── derive an issue number from a branch/dir string ───────────────────────────
# Handles: issue-251, feat/251, feat/251-slug, 251-fix, and a bare 251.
# Prints the number, or nothing when the string carries no leading issue number.
derive_issue() {
  local s="$1"
  if [[ "$s" =~ ^issue-([0-9]+) ]]; then printf '%s' "${BASH_REMATCH[1]}"; return; fi
  # Case-insensitive type prefix so uppercase/mixed-case branches (FEAT/9,
  # Fix/12) still resolve the number, matching worktree-flow's slug rules.
  if [[ "$s" =~ ^[A-Za-z]+/([0-9]+) ]]; then printf '%s' "${BASH_REMATCH[1]}"; return; fi
  if [[ "$s" =~ ^([0-9]+) ]]; then printf '%s' "${BASH_REMATCH[1]}"; return; fi
  printf ''
}

# ── default branch of a worktree (fallback when base_ref absent) ──────────────
default_branch_for() {
  local wt="$1" ref
  ref="$(git -C "$wt" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)" && {
    printf 'origin/%s' "${ref#refs/remotes/origin/}"; return
  }
  local cand
  for cand in main master; do
    if git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/${cand}" 2>/dev/null; then
      printf 'origin/%s' "$cand"; return
    fi
  done
  printf 'origin/main'
}

# ── query the forge for an issue's state (uppercased) ─────────────────────────
# Runs with cwd inside the worktree so `forge` picks the right host. Prints
# OPEN / CLOSED, or "unknown" on any failure (missing forge, unsupported host,
# network error, issue not found). `forge` cannot distinguish a 404 from a
# transport/auth error -- both surface the same non-zero exit -- so a numbered
# issue that cannot be read stays "unknown" rather than a false orphan.
forge_issue_state() {
  local wt="$1" num="$2" out
  [[ $REMOTE -eq 1 && $HAVE_FORGE -eq 1 && "$num" =~ ^[0-9]+$ ]] || { printf 'unknown'; return; }
  out="$(cd "$wt" && forge issue-json "$num" 2>/dev/null)" || { printf 'unknown'; return; }
  local st
  st="$(printf '%s' "$out" | jq -r '.state // empty' 2>/dev/null)" || st=""
  [[ -n "$st" ]] || { printf 'unknown'; return; }
  printf '%s' "$st" | tr '[:lower:]' '[:upper:]'
}

# ── claim owner from the issue's lease comments (worktree-flow #249) ───────────
# worktree-flow records a per-agent claim as an ISSUE COMMENT stamped with
# CLAIM_MARKER and body lines `claim-id:`, `host:`, `worktree:`, ...; a ceded
# claim carries a distinct cede marker instead. The winner is the claim comment
# with the LOWEST comment id (server-assigned, monotonic), so every host reads
# the same winner. This mirrors the canonical resolver in worktree-flow's
# github-issue.sh (`{id,body}` then `sort_by(.id) | .[0]`).
#
# `forge issue-comments-json <N>` (provider-neutral, added in #255) returns a
# JSON array of {id, body}. Order is NOT guaranteed, so WE sort by id here
# rather than trusting stream order. The winning host is extracted from THAT one
# comment's own body with a line-anchored `host:` capture -- no cross-comment
# bleed, no stateful stream parser. A comment that merely quotes or mentions the
# marker without a real anchored `host:` line yields no host and degrades to the
# local host rather than mis-attributing a bled/decoy value.
#
# Graceful degradation: the verb ships in #255 and is absent on older forge
# builds. A missing/erroring/empty/invalid-JSON result yields the empty string,
# and the caller then defaults the owner to the local host (no crash, no false
# stale). Same for any forge failure or an issue with no claim comment.
claim_owner_for() {
  local wt="$1" num="$2" out host
  [[ $REMOTE -eq 1 && $HAVE_FORGE -eq 1 && "$num" =~ ^[0-9]+$ ]] || { printf ''; return; }
  out="$(cd "$wt" && forge issue-comments-json "$num" 2>/dev/null)" || { printf ''; return; }
  [[ -n "$out" ]] || { printf ''; return; }
  # jq: keep only claim-marker comments (excludes cedes), sort by id, take the
  # lowest, and pull `host:` from that single body. `(?m)` anchors `^` to line
  # starts; leading whitespace and extra spaces after the colon are tolerated
  # and trailing whitespace is stripped. Invalid JSON makes jq exit non-zero ->
  # empty -> local-host default in the caller.
  host="$(printf '%s' "$out" | jq -r --arg m "$CLAIM_MARKER" '
    ([ .[] | select((.body // "") | contains($m)) ] | sort_by(.id) | .[0].body // "")
    | (capture("(?m)^[ \t]*host:[ \t]*(?<h>[^\n]*)") // {h:""} | .h | sub("[ \t]+$";""))
  ' 2>/dev/null)" || { printf ''; return; }
  printf '%s' "$host"
}

# ── collect rows as NDJSON, then render ───────────────────────────────────────
rows_json=""
emit_row() { rows_json+="$1"$'\n'; }

scan_worktree() {
  local wt="$1" repo="$2"
  local state_file="${wt}/.worktree-state.json"

  local issue="" branch="" step="" note="" itype=""
  if [[ -f "$state_file" ]]; then
    issue="$(jq -r '.issue_number // empty' "$state_file" 2>/dev/null)"
    branch="$(jq -r '.branch // empty' "$state_file" 2>/dev/null)"
    step="$(jq -r '.workflow_step // empty' "$state_file" 2>/dev/null)"
    note="$(jq -r '.step_history[-1].note // empty' "$state_file" 2>/dev/null)"
    itype="$(jq -r '.type // empty' "$state_file" 2>/dev/null)"
  fi

  # Branch fallback for state-less worktrees.
  if [[ -z "$branch" ]]; then
    branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  fi
  # Derive an issue number from the branch, then the dir, when the state file
  # carries none.
  if [[ -z "$issue" ]]; then
    issue="$(derive_issue "$branch")"
    [[ -z "$issue" ]] && issue="$(derive_issue "$(basename "$wt")")"
  fi
  # Numeric-guard: only a bare integer is a usable issue number for forge/git.
  # A non-numeric value (injected or malformed) is treated as no issue number.
  [[ "$issue" =~ ^[0-9]+$ ]] || issue=""

  # git signals (read-only, no fetch).
  local dirty ahead="?" behind="?" base_ref counts
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [[ -n "$dirty" ]] || dirty=0
  base_ref="$(jq -r '.base_ref // empty' "$state_file" 2>/dev/null)"
  # Reject an empty or option-like base_ref (a leading '-' would be parsed as a
  # git flag in the "${base_ref}...HEAD" range); fall back to the default branch.
  if [[ -z "$base_ref" || "$base_ref" == -* ]]; then
    base_ref="$(default_branch_for "$wt")"
  fi
  counts="$(git -C "$wt" rev-list --left-right --count "${base_ref}...HEAD" 2>/dev/null || echo "")"
  if [[ -n "$counts" ]]; then
    behind="$(printf '%s' "$counts" | awk '{print $1}')"
    ahead="$(printf '%s' "$counts" | awk '{print $2}')"
  fi

  # Kind + flags.
  local kind="worktree" orphan="false" stale="false" reasons=()
  local istate="unknown" owner="$LOCALHOST"

  if [[ -z "$issue" ]]; then
    # Benign, first-class state: a healthy worktree with no issue number.
    kind="untracked"
  else
    istate="$(forge_issue_state "$wt" "$issue")"
    if [[ "$istate" == "CLOSED" ]]; then
      orphan="true"; reasons+=("issue #${issue} is closed -- no open issue backing this worktree")
    fi
    # Foreign-host claim: worktree-flow's issue-side lease (#249).
    local claim_owner; claim_owner="$(claim_owner_for "$wt" "$issue")"
    if [[ -n "$claim_owner" ]]; then
      owner="$claim_owner"
      if [[ "$claim_owner" != "$LOCALHOST" ]]; then
        stale="true"; reasons+=("claimed by ${claim_owner}, not ${LOCALHOST}")
      fi
    fi
  fi

  local resume=""
  if [[ -n "$issue" ]]; then
    resume="work ${repo}#${issue}"
  else
    # Best-effort resume for an issue-less worktree: drop into it directly.
    resume="cd ${wt}"
  fi

  # JSON schema (see SKILL.md): issue/ahead/behind are numbers or null; dirty is
  # a number; orphan/stale are booleans. "?" never appears in --json output.
  emit_row "$(jq -nc \
    --arg repo "$repo" --arg issue "$issue" --arg branch "$branch" \
    --arg wt "$wt" --arg step "$step" --arg note "$note" --arg itype "$itype" \
    --arg dirty "$dirty" --arg ahead "$ahead" --arg behind "$behind" \
    --arg owner "$owner" --arg istate "$istate" --arg kind "$kind" \
    --arg orphan "$orphan" --arg stale "$stale" --arg resume "$resume" \
    --argjson reasons "$(printf '%s\n' "${reasons[@]:-}" | jq -R . | jq -sc 'map(select(. != ""))')" \
    '{repo:$repo, issue:($issue|tonumber? // null), branch:$branch, worktree:$wt, kind:$kind,
      workflow_step:$step, last_note:$note, type:$itype,
      dirty:($dirty|tonumber), ahead:($ahead|tonumber? // null), behind:($behind|tonumber? // null),
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

# ── render ────────────────────────────────────────────────────────────────────
all_json="$(printf '%s' "$rows_json" | jq -sc 'sort_by(.repo, (.issue // 0))')"

if [[ $JSON -eq 1 ]]; then
  printf '%s\n' "$all_json" | jq .
  exit 0
fi

count="$(printf '%s' "$all_json" | jq 'length')"
printf '%sFleet status%s  %s(host: %s, root: %s)%s\n' \
  "$C_BOLD" "$C_NC" "$C_DIM" "$LOCALHOST" "$ROOT" "$C_NC"
if [[ "$count" -eq 0 ]]; then
  printf '%sNo task worktrees found.%s\n' "$C_DIM" "$C_NC"
  exit 0
fi
printf '%s%d worktree(s)%s\n\n' "$C_DIM" "$count" "$C_NC"

printf '%s' "$all_json" | jq -c '.[]' | while IFS= read -r row; do
  repo="$(jq -r '.repo // empty' <<<"$row" | san)"
  issue="$(jq -r '.issue // empty' <<<"$row")"
  branch="$(jq -r '.branch // empty' <<<"$row" | san)"
  kind="$(jq -r '.kind' <<<"$row")"
  step="$(jq -r '.workflow_step // empty' <<<"$row" | san)"
  note="$(jq -r '.last_note // empty' <<<"$row" | san)"
  dirty="$(jq -r '.dirty' <<<"$row")"
  ahead="$(jq -r '.ahead // "?"' <<<"$row")"
  behind="$(jq -r '.behind // "?"' <<<"$row")"
  owner="$(jq -r '.owner // empty' <<<"$row" | san)"
  istate="$(jq -r '.issue_state' <<<"$row")"
  orphan="$(jq -r '.orphan' <<<"$row")"
  stale="$(jq -r '.stale' <<<"$row")"
  resume="$(jq -r '.resume // empty' <<<"$row")"
  reason_line="$(jq -r '.reasons | join("; ")' <<<"$row" | san)"

  marker="$C_GRN●$C_NC"; flag=""
  [[ "$kind" == "untracked" ]] && { marker="$C_DIM○$C_NC"; flag=" ${C_DIM}[untracked]${C_NC}"; }
  if [[ "$orphan" == "true" ]]; then marker="$C_RED✖$C_NC"; flag=" ${C_RED}[ORPHAN]${C_NC}"; fi
  if [[ "$stale" == "true" ]]; then marker="$C_YEL⚠$C_NC"; flag="${flag} ${C_YEL}[STALE]${C_NC}"; fi

  handle="$repo"
  [[ -n "$issue" ]] && handle="${repo} ${C_CYA}#${issue}${C_NC}"
  printf '%s %s%s%s  %s%s\n' "$marker" "$C_BOLD" "$handle" "$C_NC" "${branch:-(unknown branch)}" "$flag"
  if [[ -n "$step" || -n "$note" ]]; then
    printf '    step: %s%s%s' "$C_BOLD" "${step:-?}" "$C_NC"
    [[ -n "$note" ]] && printf ' %s— %s%s' "$C_DIM" "$note" "$C_NC"
    printf '\n'
  fi
  printf '    git:  %s dirty, %s ahead / %s behind\n' "$dirty" "$ahead" "$behind"
  printf '    issue: %s   owner: %s\n' "$istate" "$owner"
  [[ -n "$reason_line" ]] && printf '    %s%s%s\n' "$C_YEL" "$reason_line" "$C_NC"
  [[ -n "$resume" ]] && printf '    resume: %s%s%s\n' "$C_CYA" "$resume" "$C_NC"
  printf '\n'
done
