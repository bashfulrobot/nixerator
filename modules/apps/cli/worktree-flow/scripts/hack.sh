# hack: subcommand library for hack worktree workflows
# Pure JSON output. No TUI, no interactive mode, no launching Claude.
# The skill (SKILL.md) is the sole orchestrator — this script is its hands.

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: hack <subcommand> [args]"
  info ""
  info "Subcommands:"
  info "  setup \"<description>\"                   -- create worktree + state file"
  info "  status <slug>                            -- detect lifecycle state"
  info "  push <slug>                              -- push branch + create/update PR"
  info "  audit                                    -- scan all hack worktrees"
  info "  cleanup <slug>                           -- remove worktree + branches"
  info "  transition <slug> <step> [--detail-json '<json>']"
  info "                                           -- advance workflow state"
  info "  validate-cwd <slug>                      -- check working directory"
  exit 0
fi

# ── State v2 constants ────────────────────────────────────────────────────────

VALID_STEPS=(setup implement verify push review_dev review_security waiting revamp "done" closed)

# Transition whitelist: from -> space-separated valid targets
declare -A VALID_TRANSITIONS=(
  [setup]="implement"
  [implement]="verify"
  [verify]="implement push"
  [push]="review_dev"
  [review_dev]="review_security"
  [review_security]="waiting"
  [waiting]="done revamp closed"
  [revamp]="verify"
  [done]=""
  [closed]=""
)

# ── State v2 helpers ─────────────────────────────────────────────────────────

create_hack_state() {
  local branch="$1"
  local wt_path="$2"
  local description="$3"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local json
  json="$(jq -n \
    --argjson version 2 \
    --arg type "hack" \
    --arg description "$description" \
    --arg branch "$branch" \
    --arg wt_path "$wt_path" \
    --arg pr_url "" \
    --arg session_id "" \
    --arg workflow_step "implement" \
    --arg started_at "$timestamp" \
    --arg updated_at "$timestamp" \
    '{
      version: $version,
      type: $type,
      description: $description,
      branch: $branch,
      wt_path: $wt_path,
      pr_url: $pr_url,
      session_id: $session_id,
      workflow_step: $workflow_step,
      workflow_detail: {review_stage: null, revamp_round: 0, blocker: null},
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
    setup) workflow_step="implement" ;;
    claude_running | claude_exited) workflow_step="implement" ;;
    pushing) workflow_step="push" ;;
    pr_created) workflow_step="waiting" ;;
    *) workflow_step="implement" ;;
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
      workflow_detail: (.workflow_detail // {review_stage: null, revamp_round: 0, blocker: null}),
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

  # Commits exist but step says setup
  if [[ "$workflow_step" == "setup" ]]; then
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
  local description="${1:?usage: hack setup \"<description>\"}"
  local slug
  slug="$(slugify "$description")"
  local wt_path
  wt_path="$(worktree_base)/hack-${slug}"

  if [[ -d "$wt_path" ]]; then
    json_error "worktree already exists at ${wt_path} -- use 'hack status ${slug}' to check state"
  fi

  fetch_remote
  assert_clean_tree

  local branch_name="hack/${slug}"
  ok "branch: ${branch_name}"

  mkdir -p "$(dirname "$wt_path")"
  git worktree add --no-checkout "$wt_path" -b "$branch_name"
  register_cleanup "$wt_path"
  checkout_and_unlock "$wt_path"
  create_hack_state "$branch_name" "$wt_path" "$description"
  _WT_CLEANUP_PATH=""
  ok "worktree created at ${wt_path}"

  json_ok "$(jq -n \
    --arg slug "$slug" \
    --arg description "$description" \
    --arg branch "$branch_name" \
    --arg worktree "$wt_path" \
    '{slug: $slug, description: $description, branch: $branch, worktree: $worktree,
      workflow_step: "implement"}')"
}

cmd_status() {
  local slug="${1:?usage: hack status <slug>}"
  local wt_path
  wt_path="$(worktree_base)/hack-${slug}"

  # No worktree -> NEW
  if [[ ! -d "$wt_path" ]]; then
    json_ok "$(jq -n \
      --arg slug "$slug" \
      '{slug: $slug, state: "NEW", detail: "no worktree exists",
        worktree: null, branch: null, workflow_step: null, workflow_detail: null,
        step_history: [], description: null, pr: null}')"
    return
  fi

  local state_file="${wt_path}/.worktree-state.json"
  if [[ ! -f "$state_file" ]]; then
    json_error "worktree exists but no state file at ${state_file}"
  fi

  # Migrate v1 -> v2 if needed
  migrate_v1_state "$wt_path"

  local branch pr_url description workflow_step workflow_detail step_history
  branch="$(jq -r '.branch' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"
  description="$(jq -r '.description' "$state_file")"
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
    --arg slug "$slug" \
    --arg state "$_detected_state" \
    --arg detail "$_detected_detail" \
    --arg worktree "$wt_path" \
    --arg branch "$branch" \
    --arg workflow_step "$workflow_step" \
    --argjson workflow_detail "$workflow_detail" \
    --argjson step_history "$step_history" \
    --arg description "$description" \
    --argjson pr "$pr_obj" \
    '{slug: $slug, state: $state, detail: $detail,
      worktree: $worktree, branch: $branch, workflow_step: $workflow_step,
      workflow_detail: $workflow_detail, step_history: $step_history,
      description: $description, pr: $pr}')"
}

cmd_push() {
  local slug="${1:?usage: hack push <slug>}"
  local wt_path
  wt_path="$(worktree_base)/hack-${slug}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for hack '${slug}'"
  fi

  local branch pr_url description default_br
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  description="$(read_state_field description "$wt_path")"
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
    pr_body="$(printf '## Summary\n%s' "$commit_log")"

    pr_url="$(cd "$wt_path" && gh pr create \
      --title "$description" \
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
    --arg slug "$slug" \
    --arg action "$action" \
    --arg pr_url "$pr_url" \
    --arg branch "$branch" \
    --argjson commits "$commit_count" \
    --arg ci_status "$ci_status" \
    '{slug: $slug, action: $action, pr_url: $pr_url,
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
    [[ "$wt_type" == "hack" ]] || continue

    # Migrate v1 if needed
    migrate_v1_state "$wt_dir"

    local description branch pr_url workflow_step slug_name
    description="$(jq -r '.description' "$state_file")"
    branch="$(jq -r '.branch' "$state_file")"
    pr_url="$(jq -r '.pr_url // ""' "$state_file")"
    workflow_step="$(jq -r '.workflow_step' "$state_file")"
    slug_name="$(basename "$wt_dir")"
    slug_name="${slug_name#hack-}"

    detect_issue_state "$wt_dir" "$branch" "$pr_url" "$default_br"

    results="$(printf '%s' "$results" | jq \
      --arg slug "$slug_name" \
      --arg description "$description" \
      --arg state "$_detected_state" \
      --arg detail "$_detected_detail" \
      --arg branch "$branch" \
      --arg pr_url "$pr_url" \
      --arg worktree "$wt_dir" \
      --arg workflow_step "$workflow_step" \
      '. + [{slug: $slug, description: $description, state: $state,
              detail: $detail, branch: $branch,
              pr_url: (if $pr_url == "" then null else $pr_url end),
              worktree: $worktree, workflow_step: $workflow_step}]')"
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name 'hack-*' -print0 2>/dev/null)

  json_ok "$results"
}

cmd_cleanup() {
  local slug="${1:?usage: hack cleanup <slug>}"
  local wt_path
  wt_path="$(worktree_base)/hack-${slug}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for hack '${slug}'"
  fi

  local state_file="${wt_path}/.worktree-state.json"
  if [[ ! -f "$state_file" ]]; then
    json_error "worktree exists but no state file"
  fi

  local branch pr_url default_br
  branch="$(jq -r '.branch' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"
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

  json_ok "$(jq -n \
    --arg slug "$slug" \
    --arg branch "$branch" \
    --arg pr_url "$pr_url" \
    '{slug: $slug, cleaned: true, branch: $branch,
      pr_url: (if $pr_url == "" then null else $pr_url end)}')"
}

cmd_transition() {
  local slug="${1:?usage: hack transition <slug> <step> [--detail-json '<json>']}"
  local new_step="${2:?usage: hack transition <slug> <step>}"
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
  wt_path="$(worktree_base)/hack-${slug}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for hack '${slug}'"
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
    --arg slug "$slug" \
    --arg previous_step "$current_step" \
    --arg current_step "$new_step" \
    --arg updated_at "$timestamp" \
    '{slug: $slug, previous_step: $previous_step,
      current_step: $current_step, updated_at: $updated_at}')"
}

cmd_validate_cwd() {
  local slug="${1:?usage: hack validate-cwd <slug>}"
  local wt_path
  wt_path="$(worktree_base)/hack-${slug}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for hack '${slug}'"
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

# ── Entry point ──────────────────────────────────────────────────────────────

case "${1:-}" in
  setup | status | push | audit | cleanup | transition | validate-cwd)
    _JSON_MODE=1
    SUBCMD="${1//-/_}"
    shift
    "cmd_${SUBCMD}" "$@"
    ;;
  *)
    die "usage: hack <subcommand> [args] -- run 'hack --help' for details"
    ;;
esac
