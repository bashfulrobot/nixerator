# hack: AI-powered worktree workflow for quick tasks

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: hack \"<description>\""
  info "Creates an isolated git worktree and launches Claude for a quick task."
  info ""
  info "Workflow:"
  info "  1. Creates a worktree at ../.worktrees/hack-<slug>/"
  info "  2. Launches Claude Code in the worktree"
  info "  3. Shows diff via gum pager for review"
  info "  4. On approve: fast-forward merges to default branch and removes worktree"
  info "  5. On reject: preserves worktree and prints resume command"
  exit 0
fi

if [[ $# -lt 1 ]]; then
  die "usage: hack \"<description>\""
fi

DESCRIPTION="$1"

# ── Helper functions ──────────────────────────────────────────────────────────

create_hack_state() {
  local branch="$1"
  local wt_path="$2"
  local description="$3"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local json
  json="$(jq -n \
    --arg type        "hack" \
    --arg phase       "setup" \
    --arg branch      "$branch" \
    --arg wt_path     "$wt_path" \
    --arg session_id  "" \
    --arg description "$description" \
    --arg started_at  "$timestamp" \
    --arg updated_at  "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path,
      session_id: $session_id, description: $description,
      started_at: $started_at, updated_at: $updated_at}')"
  write_state "$json" "$wt_path"
}

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

remove_worktree() {
  local wt_path="$1"
  _WT_CLEANUP_PATH=""
  local branch
  branch="$(read_state_field branch "$wt_path" 2>/dev/null || echo "")"
  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true
  if [[ -n "$branch" ]]; then
    git branch -D "$branch" 2>/dev/null || true
  fi
  ok "worktree removed"
}

handle_existing_worktree() {
  local description="$1"
  local wt_path="$2"

  if [[ ! -f "${wt_path}/.worktree-state.json" ]]; then
    die "worktree exists but no state file found at ${wt_path}/.worktree-state.json"
  fi

  local phase branch
  phase="$(read_state_field phase "$wt_path")"
  branch="$(read_state_field branch "$wt_path")"

  info "hack: phase ${phase}, branch ${branch}"

  local choice
  choice="$(gum choose "Resume" "Remove & restart" "Abort" || die "aborted")"

  case "$choice" in
    "Resume")
      phase_resume "$description" "$wt_path" "$phase"
      ;;
    "Remove & restart")
      remove_worktree "$wt_path"
      main "$description"
      ;;
    "Abort")
      info "aborted"
      exit 0
      ;;
  esac
}

phase_resume() {
  local description="$1"
  local wt_path="$2"
  local current_phase="$3"

  local start=0
  case "$current_phase" in
    setup)          start=1 ;;
    claude_running) start=1 ;;
    claude_exited)  start=2 ;;
    diff_review)    start=2 ;;
    merged|cleanup_done)
      ok "already merged"
      return ;;
    *) die "unknown phase: $current_phase" ;;
  esac

  register_cleanup "$wt_path"

  if [[ $start -le 1 ]]; then phase_claude_running "$wt_path"; fi
  if [[ $start -le 2 ]]; then phase_claude_exited "$wt_path"; fi
  phase_diff_review "$wt_path"

  # Disable cleanup trap on successful resume completion
  _WT_CLEANUP_PATH=""
}

# ── Phase functions ───────────────────────────────────────────────────────────

phase_setup() {
  local description="$1"
  local slug="$2"
  local wt_path="$3"

  section "Setup"

  local branch_name="hack/${slug}"
  ok "branch: ${branch_name}"

  info "creating worktree..."
  mkdir -p "$(dirname "$wt_path")"
  git worktree add "$wt_path" -b "$branch_name"
  ok "worktree created at ${wt_path}"

  register_cleanup "$wt_path"

  unlock_git_crypt "$wt_path"

  info "writing state file..."
  create_hack_state "$branch_name" "$wt_path" "$description"
  ok "state file written"

  # Disable cleanup trap -- worktree must survive interruption so user can resume
  _WT_CLEANUP_PATH=""

  set_phase "claude_running" "$wt_path"
  ok "setup complete"
}

phase_claude_running() {
  local wt_path="$1"

  section "Launching Claude"

  local skill_path="$HOME/.claude/skills/github-issue/SKILL.md"
  local description
  description="$(read_state_field description "$wt_path")"
  local branch
  branch="$(read_state_field branch "$wt_path")"

  local skill_content=""
  if [[ -f "$skill_path" ]]; then
    skill_content="$(cat "$skill_path")"
    ok "loaded SKILL.md"
  else
    warn "SKILL.md not found at ${skill_path}"
  fi

  local prompt
  prompt="$(printf 'You are working in worktree %s on branch %s.\n\nTask: %s\n\n%s' \
    "$wt_path" "$branch" "$description" "$skill_content")"

  # Check for existing session_id (resume path)
  local session_id
  session_id="$(read_state_field session_id "$wt_path")"

  local resume_flags=""
  if [[ -n "$session_id" ]]; then
    resume_flags="--resume $session_id"
    info "resuming session: ${session_id}"
  fi

  info "launching claude..."

  # Launch claude in subshell: unset CLAUDECODE to prevent nested session refusal
  (
    cd "$wt_path"
    unset CLAUDECODE
    # shellcheck disable=SC2086
    claude --dangerously-skip-permissions \
      --output-format stream-json \
      -p "$prompt" \
      $resume_flags \
      2>/dev/null \
    | tee /dev/stderr \
    | jq -r 'select(.type == "system") | .session_id // .sessionId // empty' \
    | head -1 > "/tmp/wf-session-id-$$"
  ) || true

  # Write captured session_id to state
  local captured_id
  captured_id="$(cat "/tmp/wf-session-id-$$" 2>/dev/null || echo "")"
  rm -f "/tmp/wf-session-id-$$"

  if [[ -n "$captured_id" ]]; then
    local current updated timestamp
    current="$(cat "${wt_path}/.worktree-state.json")"
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    updated="$(printf '%s' "$current" | jq \
      --arg sid "$captured_id" \
      --arg t "$timestamp" \
      '.session_id = $sid | .updated_at = $t')"
    write_state "$updated" "$wt_path"
    ok "session id captured"
  fi

  set_phase "claude_exited" "$wt_path"
  ok "claude session ended"
}

phase_claude_exited() {
  local wt_path="$1"

  section "Checking Changes"

  # Exclude .worktree-state.json from porcelain check (it's always present and untracked)
  local porcelain
  porcelain="$(git -C "$wt_path" status --porcelain | grep -v '^?? \.worktree-state\.json$' || true)"
  if git -C "$wt_path" diff --quiet HEAD && [[ -z "$porcelain" ]]; then
    warn "no changes detected -- nothing to review"
    exit 0
  fi

  ok "changes detected"
  set_phase "diff_review" "$wt_path"
}

phase_diff_review() {
  local wt_path="$1"

  section "Diff Review"

  local branch description default_br
  branch="$(read_state_field branch "$wt_path")"
  description="$(read_state_field description "$wt_path")"
  default_br="$(default_branch)"

  info "showing diff against ${default_br}..."
  git -C "$wt_path" diff --color=always "${default_br}...${branch}" | gum pager

  if gum confirm "Merge to ${default_br}?"; then
    phase_merge "$wt_path" "$branch" "$default_br"
  else
    # Reject path: preserve worktree, print resume hint, exit cleanly
    _WT_CLEANUP_PATH=""
    warn "merge rejected -- worktree preserved at ${wt_path}"
    info "resume: hack \"${description}\""
    exit 0
  fi
}

phase_merge() {
  local wt_path="$1"
  local branch="$2"
  local default_br="$3"

  section "Merging"

  local repo_root
  repo_root="$(git -C "$wt_path" rev-parse --show-toplevel)"

  cd "$repo_root"
  git checkout "$default_br"

  # Disable cleanup trap before intentional removal
  _WT_CLEANUP_PATH=""

  if ! git merge --ff-only "$branch"; then
    warn "fast-forward merge failed"
    warn "worktree preserved at ${wt_path} for manual resolution"
    exit 1
  fi
  ok "merged"

  # WT-05 cleanup: remove worktree, prune, delete branch
  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true
  ok "worktree removed"

  git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
  ok "branch deleted"

  set_phase "cleanup_done" "$wt_path" 2>/dev/null || true
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  local description="$1"
  local slug
  slug="$(slugify "$description")"
  local wt_path
  wt_path="$(worktree_base)/hack-${slug}"

  assert_clean_tree
  check_orphan_worktrees

  if [[ -d "$wt_path" ]]; then
    handle_existing_worktree "$description" "$wt_path"
    exit 0
  fi

  phase_setup "$description" "$slug" "$wt_path"
  phase_claude_running "$wt_path"
  phase_claude_exited "$wt_path"
  phase_diff_review "$wt_path"

  # Approve path completes inline via phase_merge; cleanup already done
  _WT_CLEANUP_PATH=""
  ok "done!"
}

main "$DESCRIPTION"
