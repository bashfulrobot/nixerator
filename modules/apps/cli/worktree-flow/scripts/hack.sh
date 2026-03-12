# hack: AI-powered worktree workflow for quick tasks

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: hack [\"<description>\"]"
  info "Creates an isolated git worktree, launches Claude, and opens a PR."
  info ""
  info "Workflow:"
  info "  hack \"<description>\"  -- new worktree + Claude session + PR"
  info "  hack \"<description>\"  -- resume existing worktree (if slug matches)"
  info "  hack                  -- pick from active hack worktrees"
  exit 0
fi

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
    --arg pr_url      "" \
    --arg description "$description" \
    --arg started_at  "$timestamp" \
    --arg updated_at  "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path,
      session_id: $session_id, pr_url: $pr_url, description: $description,
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

# ── Worktree picker (no-arg mode) ───────────────────────────────────────────

pick_worktree() {
  local wt_base
  wt_base="$(worktree_base)"

  if [[ ! -d "$wt_base" ]]; then
    die "usage: hack \"<description>\""
  fi

  # Collect hack worktrees with state files
  local -a descriptions=()
  local -a paths=()
  while IFS= read -r -d '' wt_dir; do
    local state_file="${wt_dir}/.worktree-state.json"
    if [[ -f "$state_file" ]]; then
      local wt_type
      wt_type="$(jq -r '.type' "$state_file")"
      if [[ "$wt_type" == "hack" ]]; then
        local desc phase pr_url
        desc="$(jq -r '.description' "$state_file")"
        phase="$(jq -r '.phase' "$state_file")"
        pr_url="$(jq -r '.pr_url // ""' "$state_file")"
        local label="${desc} [${phase}]"
        if [[ -n "$pr_url" ]]; then
          label="${desc} [${phase}] ${pr_url}"
        fi
        descriptions+=("$label")
        paths+=("$wt_dir")
      fi
    fi
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name 'hack-*' -print0 2>/dev/null)

  if [[ ${#descriptions[@]} -eq 0 ]]; then
    die "no active hack worktrees. usage: hack \"<description>\""
  fi

  if [[ ${#descriptions[@]} -eq 1 ]]; then
    # Single worktree: go directly
    local desc
    desc="$(jq -r '.description' "${paths[0]}/.worktree-state.json")"
    handle_existing_worktree "$desc" "${paths[0]}"
    return
  fi

  # Multiple: let user pick
  local choice
  choice="$(printf '%s\n' "${descriptions[@]}" | gum choose --header "Active hacks:" || die "aborted")"

  # Find matching path
  local i
  for i in "${!descriptions[@]}"; do
    if [[ "${descriptions[$i]}" == "$choice" ]]; then
      local desc
      desc="$(jq -r '.description' "${paths[$i]}/.worktree-state.json")"
      handle_existing_worktree "$desc" "${paths[$i]}"
      return
    fi
  done
}

# ── Existing worktree handling ───────────────────────────────────────────────

handle_existing_worktree() {
  local description="$1"
  local wt_path="$2"

  if [[ ! -f "${wt_path}/.worktree-state.json" ]]; then
    die "worktree exists but no state file found at ${wt_path}/.worktree-state.json"
  fi

  local phase branch pr_url
  phase="$(read_state_field phase "$wt_path")"
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"

  # Check if PR was merged
  if [[ "$phase" == "pr_created" ]] && [[ -n "$pr_url" ]]; then
    local pr_state
    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")"
    if [[ "$pr_state" == "MERGED" ]]; then
      phase_cleanup "$wt_path"
      return
    fi
  fi

  info "hack: phase ${phase}, branch ${branch}"
  if [[ -n "$pr_url" ]]; then
    info "PR: ${pr_url}"
  fi

  local choice
  choice="$(gum choose "Resume Claude" "Check PR" "Remove" "Abort" || die "aborted")"

  case "$choice" in
    "Resume Claude")
      phase_resume "$wt_path"
      ;;
    "Check PR")
      if [[ -z "$pr_url" ]]; then
        warn "no PR created yet"
      else
        gh pr view "$pr_url" --web 2>/dev/null || info "PR: ${pr_url}"
      fi
      ;;
    "Remove")
      remove_worktree "$wt_path"
      ;;
    "Abort")
      info "aborted"
      exit 0
      ;;
  esac
}

phase_resume() {
  local wt_path="$1"

  phase_claude_running "$wt_path"
  phase_claude_exited "$wt_path"
  phase_push_updates "$wt_path"
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
  git worktree add --no-checkout "$wt_path" -b "$branch_name"
  ok "worktree created at ${wt_path}"

  register_cleanup "$wt_path"

  checkout_and_unlock "$wt_path"

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

  local system_prompt
  system_prompt="$(printf 'You are working in worktree %s on branch %s.\n\n%s' \
    "$wt_path" "$branch" "$skill_content")"

  # Check for existing session_id (resume path)
  local session_id
  session_id="$(read_state_field session_id "$wt_path")"

  info "launching claude..."

  if [[ -n "$session_id" ]]; then
    # Resume existing session
    info "resuming session: ${session_id}"
    (
      cd "$wt_path"
      unset CLAUDECODE
      claude --dangerously-skip-permissions \
        --resume "$session_id"
    ) || true
  else
    # New session: pre-generate ID so we can store it before launch
    session_id="$(uuidgen)"
    local current updated timestamp
    current="$(cat "${wt_path}/.worktree-state.json")"
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    updated="$(printf '%s' "$current" | jq \
      --arg sid "$session_id" \
      --arg t "$timestamp" \
      '.session_id = $sid | .updated_at = $t')"
    write_state "$updated" "$wt_path"
    ok "session id: ${session_id}"

    (
      cd "$wt_path"
      unset CLAUDECODE
      claude --dangerously-skip-permissions \
        --system-prompt "$system_prompt" \
        --session-id "$session_id" \
        "$description"
    ) || true
  fi

  set_phase "claude_exited" "$wt_path"
  ok "claude session ended"
}

phase_claude_exited() {
  local wt_path="$1"

  section "Checking Changes"

  local default_br branch
  default_br="$(default_branch)"
  branch="$(read_state_field branch "$wt_path")"

  # Check for committed changes on this branch vs default branch
  local commit_count
  commit_count="$(git -C "$wt_path" rev-list --count "${default_br}..${branch}")"
  if [[ "$commit_count" -eq 0 ]]; then
    warn "no commits on branch -- nothing to push"
    warn "tip: commit your changes in Claude before exiting"
    exit 0
  fi

  ok "${commit_count} commit(s) detected"
  set_phase "pushing" "$wt_path"
}

phase_push_and_pr() {
  local wt_path="$1"

  section "Pushing and Creating PR"

  local branch description
  branch="$(read_state_field branch "$wt_path")"
  description="$(read_state_field description "$wt_path")"

  info "pushing branch ${branch}..."
  (cd "$wt_path" && safe_push "$branch")
  ok "branch pushed"

  local pr_body
  pr_body="$(printf '## Summary\n- %s\n\n## Test plan\n- [ ] Manual verification of changes\n- [ ] CI passes' \
    "$description")"

  info "creating PR..."
  local pr_url
  pr_url="$(cd "$wt_path" && gh pr create \
    --title "$description" \
    --body "$pr_body" \
    --head "$branch")"
  ok "PR created: ${pr_url}"

  # Write pr_url to state
  local current updated timestamp
  current="$(cat "${wt_path}/.worktree-state.json")"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(printf '%s' "$current" | jq \
    --arg url "$pr_url" \
    --arg t "$timestamp" \
    '.pr_url = $url | .updated_at = $t')"
  write_state "$updated" "$wt_path"

  set_phase "pr_created" "$wt_path"
}

phase_push_updates() {
  local wt_path="$1"

  section "Pushing Updates"

  local branch pr_url
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"

  if [[ -z "$pr_url" ]]; then
    # No PR yet, create one
    phase_push_and_pr "$wt_path"
    return
  fi

  info "pushing updates to ${branch}..."
  (cd "$wt_path" && git push origin "$branch")
  ok "updates pushed to PR: ${pr_url}"

  set_phase "pr_created" "$wt_path"
}

phase_cleanup() {
  local wt_path="$1"

  section "Post-merge Cleanup"

  local branch pr_url default_br
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  default_br="$(default_branch)"

  # Switch to default branch and pull
  cd "$(git rev-parse --show-toplevel)" || die "cannot cd to repo root"
  git checkout "$default_br"
  git pull origin "$default_br"
  ok "switched to ${default_br} and pulled"

  # Disable cleanup trap before intentional removal
  _WT_CLEANUP_PATH=""

  # Remove worktree
  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true
  ok "worktree removed"

  # Delete branches
  git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
  git push origin --delete "$branch" 2>/dev/null || true
  ok "branches cleaned up"

  ok "cleanup complete"
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
  phase_push_and_pr "$wt_path"

  _WT_CLEANUP_PATH=""
  ok "done!"
}

# ── Entry point ──────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  pick_worktree
else
  DESCRIPTION="$1"
  main "$DESCRIPTION"
fi
