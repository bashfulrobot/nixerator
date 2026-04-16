# github-issue: subcommand library for GitHub issue worktree workflows
# Pure JSON output. No TUI, no interactive mode, no launching Claude.
# The skill (SKILL.md) is the sole orchestrator — this script is its hands.

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: github-issue <subcommand> [args]"
  info ""
  info "Subcommands:"
  info "  setup <number>                          -- create worktree + state file"
  info "  status <number>                         -- detect lifecycle state"
  info "  push <number>                           -- push branch + create/update PR"
  info "  audit                                   -- scan all issue worktrees"
  info "  cleanup <number>                        -- remove worktree + branches"
  info "  transition <number> <step> [--detail-json '<json>']"
  info "                                          -- advance workflow state"
  info "  validate-cwd <number>                   -- check working directory"
  info "  check-ci <number>                       -- check PR CI status"
  info "  review-feedback <number>                -- fetch PR review comments"
  exit 0
fi

# ── State v2 constants ────────────────────────────────────────────────────────

VALID_STEPS=(setup assess design plan implement verify push review_dev review_security waiting revamp "done" closed)

# Transition whitelist: from -> space-separated valid targets
declare -A VALID_TRANSITIONS=(
  [setup]="assess"
  [assess]="design plan implement"
  [design]="plan"
  [plan]="implement"
  [implement]="verify"
  [verify]="implement push waiting"
  [push]="review_dev waiting"
  [review_dev]="review_security"
  [review_security]="waiting"
  [waiting]="done revamp closed"
  [revamp]="verify"
  [done]=""
  [closed]=""
)

# ── Helper functions ─────────────────────────────────────────────────────────

fetch_issue_metadata() {
  local issue_number="$1"
  gh issue view "$issue_number" --json title,labels,body
}

derive_branch_type_auto() {
  local labels_json="$1"
  local branch_type=""

  while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    local lower="${label,,}"
    case "$lower" in
      *bug*)
        branch_type="fix"
        break
        ;;
      *enhancement* | *feature*)
        branch_type="feat"
        break
        ;;
      *documentation* | *docs*)
        branch_type="docs"
        break
        ;;
      *refactor*)
        branch_type="refactor"
        break
        ;;
      *testing* | *test*)
        branch_type="test"
        break
        ;;
      *dependenc* | *deps*)
        branch_type="deps"
        break
        ;;
      *ci*)
        branch_type="ci"
        break
        ;;
      *chore*)
        branch_type="chore"
        break
        ;;
      *revert*)
        branch_type="revert"
        break
        ;;
    esac
  done < <(printf '%s' "$labels_json" | jq -r '.[].name')

  printf '%s' "${branch_type:-feat}"
}

build_branch_name() {
  local branch_type="$1"
  local issue_number="$2"
  local title="$3"
  local slug
  slug="$(slugify "$title")"
  local prefix_len=$((${#branch_type} + 1 + ${#issue_number} + 1))
  local max_slug=$((50 - prefix_len))
  if [[ $max_slug -lt 5 ]]; then
    max_slug=5
  fi
  slug="${slug:0:$max_slug}"
  slug="${slug%-}"
  printf '%s/%s-%s' "$branch_type" "$issue_number" "$slug"
}

# ── State v2 helpers ─────────────────────────────────────────────────────────

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
    --argjson version 2 \
    --arg type "issue" \
    --arg issue_number "$issue_number" \
    --arg issue_title "$issue_title" \
    --arg issue_body "$issue_body" \
    --arg branch "$branch" \
    --arg wt_path "$wt_path" \
    --arg pr_url "" \
    --arg session_id "" \
    --arg workflow_step "assess" \
    --arg started_at "$timestamp" \
    --arg updated_at "$timestamp" \
    '{
      version: $version,
      type: $type,
      issue_number: $issue_number,
      issue_title: $issue_title,
      issue_body: $issue_body,
      branch: $branch,
      wt_path: $wt_path,
      pr_url: $pr_url,
      session_id: $session_id,
      workflow_step: $workflow_step,
      workflow_detail: {complexity: null, plan_file: null, review_stage: null, revamp_round: 0, blocker: null},
      step_history: [{step: "setup", completed_at: $started_at}],
      started_at: $started_at,
      updated_at: $updated_at
    }')"
  write_state "$json" "$wt_path"
}

is_valid_step() {
  local step="$1"
  local s
  for s in "${VALID_STEPS[@]}"; do
    [[ "$s" == "$step" ]] && return 0
  done
  return 1
}

is_valid_transition() {
  local from="$1" to="$2"
  local allowed="${VALID_TRANSITIONS[$from]:-}"
  local s
  for s in $allowed; do
    [[ "$s" == "$to" ]] && return 0
  done
  return 1
}

# Migrate v1 state files (no version field) to v2
migrate_v1_state() {
  local wt_path="$1"
  local state_file="${wt_path}/.worktree-state.json"

  # Already v2
  local version
  version="$(jq -r '.version // empty' "$state_file" 2>/dev/null)" || version=""
  if [[ "$version" == "2" ]]; then
    return 0
  fi

  local phase
  phase="$(jq -r '.phase // "setup"' "$state_file")"

  # Map v1 phase to v2 workflow_step
  local workflow_step
  case "$phase" in
    setup) workflow_step="assess" ;;
    claude_running | claude_exited) workflow_step="implement" ;;
    pushing) workflow_step="push" ;;
    pr_created) workflow_step="waiting" ;;
    *) workflow_step="assess" ;;
  esac

  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local current updated
  current="$(cat "$state_file")"
  updated="$(printf '%s' "$current" | jq \
    --argjson version 2 \
    --arg workflow_step "$workflow_step" \
    --arg updated_at "$timestamp" \
    '. + {
      version: $version,
      workflow_step: $workflow_step,
      workflow_detail: (.workflow_detail // {complexity: null, plan_file: null, review_stage: null, revamp_round: 0, blocker: null}),
      step_history: (.step_history // []),
      updated_at: $updated_at
    }')"
  write_state "$updated" "$wt_path"
  ok "migrated state v1 -> v2 (phase=${phase} -> workflow_step=${workflow_step})"
}

# Reconcile workflow_step with git/PR signals
reconcile_state() {
  local wt_path="$1" branch="$2" pr_url="$3" default_br="$4"
  local state_file="${wt_path}/.worktree-state.json"
  local workflow_step
  workflow_step="$(jq -r '.workflow_step' "$state_file")"

  local new_step=""

  # Check PR state if URL exists
  if [[ -n "$pr_url" ]]; then
    local pr_state
    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null)" || pr_state=""

    case "$pr_state" in
      MERGED)
        if [[ "$workflow_step" != "done" ]]; then
          new_step="done"
        fi
        ;;
      CLOSED)
        if [[ "$workflow_step" != "closed" ]]; then
          new_step="closed"
        fi
        ;;
      OPEN)
        local review
        review="$(gh pr view "$pr_url" --json reviewDecision --jq '.reviewDecision // ""' 2>/dev/null)" || review=""
        if [[ "$review" == "CHANGES_REQUESTED" ]] && [[ "$workflow_step" == "waiting" ]]; then
          new_step="revamp"
        fi
        ;;
    esac
  else
    # No PR — check branch merge status
    if is_branch_merged "$branch"; then
      if [[ "$workflow_step" != "done" ]]; then
        new_step="done"
      fi
    fi
  fi

  # Commits exist but step says pre-implementation
  if [[ "$workflow_step" == "plan" ]] || [[ "$workflow_step" == "assess" ]] || [[ "$workflow_step" == "design" ]]; then
    local commit_count
    commit_count="$(git -C "$wt_path" rev-list --count "${default_br}..${branch}" 2>/dev/null)" || commit_count="0"
    if [[ "$commit_count" -gt 0 ]]; then
      new_step="implement"
    fi
  fi

  # PR exists but step says push
  if [[ "$workflow_step" == "push" ]] && [[ -n "$pr_url" ]]; then
    new_step="review_dev"
  fi

  if [[ -n "$new_step" ]]; then
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    local current updated
    current="$(cat "$state_file")"
    updated="$(printf '%s' "$current" | jq \
      --arg step "$new_step" \
      --arg t "$timestamp" \
      '.workflow_step = $step | .updated_at = $t |
       .step_history = .step_history + [{step: $step, completed_at: $t, reconciled: true}]')"
    write_state "$updated" "$wt_path"
    ok "reconciled workflow_step: ${workflow_step} -> ${new_step}"
  fi
}

# ── Subcommands ──────────────────────────────────────────────────────────────

cmd_setup() {
  local issue_number="${1:?usage: github-issue setup <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ -d "$wt_path" ]]; then
    json_error "worktree already exists at ${wt_path} -- use 'github-issue status ${issue_number}' to check state"
  fi

  fetch_remote
  assert_clean_tree

  local issue_json issue_title issue_labels issue_body
  issue_json="$(fetch_issue_metadata "$issue_number")"
  issue_title="$(printf '%s' "$issue_json" | jq -r '.title')"
  issue_labels="$(printf '%s' "$issue_json" | jq -c '.labels')"
  issue_body="$(printf '%s' "$issue_json" | jq -r '.body')"
  ok "fetched: ${issue_title}"

  local branch_type
  branch_type="$(derive_branch_type_auto "$issue_labels")"
  ok "branch type: ${branch_type}"

  local branch_name
  branch_name="$(build_branch_name "$branch_type" "$issue_number" "$issue_title")"
  ok "branch: ${branch_name}"

  mkdir -p "$(dirname "$wt_path")"
  git worktree add --no-checkout "$wt_path" -b "$branch_name"
  register_cleanup "$wt_path"
  checkout_and_unlock "$wt_path"
  create_issue_state "$branch_name" "$wt_path" "$issue_number" "$issue_title" "$issue_body"
  _WT_CLEANUP_PATH=""
  ok "worktree created at ${wt_path}"

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg branch "$branch_name" \
    --arg worktree "$wt_path" \
    --arg branch_type "$branch_type" \
    --arg title "$issue_title" \
    --arg issue_body "$issue_body" \
    '{issue_number: ($issue_number|tonumber), branch: $branch, worktree: $worktree,
      branch_type: $branch_type, title: $title, issue_body: $issue_body,
      workflow_step: "assess"}')"
}

cmd_status() {
  local issue_number="${1:?usage: github-issue status <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  # No worktree -> NEW
  if [[ ! -d "$wt_path" ]]; then
    json_ok "$(jq -n \
      --arg issue_number "$issue_number" \
      '{issue_number: ($issue_number|tonumber), state: "NEW", detail: "no worktree exists",
        worktree: null, branch: null, workflow_step: null, workflow_detail: null,
        step_history: [], title: null, issue_body: null, pr: null}')"
    return
  fi

  local state_file="${wt_path}/.worktree-state.json"
  if [[ ! -f "$state_file" ]]; then
    json_error "worktree exists but no state file at ${state_file}"
  fi

  # Migrate v1 -> v2 if needed
  migrate_v1_state "$wt_path"

  local branch pr_url issue_title issue_body workflow_step workflow_detail step_history
  branch="$(jq -r '.branch' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"
  issue_title="$(jq -r '.issue_title' "$state_file")"
  issue_body="$(jq -r '.issue_body // ""' "$state_file")"
  workflow_step="$(jq -r '.workflow_step' "$state_file")"
  workflow_detail="$(jq -c '.workflow_detail // {}' "$state_file")"
  step_history="$(jq -c '.step_history // []' "$state_file")"

  local default_br
  default_br="$(default_branch)"

  # Reconcile state with external signals
  reconcile_state "$wt_path" "$branch" "$pr_url" "$default_br"

  # Re-read after reconciliation (may have changed)
  workflow_step="$(jq -r '.workflow_step' "$state_file")"
  workflow_detail="$(jq -c '.workflow_detail // {}' "$state_file")"
  step_history="$(jq -c '.step_history // []' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"

  # Also run legacy state detection for the state/detail fields
  detect_issue_state "$wt_path" "$branch" "$pr_url" "$default_br"

  # Build PR sub-object
  local pr_obj="null"
  if [[ -n "$pr_url" ]] && [[ -n "$_detected_pr_state" ]]; then
    local pr_number
    pr_number="$(printf '%s' "$pr_url" | grep -oE '[0-9]+$' || echo "")"
    pr_obj="$(jq -n \
      --arg url "$pr_url" \
      --arg state "$_detected_pr_state" \
      --arg review "$_detected_review" \
      --arg number "$pr_number" \
      '{url: $url, state: $state, review_decision: $review,
        number: (if $number == "" then null else ($number|tonumber) end)}')"
  fi

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg state "$_detected_state" \
    --arg detail "$_detected_detail" \
    --arg worktree "$wt_path" \
    --arg branch "$branch" \
    --arg workflow_step "$workflow_step" \
    --argjson workflow_detail "$workflow_detail" \
    --argjson step_history "$step_history" \
    --arg title "$issue_title" \
    --arg issue_body "$issue_body" \
    --argjson pr "$pr_obj" \
    '{issue_number: ($issue_number|tonumber), state: $state, detail: $detail,
      worktree: $worktree, branch: $branch, workflow_step: $workflow_step,
      workflow_detail: $workflow_detail, step_history: $step_history,
      title: $title, issue_body: $issue_body, pr: $pr}')"
}

cmd_push() {
  local issue_number="${1:?usage: github-issue push <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  local branch pr_url issue_title default_br
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  issue_title="$(read_state_field issue_title "$wt_path")"
  default_br="$(default_branch)"

  # Check for commits
  local commit_count
  commit_count="$(git -C "$wt_path" rev-list --count "${default_br}..${branch}")"
  if [[ "$commit_count" -eq 0 ]]; then
    json_error "no commits on branch ${branch} -- nothing to push"
  fi

  local action=""
  if [[ -z "$pr_url" ]]; then
    # Push + create PR
    (cd "$wt_path" && safe_push "$branch")
    ok "branch pushed"

    local commit_log pr_body
    commit_log="$(git -C "$wt_path" log --format='- %s%n%w(0,2,2)%b' "${default_br}..${branch}")"
    pr_body="$(printf '## Summary\nCloses #%s: %s\n\n%s' "$issue_number" "$issue_title" "$commit_log")"

    pr_url="$(cd "$wt_path" && gh pr create \
      --title "$issue_title" \
      --body "$pr_body" \
      --head "$branch")"
    ok "PR created: ${pr_url}"

    # Update state with PR URL
    local current updated timestamp
    current="$(cat "${wt_path}/.worktree-state.json")"
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    updated="$(printf '%s' "$current" | jq \
      --arg url "$pr_url" \
      --arg t "$timestamp" \
      '.pr_url = $url | .updated_at = $t')"
    write_state "$updated" "$wt_path"

    gh issue comment "$issue_number" --body "PR ready for review: $pr_url" 2>/dev/null || true
    action="created"
  else
    # Push updates to existing PR
    (cd "$wt_path" && git push origin "$branch")
    ok "updates pushed to PR: ${pr_url}"
    action="updated"
  fi

  # Check CI status if available
  local ci_status="unknown"
  local ci_json
  ci_json="$(gh pr checks "$pr_url" --json name,state,conclusion 2>/dev/null)" || ci_json="[]"
  if [[ "$ci_json" != "[]" ]]; then
    local total passing failing pending
    total="$(printf '%s' "$ci_json" | jq 'length')"
    passing="$(printf '%s' "$ci_json" | jq '[.[] | select(.conclusion == "SUCCESS" or .conclusion == "NEUTRAL")] | length')"
    failing="$(printf '%s' "$ci_json" | jq '[.[] | select(.conclusion == "FAILURE" or .conclusion == "ERROR")] | length')"
    pending="$(printf '%s' "$ci_json" | jq '[.[] | select(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS")] | length')"
    if [[ "$failing" -gt 0 ]]; then
      ci_status="failing"
    elif [[ "$pending" -gt 0 ]]; then
      ci_status="pending"
    elif [[ "$passing" -eq "$total" ]] && [[ "$total" -gt 0 ]]; then
      ci_status="passing"
    fi
  fi

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg action "$action" \
    --arg pr_url "$pr_url" \
    --arg branch "$branch" \
    --argjson commits "$commit_count" \
    --arg ci_status "$ci_status" \
    '{issue_number: ($issue_number|tonumber), action: $action, pr_url: $pr_url,
      branch: $branch, commits: $commits, ci_status: $ci_status}')"
}

cmd_audit() {
  fetch_remote

  local wt_base
  wt_base="$(worktree_base)"

  if [[ ! -d "$wt_base" ]]; then
    json_ok "[]"
    return
  fi

  local default_br
  default_br="$(default_branch)"

  local results="[]"
  while IFS= read -r -d '' wt_dir; do
    local state_file="${wt_dir}/.worktree-state.json"
    [[ -f "$state_file" ]] || continue

    local wt_type
    wt_type="$(jq -r '.type' "$state_file")"
    [[ "$wt_type" == "issue" ]] || continue

    # Migrate v1 if needed
    migrate_v1_state "$wt_dir"

    local issue_num issue_title branch pr_url workflow_step
    issue_num="$(jq -r '.issue_number' "$state_file")"
    issue_title="$(jq -r '.issue_title' "$state_file")"
    branch="$(jq -r '.branch' "$state_file")"
    pr_url="$(jq -r '.pr_url // ""' "$state_file")"
    workflow_step="$(jq -r '.workflow_step' "$state_file")"

    detect_issue_state "$wt_dir" "$branch" "$pr_url" "$default_br"

    results="$(printf '%s' "$results" | jq \
      --arg num "$issue_num" \
      --arg title "$issue_title" \
      --arg state "$_detected_state" \
      --arg detail "$_detected_detail" \
      --arg branch "$branch" \
      --arg pr_url "$pr_url" \
      --arg worktree "$wt_dir" \
      --arg workflow_step "$workflow_step" \
      '. + [{issue_number: ($num|tonumber), title: $title, state: $state,
              detail: $detail, branch: $branch,
              pr_url: (if $pr_url == "" then null else $pr_url end),
              worktree: $worktree, workflow_step: $workflow_step}]')"
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name 'issue-*' -print0 2>/dev/null)

  json_ok "$results"
}

cmd_cleanup() {
  local issue_number="${1:?usage: github-issue cleanup <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  local state_file="${wt_path}/.worktree-state.json"
  if [[ ! -f "$state_file" ]]; then
    json_error "worktree exists but no state file"
  fi

  local branch pr_url default_br pr_number
  branch="$(jq -r '.branch' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"
  pr_number="$(printf '%s' "$pr_url" | grep -oE '[0-9]+$' || echo "")"
  default_br="$(default_branch)"

  # Switch to default branch
  cd "$(git rev-parse --show-toplevel)" || json_error "cannot cd to repo root"
  git checkout "$default_br" >&2
  git pull origin "$default_br" >&2
  ok "switched to ${default_br} and pulled"

  # Remove worktree
  _WT_CLEANUP_PATH=""
  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true
  ok "worktree removed"

  # Delete branches
  git branch -D "$branch" 2>/dev/null || true
  git push origin --delete "$branch" 2>/dev/null || true
  ok "branches cleaned up"

  # Close issue if PR exists
  if [[ -n "$pr_number" ]]; then
    gh issue comment "$issue_number" \
      --body "Resolved via #${pr_number}. Branch and worktree cleaned up." 2>/dev/null || true
    gh issue close "$issue_number" 2>/dev/null || true
    ok "issue closed"
  fi

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg branch "$branch" \
    --arg pr_url "$pr_url" \
    '{issue_number: ($issue_number|tonumber), cleaned: true, branch: $branch,
      pr_url: (if $pr_url == "" then null else $pr_url end)}')"
}

cmd_transition() {
  local issue_number="${1:?usage: github-issue transition <issue-number> <step> [--detail-json '<json>']}"
  local new_step="${2:?usage: github-issue transition <issue-number> <step>}"
  shift 2

  # Parse optional --detail-json
  local detail_json="{}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --detail-json)
        detail_json="${2:?--detail-json requires a value}"
        shift 2
        ;;
      *) die "unknown option: $1" ;;
    esac
  done

  # Validate step name
  if ! is_valid_step "$new_step"; then
    json_error "invalid step '${new_step}' -- valid steps: ${VALID_STEPS[*]}"
  fi

  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  local state_file="${wt_path}/.worktree-state.json"
  if [[ ! -f "$state_file" ]]; then
    json_error "worktree exists but no state file"
  fi

  # Migrate v1 if needed
  migrate_v1_state "$wt_path"

  local current_step
  current_step="$(jq -r '.workflow_step' "$state_file")"

  # Validate transition
  if ! is_valid_transition "$current_step" "$new_step"; then
    json_error "invalid transition: ${current_step} -> ${new_step} -- allowed from ${current_step}: ${VALID_TRANSITIONS[$current_step]:-none}"
  fi

  # Validate detail_json is valid JSON
  if ! printf '%s' "$detail_json" | jq . >/dev/null 2>&1; then
    json_error "invalid --detail-json: not valid JSON"
  fi

  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local current updated
  current="$(cat "$state_file")"
  updated="$(printf '%s' "$current" | jq \
    --arg step "$new_step" \
    --arg t "$timestamp" \
    --argjson detail "$detail_json" \
    '.workflow_step = $step |
     .updated_at = $t |
     .workflow_detail = (.workflow_detail // {}) * $detail |
     .step_history = (.step_history // []) + [{step: $step, completed_at: $t}]')"
  write_state "$updated" "$wt_path"

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg previous_step "$current_step" \
    --arg current_step "$new_step" \
    --arg updated_at "$timestamp" \
    '{issue_number: ($issue_number|tonumber), previous_step: $previous_step,
      current_step: $current_step, updated_at: $updated_at}')"
}

cmd_validate_cwd() {
  local issue_number="${1:?usage: github-issue validate-cwd <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  # Resolve both to absolute paths for comparison
  local expected actual
  expected="$(cd "$wt_path" && pwd -P)"
  actual="$(pwd -P)"

  if [[ "$actual" == "$expected" ]]; then
    json_ok "$(jq -n \
      --arg expected "$expected" \
      --arg actual "$actual" \
      '{valid: true, expected: $expected, actual: $actual}')"
  else
    json_ok "$(jq -n \
      --arg expected "$expected" \
      --arg actual "$actual" \
      '{valid: false, expected: $expected, actual: $actual,
        fix: ("cd " + $expected)}')"
  fi
}

cmd_check_ci() {
  local issue_number="${1:?usage: github-issue check-ci <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  local pr_url
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"

  if [[ -z "$pr_url" ]]; then
    json_error "no PR exists for issue #${issue_number}"
  fi

  local checks_json
  checks_json="$(gh pr checks "$pr_url" --json name,state,conclusion,detailsUrl 2>/dev/null)" || checks_json="[]"

  local ci_status="unknown"
  local passing_checks failing_checks pending_checks
  passing_checks="$(printf '%s' "$checks_json" | jq -c '[.[] | select(.conclusion == "SUCCESS" or .conclusion == "NEUTRAL") | {name, conclusion}]')"
  failing_checks="$(printf '%s' "$checks_json" | jq -c '[.[] | select(.conclusion == "FAILURE" or .conclusion == "ERROR") | {name, conclusion, detailsUrl}]')"
  pending_checks="$(printf '%s' "$checks_json" | jq -c '[.[] | select(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS") | {name, state}]')"

  local total failing pending passing
  total="$(printf '%s' "$checks_json" | jq 'length')"
  failing="$(printf '%s' "$failing_checks" | jq 'length')"
  pending="$(printf '%s' "$pending_checks" | jq 'length')"
  passing="$(printf '%s' "$passing_checks" | jq 'length')"

  if [[ "$failing" -gt 0 ]]; then
    ci_status="failing"
  elif [[ "$pending" -gt 0 ]]; then
    ci_status="pending"
  elif [[ "$passing" -eq "$total" ]] && [[ "$total" -gt 0 ]]; then
    ci_status="passing"
  fi

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg pr_url "$pr_url" \
    --arg ci_status "$ci_status" \
    --argjson total "$total" \
    --argjson passing_checks "$passing_checks" \
    --argjson failing_checks "$failing_checks" \
    --argjson pending_checks "$pending_checks" \
    '{issue_number: ($issue_number|tonumber), pr_url: $pr_url, ci_status: $ci_status,
      total_checks: $total, passing_checks: $passing_checks,
      failing_checks: $failing_checks, pending_checks: $pending_checks}')"
}

cmd_review_feedback() {
  local issue_number="${1:?usage: github-issue review-feedback <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  local pr_url
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"

  if [[ -z "$pr_url" ]]; then
    json_error "no PR exists for issue #${issue_number}"
  fi

  # Extract owner/repo/number from PR URL
  local pr_number repo_path
  pr_number="$(printf '%s' "$pr_url" | grep -oE '[0-9]+$' || echo "")"
  repo_path="$(printf '%s' "$pr_url" | sed 's|https://github.com/||; s|/pull/[0-9]*$||')"

  if [[ -z "$pr_number" ]] || [[ -z "$repo_path" ]]; then
    json_error "cannot parse PR URL: ${pr_url}"
  fi

  # Fetch reviews (high-level)
  local reviews
  reviews="$(gh api "repos/${repo_path}/pulls/${pr_number}/reviews" \
    --jq '[.[] | {id, state, body, author: .user.login, submitted_at}]' 2>/dev/null)" || reviews="[]"

  # Fetch inline comments
  local inline_comments
  inline_comments="$(gh api "repos/${repo_path}/pulls/${pr_number}/comments" \
    --jq '[.[] | {id, path, line: (.line // .original_line), body, author: .user.login, created_at}]' 2>/dev/null)" || inline_comments="[]"

  # Get review decision
  local review_decision
  review_decision="$(gh pr view "$pr_url" --json reviewDecision --jq '.reviewDecision // ""' 2>/dev/null)" || review_decision=""

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg pr_url "$pr_url" \
    --arg review_decision "$review_decision" \
    --argjson reviews "$reviews" \
    --argjson inline_comments "$inline_comments" \
    '{issue_number: ($issue_number|tonumber), pr_url: $pr_url,
      review_decision: $review_decision, reviews: $reviews,
      inline_comments: $inline_comments}')"
}

# ── Entry point ──────────────────────────────────────────────────────────────

case "${1:-}" in
  setup | status | push | audit | cleanup | transition | validate-cwd | check-ci | review-feedback)
    _JSON_MODE=1
    SUBCMD="${1//-/_}"
    shift
    "cmd_${SUBCMD}" "$@"
    ;;
  *)
    die "usage: github-issue <subcommand> [args] -- run 'github-issue --help' for details"
    ;;
esac
