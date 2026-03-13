# NOTE: set -euo pipefail injected by writeShellApplication

# ── Colors ────────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

info() { printf '%s▸ %s%s\n'  "$CYAN"   "$*" "$NC";        }
ok()   { printf '%s✔ %s%s\n'  "$GREEN"  "$*" "$NC";        }
warn() { printf '%s⚠ %s%s\n'  "$YELLOW" "$*" "$NC";        }
die()  { printf '%s✖ %s%s\n'  "$RED"    "$*" "$NC" >&2; exit 1; }

# ── Section headers ───────────────────────────────────────────────────────────
section() {
  printf '\n'
  gum style --bold --foreground="6" -- "-- $* --"
  printf '\n'
}

# ── Remote sync ───────────────────────────────────────────────────────────────

fetch_remote() {
  info "fetching latest from remote..."
  git fetch origin --prune 2>/dev/null || warn "fetch failed (offline?)"
}

# ── Safety guards ─────────────────────────────────────────────────────────────

# SF-01: Block pushes to main/master
assert_not_main() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    die "refusing to operate on protected branch '$branch'"
  fi
}

# SF-02: Require clean working tree
assert_clean_tree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree is not clean -- commit or stash first"
  fi
}

# SF-03: Safe push (branch guard + push with tracking)
safe_push() {
  assert_not_main
  git push -u origin "$1"
}

# ── Worktree checkout + git-crypt unlock ──────────────────────────────────────
# Expects worktree created with --no-checkout. For git-crypt repos:
# bypass smudge -> checkout encrypted blobs -> unlock to decrypt.

checkout_and_unlock() {
  local wt_path="$1"

  # Derive repo name from remote URL to find git-crypt key
  local repo_name
  repo_name="$(git -C "$wt_path" remote get-url origin 2>/dev/null | sed 's|.*/||; s|\.git$||')"
  local key="$HOME/.ssh/${repo_name}-git-crypt-key"

  if [[ -n "$repo_name" ]] && [[ -f "$key" ]]; then
    # Worktree inherits main repo's git-crypt smudge filter.
    # Override with pass-through so checkout doesn't attempt decryption
    # (worktree has no git-crypt keys installed yet).
    info "checking out files (pre-decrypt)..."
    git -C "$wt_path" config filter.git-crypt.smudge cat
    git -C "$wt_path" config filter.git-crypt.clean cat
    git -C "$wt_path" config filter.git-crypt.required false
    git -C "$wt_path" checkout
    ok "checkout complete"

    # Unlock git-crypt: installs key, restores proper filters,
    # re-checksout encrypted files through the real smudge filter.
    # Must cd into worktree -- git-crypt has no -C flag and
    # "git -C <path> crypt" doesn't reliably pass context.
    info "unlocking git-crypt..."
    (cd "$wt_path" && git-crypt unlock "$key")
    ok "git-crypt unlocked"
  else
    # No git-crypt: plain checkout
    info "checking out files..."
    git -C "$wt_path" checkout
    ok "checkout complete"
  fi
}

# ── Default branch detection ──────────────────────────────────────────────────
default_branch() {
  local ref
  ref="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)" || {
    # Fallback: try common default branch names
    for candidate in main master; do
      if git show-ref --verify --quiet "refs/remotes/origin/${candidate}"; then
        printf '%s' "$candidate"
        return
      fi
    done
    die "cannot detect default branch -- run: git remote set-head origin --auto"
  }
  printf '%s' "${ref#refs/remotes/origin/}"
}

# ── Atomic state file I/O (WT-04) ─────────────────────────────────────────────

# Write JSON string atomically to .worktree-state.json
# Args: $1=json_string, $2=wt_path
write_state() {
  local json="$1"
  local wt_path="$2"
  local tmpfile
  tmpfile="$(mktemp "${wt_path}/.worktree-state.XXXXXX")"
  printf '%s\n' "$json" > "$tmpfile"
  mv "$tmpfile" "${wt_path}/.worktree-state.json"
}

# Create initial state file
# Args: $1=type (issue/hack), $2=branch, $3=wt_path
create_state() {
  local type="$1"
  local branch="$2"
  local wt_path="$3"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local json
  json="$(jq -n \
    --arg type       "$type" \
    --arg phase      "setup" \
    --arg branch     "$branch" \
    --arg wt_path    "$wt_path" \
    --arg session_id "" \
    --arg started_at "$timestamp" \
    --arg updated_at "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path, session_id: $session_id, started_at: $started_at, updated_at: $updated_at}'
  )"
  write_state "$json" "$wt_path"
}

# Update the phase field atomically
# Args: $1=new_phase, $2=wt_path
set_phase() {
  local new_phase="$1"
  local wt_path="$2"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local current
  current="$(cat "${wt_path}/.worktree-state.json")"
  local updated
  updated="$(printf '%s' "$current" | jq --arg phase "$new_phase" --arg updated_at "$timestamp" '.phase = $phase | .updated_at = $updated_at')"
  write_state "$updated" "$wt_path"
}

# Read a single field from state
# Args: $1=field_name, $2=wt_path
read_state_field() {
  local field="$1"
  local wt_path="$2"
  jq -r ".$field" "${wt_path}/.worktree-state.json"
}

# ── Trap cleanup handler (WT-03) ──────────────────────────────────────────────

# Global path used by cleanup trap -- initialize to empty
_WT_CLEANUP_PATH=""

# Cleanup handler -- called by trap on EXIT/INT/TERM
cleanup() {
  if [[ -n "$_WT_CLEANUP_PATH" && -d "$_WT_CLEANUP_PATH" ]]; then
    warn "cleaning up worktree at $_WT_CLEANUP_PATH..."
    git worktree remove --force "$_WT_CLEANUP_PATH" 2>/dev/null || true
    git worktree prune 2>/dev/null || true
  fi
}

# Register cleanup trap for a worktree path
# Args: $1=wt_path
register_cleanup() {
  _WT_CLEANUP_PATH="$1"
  trap cleanup EXIT INT TERM
}

# ── Slug generation ───────────────────────────────────────────────────────────
# Uses coreutils (tr, sed) + bash case conversion (${var,,})
slugify() {
  local input="$1"
  local lower="${input,,}"
  printf '%s' "$lower" \
    | tr -cs 'a-z0-9' '-' \
    | sed 's/^-*//;s/-*$//' \
    | cut -c1-50
}

# ── Worktree path helper ──────────────────────────────────────────────────────
worktree_base() {
  printf '%s' "$(git rev-parse --show-toplevel)/../.worktrees"
}

# ── Orphan worktree detection ────────────────────────────────────────────────
# Warns about worktree dirs with no state file and offers to remove them.
check_orphan_worktrees() {
  local wt_base
  wt_base="$(worktree_base)"
  [[ -d "$wt_base" ]] || return 0

  local found_orphan=0
  while IFS= read -r -d '' wt_dir; do
    if [[ ! -f "${wt_dir}/.worktree-state.json" ]]; then
      warn "orphan worktree (no state file): $wt_dir"
      found_orphan=1
    fi
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  if [[ $found_orphan -eq 1 ]]; then
    if gum confirm "Remove orphan worktrees?"; then
      while IFS= read -r -d '' wt_dir; do
        if [[ ! -f "${wt_dir}/.worktree-state.json" ]]; then
          git worktree remove --force "$wt_dir" 2>/dev/null || rm -rf "$wt_dir"
        fi
      done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
      git worktree prune 2>/dev/null || true
      ok "orphan worktrees cleaned"
    fi
  fi
}

# ── Worktree removal ────────────────────────────────────────────────────────
remove_worktree() {
  local wt_path="$1"
  _WT_CLEANUP_PATH=""
  local branch
  branch="$(read_state_field branch "$wt_path" 2>/dev/null || echo "")"

  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true
  if [[ -n "$branch" ]]; then
    git branch -D "$branch" 2>/dev/null || true
    git push origin --delete "$branch" 2>/dev/null || true
  fi
  ok "worktree removed"
}

# ── Swept path tracking ─────────────────────────────────────────────────────
# Tracks worktree paths cleaned by sweep so callers can detect when their
# target worktree was just removed (prevents re-creating it as a new worktree).
_SWEPT_PATHS=()

was_swept() {
  local target="$1"
  local p
  for p in "${_SWEPT_PATHS[@]}"; do
    [[ "$p" == "$target" ]] && return 0
  done
  return 1
}

# ── Auto-sweep merged/closed worktrees ───────────────────────────────────────
# Scans all worktrees with state files, checks PR status via gh, and cleans up
# any whose PR has been merged or closed. Runs on every invocation so stale
# worktrees don't accumulate.
# Args: $1=dir_prefix (e.g. "issue-" or "hack-"), defaults to scanning all.
sweep_merged_worktrees() {
  local dir_prefix="${1:-}"
  local wt_base
  wt_base="$(worktree_base)"
  [[ -d "$wt_base" ]] || return 0

  local name_filter="*"
  if [[ -n "$dir_prefix" ]]; then
    name_filter="${dir_prefix}*"
  fi

  local cleaned=0
  local state_file pr_url pr_state wt_type branch issue_num alert_num pr_number
  while IFS= read -r -d '' wt_dir; do
    state_file="${wt_dir}/.worktree-state.json"
    [[ -f "$state_file" ]] || continue

    pr_url="$(jq -r '.pr_url // ""' "$state_file")"
    [[ -n "$pr_url" ]] || continue

    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null)" || {
      warn "could not check PR status for $(basename "$wt_dir"), skipping"
      continue
    }
    if [[ "$pr_state" == "MERGED" ]] || [[ "$pr_state" == "CLOSED" ]]; then
      # Read all state BEFORE removing worktree (state file lives inside it)
      wt_type="$(jq -r '.type' "$state_file")"
      branch="$(jq -r '.branch' "$state_file")"
      pr_number="${pr_url##*/}"
      issue_num=""
      alert_num=""

      if [[ "$wt_type" == "issue" ]]; then
        issue_num="$(jq -r '.issue_number' "$state_file")"
        info "issue #${issue_num}: PR ${pr_state,,}, cleaning up..."
      elif [[ "$wt_type" == "dependabot" ]]; then
        alert_num="$(jq -r '.alert_number' "$state_file")"
        info "alert #${alert_num}: PR ${pr_state,,}, cleaning up..."
      else
        info "$(basename "$wt_dir"): PR ${pr_state,,}, cleaning up..."
      fi

      # Dismiss dependabot alert (before worktree removal destroys state file)
      if [[ "$wt_type" == "dependabot" ]] && [[ -n "$alert_num" ]] && [[ "$alert_num" != "null" ]]; then
        gh api "repos/{owner}/{repo}/dependabot/alerts/${alert_num}" \
          -X PATCH -f state=dismissed -f dismissed_reason=fix_started \
          -f dismissed_comment="Fixed via PR" 2>/dev/null || true
      fi

      # Track this path before removal so callers know it was swept
      _SWEPT_PATHS+=("$wt_dir")

      # Remove worktree
      git worktree remove --force "$wt_dir" 2>/dev/null || rm -rf "$wt_dir"

      # Delete local and remote branches
      git branch -D "$branch" 2>/dev/null || true
      git push origin --delete "$branch" 2>/dev/null || true

      # Post resolution comment and close issue (issue worktrees only, merged PRs)
      if [[ "$wt_type" == "issue" ]] && [[ -n "$pr_number" ]] && [[ -n "$issue_num" ]]; then
        gh issue comment "$issue_num" \
          --body "Resolved via #${pr_number}. Branch and worktree cleaned up." 2>/dev/null || true
        if [[ "$pr_state" == "MERGED" ]]; then
          gh issue close "$issue_num" 2>/dev/null || true
        fi
      fi

      ok "cleaned up $(basename "$wt_dir")"
      cleaned=$((cleaned + 1))
    fi
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name "$name_filter" -print0 2>/dev/null)

  if [[ $cleaned -gt 0 ]]; then
    git worktree prune 2>/dev/null || true
    ok "swept ${cleaned} merged worktree(s)"
  fi
}

# ── Signal-safe Claude launcher ──────────────────────────────────────────────
# Runs Claude in a subshell while protecting the parent script from SIGINT.
# Without this, Ctrl+C or /exit in Claude propagates SIGINT to the parent,
# killing it before post-Claude phases (push, PR creation) can run.
#
# Uses `trap : INT` (no-op command) so the parent survives SIGINT while
# child processes still receive default signal handling. `trap '' INT` would
# cause children to inherit the ignore — that's NOT what we want.
#
# Args: $1=wt_path, remaining args passed to claude
run_claude() {
  local wt_path="$1"
  shift

  # Protect parent from SIGINT/SIGTERM while Claude runs
  trap : INT TERM

  (
    cd "$wt_path"
    unset CLAUDECODE
    claude "$@"
  ) || true

  # Restore signal handling
  trap cleanup EXIT INT TERM
}

# ── gum confirm usage pattern (SF-04) ────────────────────────────────────────
# IMPORTANT: Always wrap gum confirm in an if statement -- never use bare.
# Correct:   if gum confirm "Do the thing?"; then ...; else ...; fi
# Wrong:     gum confirm "Do the thing?"   (bare call fails under set -e)
