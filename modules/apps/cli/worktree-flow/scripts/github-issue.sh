# github-issue: AI-powered worktree workflow for GitHub issues

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: github-issue <issue-number>"
  info "Creates an isolated git worktree and launches Claude to work on a GitHub issue."
  info ""
  info "Workflow:"
  info "  1. Fetches issue metadata from GitHub"
  info "  2. Creates a worktree with a branch named <type>/<number>-<slug>"
  info "  3. Launches Claude Code in the worktree"
  info "  4. Pushes the branch and creates a PR"
  info "  5. Comments on the issue with a link to the PR"
  exit 0
fi

if [[ $# -lt 1 ]]; then
  die "usage: github-issue <issue-number>"
fi

ISSUE_NUMBER="$1"

# ── Helper functions ─────────────────────────────────────────────────────────

fetch_issue_metadata() {
  local issue_number="$1"
  gh issue view "$issue_number" --json title,labels,body
}

derive_branch_type() {
  local labels_json="$1"
  local branch_type=""

  # Process all labels, return first match
  while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    local lower="${label,,}"
    case "$lower" in
      *bug*)            branch_type="fix";      break ;;
      *enhancement*|*feature*) branch_type="feat"; break ;;
      *documentation*|*docs*) branch_type="docs"; break ;;
      *refactor*)       branch_type="refactor"; break ;;
      *testing*|*test*) branch_type="test";     break ;;
      *dependenc*|*deps*) branch_type="deps";   break ;;
      *ci*)             branch_type="ci";       break ;;
      *chore*)          branch_type="chore";    break ;;
      *revert*)         branch_type="revert";   break ;;
    esac
  done < <(printf '%s' "$labels_json" | jq -r '.[].name')

  if [[ -n "$branch_type" ]]; then
    printf '%s' "$branch_type"
  else
    # Fallback: prompt user
    gum choose --header "Branch type:" \
      "feat" "fix" "docs" "refactor" "test" "ci" "chore" "revert" "deps" \
      || die "aborted"
  fi
}

build_branch_name() {
  local branch_type="$1"
  local issue_number="$2"
  local title="$3"
  local slug
  slug="$(slugify "$title")"
  # Prefix is "<type>/<number>-", keep total under ~50 chars
  local prefix_len=$(( ${#branch_type} + 1 + ${#issue_number} + 1 ))
  local max_slug=$(( 50 - prefix_len ))
  if [[ $max_slug -lt 5 ]]; then
    max_slug=5
  fi
  slug="${slug:0:$max_slug}"
  slug="${slug%-}"  # trim trailing dash from truncation
  printf '%s/%s-%s' "$branch_type" "$issue_number" "$slug"
}

create_issue_state() {
  local branch="$1"
  local wt_path="$2"
  local issue_number="$3"
  local issue_title="$4"
  local issue_body="$5"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local json
  json="$(jq -n \
    --arg type         "issue" \
    --arg phase        "setup" \
    --arg branch       "$branch" \
    --arg wt_path      "$wt_path" \
    --arg session_id   "" \
    --arg pr_url       "" \
    --arg issue_number "$issue_number" \
    --arg issue_title  "$issue_title" \
    --arg issue_body   "$issue_body" \
    --arg started_at   "$timestamp" \
    --arg updated_at   "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path,
      session_id: $session_id, pr_url: $pr_url,
      issue_number: $issue_number, issue_title: $issue_title, issue_body: $issue_body,
      started_at: $started_at, updated_at: $updated_at}')"
  write_state "$json" "$wt_path"
}

# ── Phase functions ──────────────────────────────────────────────────────────

phase_setup() {
  local issue_number="$1"
  local wt_path="$2"

  section "Setup"

  info "fetching issue #${issue_number} metadata..."
  local issue_json
  issue_json="$(fetch_issue_metadata "$issue_number")"

  local issue_title issue_labels issue_body
  issue_title="$(printf '%s' "$issue_json" | jq -r '.title')"
  issue_labels="$(printf '%s' "$issue_json" | jq -c '.labels')"
  issue_body="$(printf '%s' "$issue_json" | jq -r '.body')"
  ok "fetched: ${issue_title}"

  info "determining branch type from labels..."
  local branch_type
  branch_type="$(derive_branch_type "$issue_labels")"
  ok "branch type: ${branch_type}"

  local branch_name
  branch_name="$(build_branch_name "$branch_type" "$issue_number" "$issue_title")"
  ok "branch: ${branch_name}"

  info "creating worktree..."
  mkdir -p "$(dirname "$wt_path")"
  git worktree add --no-checkout "$wt_path" -b "$branch_name"
  ok "worktree created at ${wt_path}"

  register_cleanup "$wt_path"

  checkout_and_unlock "$wt_path"

  info "writing state file..."
  create_issue_state "$branch_name" "$wt_path" "$issue_number" "$issue_title" "$issue_body"
  ok "state file written"

  # Disable cleanup trap before launching Claude -- worktree must survive
  # interruption so the user can resume later
  _WT_CLEANUP_PATH=""

  set_phase "claude_running" "$wt_path"
  ok "setup complete"
}

phase_claude_running() {
  local wt_path="$1"

  section "Launching Claude"

  local skill_path="$HOME/.claude/skills/github-issue/SKILL.md"
  local issue_body
  issue_body="$(read_state_field issue_body "$wt_path")"
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
  prompt="$(printf 'You are working on a GitHub issue in worktree %s on branch %s.\n\n%s\n\nIssue:\n%s' \
    "$wt_path" "$branch" "$skill_content" "$issue_body")"

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

  # Check if Claude made any changes (staged, unstaged, or untracked)
  # Exclude .worktree-state.json from porcelain check (it's always present and untracked)
  local porcelain
  porcelain="$(git -C "$wt_path" status --porcelain | grep -v '^?? \.worktree-state\.json$' || true)"
  if git -C "$wt_path" diff --quiet HEAD && [[ -z "$porcelain" ]]; then
    warn "no changes detected -- nothing to push"
    exit 0
  fi

  ok "changes detected"
  set_phase "pushing" "$wt_path"
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

phase_cleanup() {
  local issue_number="$1" wt_path="$2"

  section "Post-merge Cleanup"

  local branch pr_url pr_number default_br
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path")"
  pr_number="$(printf '%s' "$pr_url" | grep -oE '[0-9]+$')"
  default_br="$(default_branch)"

  # PM-02: switch to default branch and pull (must leave worktree dir first)
  cd "$(git rev-parse --show-toplevel)" || die "cannot cd to repo root"
  git checkout "$default_br"
  git pull origin "$default_br"
  ok "switched to $default_br and pulled"

  # Disable cleanup trap before intentional removal (Pitfall 5)
  _WT_CLEANUP_PATH=""

  # PM-03 / WT-05: worktree remove, then prune, then branch delete
  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true
  ok "worktree removed"

  # PM-02: delete local and remote branches
  git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
  git push origin --delete "$branch" 2>/dev/null || true
  ok "branches cleaned up"

  # PM-04: comment on issue and PR with resolution summary
  local resolution_msg="Resolved via #${pr_number}. Branch and worktree cleaned up."
  gh issue comment "$issue_number" --body "$resolution_msg" 2>/dev/null || true
  gh pr comment "$pr_url" --body "$resolution_msg" 2>/dev/null || true
  ok "resolution comments posted"

  ok "cleanup complete for issue #${issue_number}"
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

phase_resume() {
  local issue_number="$1" wt_path="$2" current_phase="$3"
  register_cleanup "$wt_path"

  local start=0
  case "$current_phase" in
    setup)          start=1 ;;
    claude_running) start=1 ;;
    claude_exited)  start=2 ;;
    pushing)        start=3 ;;
    pr_created)
      ok "PR already created: $(read_state_field pr_url "$wt_path")"
      return ;;
    *) die "unknown phase: $current_phase" ;;
  esac

  if [[ $start -le 1 ]]; then phase_claude_running "$wt_path"; fi
  if [[ $start -le 2 ]]; then phase_claude_exited "$wt_path"; fi
  if [[ $start -le 3 ]]; then phase_push_and_pr "$issue_number" "$wt_path"; fi

  # Disable cleanup trap on successful resume completion
  _WT_CLEANUP_PATH=""
  ok "done! PR created for issue #${issue_number}"
}

handle_existing_worktree() {
  local issue_number="$1" wt_path="$2"

  if [[ ! -f "${wt_path}/.worktree-state.json" ]]; then
    die "worktree exists but no state file found at ${wt_path}/.worktree-state.json"
  fi

  local phase branch pr_url
  phase="$(read_state_field phase "$wt_path")"
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path")"

  # PM-01: detect merged PR
  if [[ "$phase" == "pr_created" ]] && [[ -n "$pr_url" ]]; then
    local pr_state
    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")"
    if [[ "$pr_state" == "MERGED" ]]; then
      phase_cleanup "$issue_number" "$wt_path"
      return
    fi
  fi

  info "Issue #${issue_number}: phase ${phase}, branch ${branch}"

  local choice
  choice="$(gum choose "Resume" "Remove & restart" "Abort" || die "aborted")"

  case "$choice" in
    "Resume")
      phase_resume "$issue_number" "$wt_path" "$phase"
      ;;
    "Remove & restart")
      remove_worktree "$wt_path"
      main "$issue_number"
      ;;
    "Abort")
      info "aborted"
      exit 0
      ;;
  esac
}

phase_push_and_pr() {
  local issue_number="$1"
  local wt_path="$2"

  section "Pushing and Creating PR"

  local branch issue_title
  branch="$(read_state_field branch "$wt_path")"
  issue_title="$(read_state_field issue_title "$wt_path")"

  info "pushing branch ${branch}..."
  ( cd "$wt_path" && safe_push "$branch" )
  ok "branch pushed"

  # Build PR body
  local pr_body
  pr_body="$(printf '## Summary\n- Implements #%s: %s\n\n## Test plan\n- [ ] Manual verification of changes\n- [ ] CI passes' \
    "$issue_number" "$issue_title")"

  info "creating PR..."
  local pr_url
  pr_url="$(cd "$wt_path" && gh pr create \
    --title "$issue_title" \
    --body "$pr_body" \
    --head "$branch")"
  ok "PR created: ${pr_url}"

  # Write pr_url to state file atomically
  local current updated timestamp
  current="$(cat "${wt_path}/.worktree-state.json")"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(printf '%s' "$current" | jq \
    --arg url "$pr_url" \
    --arg t "$timestamp" \
    '.pr_url = $url | .updated_at = $t')"
  write_state "$updated" "$wt_path"

  set_phase "pr_created" "$wt_path"

  # Comment on issue with PR link (RF-02)
  info "commenting on issue #${issue_number}..."
  gh issue comment "$issue_number" --body "PR ready for review: $pr_url"
  ok "issue comment posted"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  ISSUE_NUMBER="$1"
  WT_PATH="$(worktree_base)/issue-${ISSUE_NUMBER}"

  # Pre-flight
  assert_clean_tree
  check_orphan_worktrees

  # Existing worktree check
  if [[ -d "$WT_PATH" ]]; then
    handle_existing_worktree "$ISSUE_NUMBER" "$WT_PATH"
    exit 0
  fi

  phase_setup "$ISSUE_NUMBER" "$WT_PATH"
  phase_claude_running "$WT_PATH"
  phase_claude_exited "$WT_PATH"
  phase_push_and_pr "$ISSUE_NUMBER" "$WT_PATH"

  # Disable cleanup trap -- workflow completed successfully
  _WT_CLEANUP_PATH=""

  ok "done! PR created for issue #${ISSUE_NUMBER}"
}

main "$ISSUE_NUMBER"
