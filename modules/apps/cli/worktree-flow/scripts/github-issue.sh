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
      *ci*)             branch_type="ci";       break ;;
      *chore*)          branch_type="chore";    break ;;
      *revert*)         branch_type="revert";   break ;;
      *dependenc*|*deps*) branch_type="deps";   break ;;
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
  git worktree add "$wt_path" -b "$branch_name"
  ok "worktree created at ${wt_path}"

  register_cleanup "$wt_path"

  unlock_git_crypt "$wt_path"

  info "writing state file..."
  create_issue_state "$branch_name" "$wt_path" "$issue_number" "$issue_title" "$issue_body"
  ok "state file written"

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

  # Check if Claude made any changes (exit 0 = no changes, exit 1 = changes exist)
  if git -C "$wt_path" diff --quiet HEAD; then
    warn "no changes detected -- nothing to push"
    exit 0
  fi

  ok "changes detected"
  set_phase "pushing" "$wt_path"
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

  # Existing worktree check (resume support coming in Plan 02)
  if [[ -d "$WT_PATH" ]]; then
    die "worktree already exists at ${WT_PATH} (resume support coming in next plan)"
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
