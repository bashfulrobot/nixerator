# dependabot: subcommand library for Dependabot alert worktree workflows
# Pure JSON output. No TUI, no interactive mode, no launching Claude.
# The skill (SKILL.md) is the sole orchestrator — this script is its hands.

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: dependabot <subcommand> [args]"
  info ""
  info "Subcommands:"
  info "  setup <alert-number>                    -- create worktree + state file"
  info "  status <alert-number>                   -- detect lifecycle state"
  info "  push <alert-number>                     -- push branch + create/update PR"
  info "  audit                                   -- scan all dependabot worktrees"
  info "  cleanup <alert-number>                  -- remove worktree + branches"
  info "  transition <alert-number> <step> [--detail-json '<json>']"
  info "                                          -- advance workflow state"
  info "  validate-cwd <alert-number>             -- check working directory"
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

# ── Helper functions ─────────────────────────────────────────────────────────

fetch_alert() {
  local alert_number="$1"
  gh api "repos/{owner}/{repo}/dependabot/alerts/${alert_number}"
}

find_dependabot_worktree() {
  local alert_number="$1"
  local wt_base
  wt_base="$(worktree_base)"
  local match=""
  while IFS= read -r -d '' wt_dir; do
    if [[ -f "${wt_dir}/.worktree-state.json" ]]; then
      local num
      num="$(jq -r '.alert_number // ""' "${wt_dir}/.worktree-state.json")"
      if [[ "$num" == "$alert_number" ]]; then
        match="$wt_dir"
        break
      fi
    fi
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name "dependabot-${alert_number}-*" -print0 2>/dev/null)
  printf '%s' "$match"
}

# ── State v2 helpers ─────────────────────────────────────────────────────────

create_dependabot_state() {
  local branch="$1"
  local wt_path="$2"
  local alert_number="$3"
  local package_name="$4"
  local manifest_path="$5"
  local patched_version="$6"
  local advisory_summary="$7"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local json
  json="$(jq -n \
    --argjson version 2 \
    --arg type "dependabot" \
    --arg alert_number "$alert_number" \
    --arg package_name "$package_name" \
    --arg manifest_path "$manifest_path" \
    --arg patched_version "$patched_version" \
    --arg advisory_summary "$advisory_summary" \
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
      alert_number: $alert_number,
      package_name: $package_name,
      manifest_path: $manifest_path,
      patched_version: $patched_version,
      advisory_summary: $advisory_summary,
      branch: $branch,
      wt_path: $wt_path,
      pr_url: $pr_url,
      session_id: $session_id,
      workflow_step: $workflow_step,
      workflow_detail: {blocker: null, revamp_round: 0},
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
migrate_v1_state_dependabot() {
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
      workflow_detail: (.workflow_detail // {blocker: null, revamp_round: 0}),
      step_history: (.step_history // []),
      updated_at: $updated_at
    }')"
  write_state "$updated" "$wt_path"
  ok "migrated state v1 -> v2 (phase=${phase} -> workflow_step=${workflow_step})"
}

# Reconcile workflow_step with git/PR signals
reconcile_dependabot_state() {
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

# Detect lifecycle state for a dependabot worktree. Sets global variables:
#   _detected_state   — NEW, IMPLEMENT, READY, REVAMP, DONE, CLOSED
#   _detected_detail  — human-readable explanation
#   _detected_pr_state — OPEN, MERGED, CLOSED, or empty
#   _detected_review  — APPROVED, CHANGES_REQUESTED, or empty
detect_dependabot_state() {
  local wt_dir="$1" branch="$2" pr_url="$3" default_br="$4"
  _detected_state="" _detected_detail="" _detected_pr_state="" _detected_review=""

  # Check PR state
  if [[ -n "$pr_url" ]]; then
    local pr_json
    pr_json="$(gh pr view "$pr_url" --json state,reviewDecision 2>/dev/null)" || pr_json=""
    if [[ -n "$pr_json" ]]; then
      _detected_pr_state="$(printf '%s' "$pr_json" | jq -r '.state')"
      _detected_review="$(printf '%s' "$pr_json" | jq -r '.reviewDecision // ""')"
    fi
  fi

  # Fallback: check branch merge status even without PR URL
  if [[ "$_detected_pr_state" != "MERGED" ]] && is_branch_merged "$branch"; then
    _detected_pr_state="MERGED"
  fi

  if [[ -n "$_detected_pr_state" ]]; then
    case "$_detected_pr_state" in
      MERGED)
        _detected_state="DONE"
        _detected_detail="PR merged"
        ;;
      CLOSED)
        _detected_state="CLOSED"
        _detected_detail="PR closed without merge"
        ;;
      OPEN)
        case "$_detected_review" in
          CHANGES_REQUESTED)
            _detected_state="REVAMP"
            _detected_detail="changes requested"
            ;;
          APPROVED)
            _detected_state="READY"
            _detected_detail="approved, merge-ready"
            ;;
          *)
            _detected_state="READY"
            _detected_detail="awaiting review"
            ;;
        esac
        ;;
    esac
  else
    # No PR — check branch for commits/changes
    local commit_count dirty
    commit_count="$(git -C "$wt_dir" rev-list --count "${default_br}..${branch}" 2>/dev/null)" || commit_count="0"
    dirty="$(git -C "$wt_dir" status --porcelain 2>/dev/null)" || dirty=""
    if [[ "$commit_count" -gt 0 ]] || [[ -n "$dirty" ]]; then
      _detected_state="IMPLEMENT"
      _detected_detail="in progress (${commit_count} commits)"
      if [[ -n "$dirty" ]]; then
        _detected_detail="${_detected_detail}, uncommitted changes"
      fi
    else
      _detected_state="IMPLEMENT"
      _detected_detail="no work started"
    fi
  fi
}

# ── Subcommands ──────────────────────────────────────────────────────────────

cmd_setup() {
  local alert_number="${1:?usage: dependabot setup <alert-number>}"

  info "fetching alert #${alert_number} metadata..."
  local alert_json
  alert_json="$(fetch_alert "$alert_number")"

  local alert_state
  alert_state="$(printf '%s' "$alert_json" | jq -r '.state')"
  if [[ "$alert_state" != "open" ]]; then
    json_error "alert #${alert_number} is ${alert_state}, not open"
  fi

  local package_name manifest_path patched_version advisory_summary
  package_name="$(printf '%s' "$alert_json" | jq -r '.dependency.package.name')"
  manifest_path="$(printf '%s' "$alert_json" | jq -r '.dependency.manifest_path')"
  patched_version="$(printf '%s' "$alert_json" | jq -r '.security_vulnerability.first_patched_version.identifier // "unknown"')"
  advisory_summary="$(printf '%s' "$alert_json" | jq -r '.security_advisory.summary')"
  ok "fetched: ${package_name} - ${advisory_summary}"

  local pkg_slug
  pkg_slug="$(slugify "$package_name")"
  local branch_name="security/${alert_number}-${pkg_slug}"
  local wt_path
  wt_path="$(worktree_base)/dependabot-${alert_number}-${pkg_slug}"

  if [[ -d "$wt_path" ]]; then
    json_error "worktree already exists at ${wt_path} -- use 'dependabot status ${alert_number}' to check state"
  fi

  fetch_remote
  assert_clean_tree

  ok "branch: ${branch_name}"

  mkdir -p "$(dirname "$wt_path")"
  git worktree add --no-checkout "$wt_path" -b "$branch_name"
  register_cleanup "$wt_path"
  checkout_and_unlock "$wt_path"

  create_dependabot_state "$branch_name" "$wt_path" "$alert_number" \
    "$package_name" "$manifest_path" "$patched_version" "$advisory_summary"

  # Store full alert JSON for context
  printf '%s' "$alert_json" | jq '.' >"${wt_path}/.dependabot-alert.json"
  ok "alert context saved"

  # Disable cleanup trap -- worktree must survive
  _WT_CLEANUP_PATH=""

  ok "worktree created at ${wt_path}"

  json_ok "$(jq -n \
    --arg alert_number "$alert_number" \
    --arg package_name "$package_name" \
    --arg manifest_path "$manifest_path" \
    --arg patched_version "$patched_version" \
    --arg advisory_summary "$advisory_summary" \
    --arg branch "$branch_name" \
    --arg worktree "$wt_path" \
    '{alert_number: ($alert_number|tonumber), package_name: $package_name,
      manifest_path: $manifest_path, patched_version: $patched_version,
      advisory_summary: $advisory_summary, branch: $branch,
      worktree: $worktree, workflow_step: "implement"}')"
}

cmd_status() {
  local alert_number="${1:?usage: dependabot status <alert-number>}"

  local wt_path
  wt_path="$(find_dependabot_worktree "$alert_number")"

  # No worktree -> NEW
  if [[ -z "$wt_path" ]]; then
    json_ok "$(jq -n \
      --arg alert_number "$alert_number" \
      '{alert_number: ($alert_number|tonumber), state: "NEW", detail: "no worktree exists",
        worktree: null, branch: null, workflow_step: null, workflow_detail: null,
        step_history: [], package_name: null, advisory_summary: null, pr: null}')"
    return
  fi

  local state_file="${wt_path}/.worktree-state.json"
  if [[ ! -f "$state_file" ]]; then
    json_error "worktree exists but no state file at ${state_file}"
  fi

  # Migrate v1 -> v2 if needed
  migrate_v1_state_dependabot "$wt_path"

  local branch pr_url package_name advisory_summary workflow_step workflow_detail step_history
  branch="$(jq -r '.branch' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"
  package_name="$(jq -r '.package_name' "$state_file")"
  advisory_summary="$(jq -r '.advisory_summary' "$state_file")"
  workflow_step="$(jq -r '.workflow_step' "$state_file")"
  workflow_detail="$(jq -c '.workflow_detail // {}' "$state_file")"
  step_history="$(jq -c '.step_history // []' "$state_file")"

  local default_br
  default_br="$(default_branch)"

  # Reconcile state with external signals
  reconcile_dependabot_state "$wt_path" "$branch" "$pr_url" "$default_br"

  # Re-read after reconciliation (may have changed)
  workflow_step="$(jq -r '.workflow_step' "$state_file")"
  workflow_detail="$(jq -c '.workflow_detail // {}' "$state_file")"
  step_history="$(jq -c '.step_history // []' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"

  # Run state detection for the state/detail fields
  detect_dependabot_state "$wt_path" "$branch" "$pr_url" "$default_br"

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
    --arg alert_number "$alert_number" \
    --arg state "$_detected_state" \
    --arg detail "$_detected_detail" \
    --arg worktree "$wt_path" \
    --arg branch "$branch" \
    --arg workflow_step "$workflow_step" \
    --argjson workflow_detail "$workflow_detail" \
    --argjson step_history "$step_history" \
    --arg package_name "$package_name" \
    --arg advisory_summary "$advisory_summary" \
    --argjson pr "$pr_obj" \
    '{alert_number: ($alert_number|tonumber), state: $state, detail: $detail,
      worktree: $worktree, branch: $branch, workflow_step: $workflow_step,
      workflow_detail: $workflow_detail, step_history: $step_history,
      package_name: $package_name, advisory_summary: $advisory_summary, pr: $pr}')"
}

cmd_push() {
  local alert_number="${1:?usage: dependabot push <alert-number>}"

  local wt_path
  wt_path="$(find_dependabot_worktree "$alert_number")"

  if [[ -z "$wt_path" ]]; then
    json_error "no worktree for alert #${alert_number}"
  fi

  local branch pr_url package_name advisory_summary default_br
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  package_name="$(read_state_field package_name "$wt_path")"
  advisory_summary="$(read_state_field advisory_summary "$wt_path")"
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

    local pr_title
    pr_title="$(printf 'security(%s): fix %s' "$package_name" "$advisory_summary")"
    # Truncate to 72 chars for clean PR titles
    if [[ ${#pr_title} -gt 72 ]]; then
      pr_title="${pr_title:0:69}..."
    fi

    local commit_log pr_body
    commit_log="$(git -C "$wt_path" log --format='- %s%n%w(0,2,2)%b' "${default_br}..${branch}")"
    pr_body="$(printf '## Summary\nFixes Dependabot alert #%s\n- Package: %s\n- %s\n\n%s' \
      "$alert_number" "$package_name" "$advisory_summary" "$commit_log")"

    pr_url="$(cd "$wt_path" && gh pr create \
      --title "$pr_title" \
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
    --arg alert_number "$alert_number" \
    --arg action "$action" \
    --arg pr_url "$pr_url" \
    --arg branch "$branch" \
    --argjson commits "$commit_count" \
    --arg ci_status "$ci_status" \
    '{alert_number: ($alert_number|tonumber), action: $action, pr_url: $pr_url,
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
    [[ "$wt_type" == "dependabot" ]] || continue

    # Migrate v1 if needed
    migrate_v1_state_dependabot "$wt_dir"

    local alert_num package_name advisory_summary branch pr_url workflow_step
    alert_num="$(jq -r '.alert_number' "$state_file")"
    package_name="$(jq -r '.package_name' "$state_file")"
    advisory_summary="$(jq -r '.advisory_summary' "$state_file")"
    branch="$(jq -r '.branch' "$state_file")"
    pr_url="$(jq -r '.pr_url // ""' "$state_file")"
    workflow_step="$(jq -r '.workflow_step' "$state_file")"

    detect_dependabot_state "$wt_dir" "$branch" "$pr_url" "$default_br"

    results="$(printf '%s' "$results" | jq \
      --arg num "$alert_num" \
      --arg package_name "$package_name" \
      --arg advisory_summary "$advisory_summary" \
      --arg state "$_detected_state" \
      --arg detail "$_detected_detail" \
      --arg branch "$branch" \
      --arg pr_url "$pr_url" \
      --arg worktree "$wt_dir" \
      --arg workflow_step "$workflow_step" \
      '. + [{alert_number: ($num|tonumber), package_name: $package_name,
              advisory_summary: $advisory_summary, state: $state,
              detail: $detail, branch: $branch,
              pr_url: (if $pr_url == "" then null else $pr_url end),
              worktree: $worktree, workflow_step: $workflow_step}]')"
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name 'dependabot-*' -print0 2>/dev/null)

  json_ok "$results"
}

cmd_cleanup() {
  local alert_number="${1:?usage: dependabot cleanup <alert-number>}"

  local wt_path
  wt_path="$(find_dependabot_worktree "$alert_number")"

  if [[ -z "$wt_path" ]]; then
    json_error "no worktree for alert #${alert_number}"
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

  # Dismiss the Dependabot alert
  gh api "repos/{owner}/{repo}/dependabot/alerts/${alert_number}" \
    -X PATCH -f state=dismissed -f dismissed_reason=fix_started \
    -f dismissed_comment="Fixed via PR" 2>/dev/null || true
  ok "alert dismissed"

  json_ok "$(jq -n \
    --arg alert_number "$alert_number" \
    --arg branch "$branch" \
    --arg pr_url "$pr_url" \
    '{alert_number: ($alert_number|tonumber), cleaned: true, branch: $branch,
      pr_url: (if $pr_url == "" then null else $pr_url end)}')"
}

cmd_transition() {
  local alert_number="${1:?usage: dependabot transition <alert-number> <step> [--detail-json '<json>']}"
  local new_step="${2:?usage: dependabot transition <alert-number> <step>}"
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
  wt_path="$(find_dependabot_worktree "$alert_number")"

  if [[ -z "$wt_path" ]]; then
    json_error "no worktree for alert #${alert_number}"
  fi

  local state_file="${wt_path}/.worktree-state.json"
  if [[ ! -f "$state_file" ]]; then
    json_error "worktree exists but no state file"
  fi

  # Migrate v1 if needed
  migrate_v1_state_dependabot "$wt_path"

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
    --arg alert_number "$alert_number" \
    --arg previous_step "$current_step" \
    --arg current_step "$new_step" \
    --arg updated_at "$timestamp" \
    '{alert_number: ($alert_number|tonumber), previous_step: $previous_step,
      current_step: $current_step, updated_at: $updated_at}')"
}

cmd_validate_cwd() {
  local alert_number="${1:?usage: dependabot validate-cwd <alert-number>}"

  local wt_path
  wt_path="$(find_dependabot_worktree "$alert_number")"

  if [[ -z "$wt_path" ]]; then
    json_error "no worktree for alert #${alert_number}"
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
    die "usage: dependabot <subcommand> [args] -- run 'dependabot --help' for details"
    ;;
esac
