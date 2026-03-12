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
# Expects worktree created with --no-checkout. Handles git-crypt repos by
# bypassing the smudge filter during checkout, then unlocking to decrypt.

checkout_and_unlock() {
  local wt_path="$1"

  # Derive repo name from remote URL to find git-crypt key
  local repo_name
  repo_name="$(git -C "$wt_path" remote get-url origin 2>/dev/null | sed 's|.*/||; s|\.git$||')"
  local key="$HOME/.ssh/${repo_name}-git-crypt-key"

  if [[ -n "$repo_name" ]] && [[ -f "$key" ]]; then
    # git-crypt repo: bypass smudge filter, checkout encrypted blobs, then unlock
    info "checking out files (pre-decrypt)..."
    git -C "$wt_path" config filter.git-crypt.smudge cat
    git -C "$wt_path" config filter.git-crypt.clean cat
    git -C "$wt_path" config filter.git-crypt.required false
    git -C "$wt_path" checkout
    ok "checkout complete"

    info "unlocking git-crypt..."
    git -C "$wt_path" crypt unlock "$key"
    git -C "$wt_path" crypt status >/dev/null 2>&1 || die "git-crypt unlock verification failed"
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
  git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'
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
# Uses coreutils (tr, sed) -- POSIX-compatible, no GNU extensions required
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

# ── gum confirm usage pattern (SF-04) ────────────────────────────────────────
# IMPORTANT: Always wrap gum confirm in an if statement -- never use bare.
# Correct:   if gum confirm "Do the thing?"; then ...; else ...; fi
# Wrong:     gum confirm "Do the thing?"   (bare call fails under set -e)
