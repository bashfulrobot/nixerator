# github-issue: subcommand library for GitHub issue worktree workflows
# Pure JSON output. No TUI, no interactive mode, no launching Claude.
# The skill (SKILL.md) is the sole orchestrator — this script is its hands.

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: github-issue <subcommand> [args]"
  info ""
  info "Subcommands:"
  info "  setup <number> [--base <ref>]           -- create worktree pinned to base (default origin/main)"
  info "  status <number>                         -- detect lifecycle state"
  info "  push <number>                           -- silent pre-push rebase, push branch, create/update PR, propagate labels"
  info "  auto-merge <number>                     -- enable GitHub auto-merge (squash) on the PR"
  info "  audit                                   -- scan worktrees, surface overlap and blocker-ordered merge queue"
  info "  cleanup <number>                        -- remove worktree + branches, rebase overlapping worktrees"
  info "  transition <number> <step> --note '...' [--detail-json '<json>']"
  info "                                          -- advance workflow state (note is required)"
  info "  validate-cwd <number>                   -- check working directory"
  info "  check-ci <number>                       -- check PR CI status"
  info "  review-feedback <number>                -- fetch PR review comments"
  info "  post-mortem <number>                    -- gather close-context for agent synthesis"
  exit 0
fi

# ── State v3 constants ────────────────────────────────────────────────────────

VALID_STEPS=(setup assess design plan implement verify push review_dev review_security waiting revamp ci_fix "done" closed)

# Transition whitelist: from -> space-separated valid targets
# ci_fix is post-push CI failure (distinct from revamp which is review feedback)
declare -A VALID_TRANSITIONS=(
  [setup]="assess"
  [assess]="design plan implement"
  [design]="plan"
  [plan]="implement"
  [implement]="verify"
  [verify]="implement push waiting"
  [push]="review_dev ci_fix waiting"
  [review_dev]="review_security"
  [review_security]="waiting"
  [waiting]="done revamp ci_fix closed"
  [revamp]="verify"
  [ci_fix]="verify"
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

# ── State v3 helpers ─────────────────────────────────────────────────────────

create_issue_state() {
  local branch="$1"
  local wt_path="$2"
  local issue_number="$3"
  local issue_title="$4"
  local issue_body="$5"
  local base_ref="$6"
  local blockers_json="${7:-[]}"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local json
  json="$(jq -n \
    --argjson version 3 \
    --arg type "issue" \
    --arg issue_number "$issue_number" \
    --arg issue_title "$issue_title" \
    --arg issue_body "$issue_body" \
    --arg branch "$branch" \
    --arg base_ref "$base_ref" \
    --arg wt_path "$wt_path" \
    --arg pr_url "" \
    --arg session_id "" \
    --arg workflow_step "assess" \
    --argjson blockers "$blockers_json" \
    --arg started_at "$timestamp" \
    --arg updated_at "$timestamp" \
    '{
      version: $version,
      type: $type,
      issue_number: $issue_number,
      issue_title: $issue_title,
      issue_body: $issue_body,
      branch: $branch,
      base_ref: $base_ref,
      wt_path: $wt_path,
      pr_url: $pr_url,
      session_id: $session_id,
      workflow_step: $workflow_step,
      workflow_detail: {complexity: null, plan_file: null, review_stage: null, revamp_round: 0, blockers: $blockers, open_threads: []},
      step_history: [{step: "setup", completed_at: $started_at, note: "Worktree created from \($base_ref)."}],
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

# Migrate state files forward: v1 (no version) -> v2 -> v3.
# v1 lacks `version`; v2 has version=2; v3 has version=3 plus base_ref, per-step
# notes, workflow_detail.blockers (array), workflow_detail.open_threads.
migrate_state() {
  local wt_path="$1"
  local state_file="${wt_path}/.worktree-state.json"

  local version
  version="$(jq -r '.version // empty' "$state_file" 2>/dev/null)" || version=""

  # v1 -> v2: synthesize version+workflow_step from legacy phase
  if [[ -z "$version" ]]; then
    local phase
    phase="$(jq -r '.phase // "setup"' "$state_file")"
    local workflow_step
    case "$phase" in
      setup) workflow_step="assess" ;;
      claude_running | claude_exited) workflow_step="implement" ;;
      pushing) workflow_step="push" ;;
      pr_created) workflow_step="waiting" ;;
      *) workflow_step="assess" ;;
    esac

    local timestamp current updated
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
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
    version="2"
  fi

  # v2 -> v3: add base_ref (inferred from default branch), open_threads,
  # migrate scalar `blocker` -> `blockers` array, backfill empty notes.
  if [[ "$version" == "2" ]]; then
    local default_br
    default_br="$(default_branch)"
    local inferred_base="origin/${default_br}"

    local timestamp current updated
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    current="$(cat "$state_file")"
    updated="$(printf '%s' "$current" | jq \
      --argjson version 3 \
      --arg base_ref "$inferred_base" \
      --arg updated_at "$timestamp" \
      '. + {
        version: $version,
        base_ref: (.base_ref // $base_ref),
        workflow_detail: (
          (.workflow_detail // {})
          | (
              if has("blocker") and (.blocker != null)
              then . + {blockers: [.blocker]}
              else . + {blockers: (.blockers // [])}
              end
            )
          | . + {open_threads: (.open_threads // [])}
          | del(.blocker)
        ),
        step_history: ((.step_history // []) | map(. + {note: (.note // "")})),
        updated_at: $updated_at
      }')"
    write_state "$updated" "$wt_path"
    ok "migrated state v2 -> v3 (added base_ref=${inferred_base}, blockers array, open_threads, per-step notes)"
  fi
}

# Back-compat shim for any callers still using the v1-named helper.
migrate_v1_state() { migrate_state "$@"; }

# Reconcile workflow_step with git/PR/CI signals. Returns nothing; mutates state.
# Signals handled:
#   - PR merged -> done
#   - PR closed without merge -> closed
#   - PR open + changes_requested (from waiting) -> revamp
#   - PR open + CI failing (from waiting/push/review_*) -> ci_fix
#   - commits exist but step pre-implementation -> implement
#   - PR exists but step still push -> review_dev
reconcile_state() {
  local wt_path="$1" branch="$2" pr_url="$3" default_br="$4"
  local state_file="${wt_path}/.worktree-state.json"
  local workflow_step base_ref
  workflow_step="$(jq -r '.workflow_step' "$state_file")"
  base_ref="$(jq -r '.base_ref // empty' "$state_file")"
  [[ -z "$base_ref" ]] && base_ref="origin/${default_br}"

  local new_step=""
  local reconcile_note=""

  if [[ -n "$pr_url" ]]; then
    local pr_state
    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null)" || pr_state=""

    case "$pr_state" in
      MERGED)
        if [[ "$workflow_step" != "done" ]]; then
          new_step="done"
          reconcile_note="PR merged."
        fi
        ;;
      CLOSED)
        if [[ "$workflow_step" != "closed" ]]; then
          new_step="closed"
          reconcile_note="PR closed without merge."
        fi
        ;;
      OPEN)
        local review ci_conclusion
        review="$(gh pr view "$pr_url" --json reviewDecision --jq '.reviewDecision // ""' 2>/dev/null)" || review=""
        ci_conclusion="$(detect_ci_conclusion "$pr_url")"

        if [[ "$ci_conclusion" == "failing" ]] && [[ "$workflow_step" == "waiting" || "$workflow_step" == "push" || "$workflow_step" == "review_dev" || "$workflow_step" == "review_security" ]]; then
          new_step="ci_fix"
          reconcile_note="CI failing on PR — routed to ci_fix."
        elif [[ "$review" == "CHANGES_REQUESTED" ]] && [[ "$workflow_step" == "waiting" ]]; then
          new_step="revamp"
          reconcile_note="Reviewer requested changes — routed to revamp."
        fi
        ;;
    esac
  else
    if is_branch_merged "$branch"; then
      if [[ "$workflow_step" != "done" ]]; then
        new_step="done"
        reconcile_note="Branch merged to ${default_br}."
      fi
    fi
  fi

  # Commits exist but step says pre-implementation
  if [[ -z "$new_step" ]] && { [[ "$workflow_step" == "plan" ]] || [[ "$workflow_step" == "assess" ]] || [[ "$workflow_step" == "design" ]]; }; then
    local commit_count
    commit_count="$(git -C "$wt_path" rev-list --count "${default_br}..${branch}" 2>/dev/null)" || commit_count="0"
    if [[ "$commit_count" -gt 0 ]]; then
      new_step="implement"
      reconcile_note="Commits detected — advanced to implement."
    fi
  fi

  # PR exists but step says push
  if [[ -z "$new_step" ]] && [[ "$workflow_step" == "push" ]] && [[ -n "$pr_url" ]]; then
    new_step="review_dev"
    reconcile_note="PR created — advanced to review_dev."
  fi

  if [[ -n "$new_step" ]]; then
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    local current updated
    current="$(cat "$state_file")"
    updated="$(printf '%s' "$current" | jq \
      --arg step "$new_step" \
      --arg t "$timestamp" \
      --arg note "$reconcile_note" \
      '.workflow_step = $step | .updated_at = $t |
       .step_history = .step_history + [{step: $step, completed_at: $t, reconciled: true, note: $note}]')"
    write_state "$updated" "$wt_path"
    ok "reconciled workflow_step: ${workflow_step} -> ${new_step}"
  fi
}

# Summarize PR CI state as "passing" | "failing" | "pending" | "none".
detect_ci_conclusion() {
  local pr_url="$1"
  local checks_json
  checks_json="$(gh pr checks "$pr_url" --json state,conclusion 2>/dev/null)" || checks_json="[]"
  local total failing pending passing
  total="$(printf '%s' "$checks_json" | jq 'length')"
  if [[ "$total" -eq 0 ]]; then
    printf 'none'
    return
  fi
  failing="$(printf '%s' "$checks_json" | jq '[.[] | select(.conclusion == "FAILURE" or .conclusion == "ERROR")] | length')"
  pending="$(printf '%s' "$checks_json" | jq '[.[] | select(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS")] | length')"
  passing="$(printf '%s' "$checks_json" | jq '[.[] | select(.conclusion == "SUCCESS" or .conclusion == "NEUTRAL")] | length')"
  if [[ "$failing" -gt 0 ]]; then
    printf 'failing'
  elif [[ "$pending" -gt 0 ]]; then
    printf 'pending'
  elif [[ "$passing" -eq "$total" ]]; then
    printf 'passing'
  else
    printf 'none'
  fi
}

# ── Subcommands ──────────────────────────────────────────────────────────────

# Parse blocker references from issue body. Matches "Blocked by #N",
# "Depends on #N", "Requires #N", "Needs #N" (case-insensitive). For each
# hit, fetches issue state + title via gh. Emits JSON array:
#   [{"number": N, "state": "OPEN"|"CLOSED", "title": "..."}]
# Missing/unreachable issues are skipped silently (offline-safe).
parse_blockers() {
  local body="$1"
  local numbers
  numbers="$(printf '%s' "$body" |
    grep -oiE '(blocked by|depends on|requires|needs)[[:space:]]*#[0-9]+' |
    grep -oE '[0-9]+' |
    sort -u)"

  local result="[]"
  local n entry
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    entry="$(gh issue view "$n" --json number,state,title 2>/dev/null)" || continue
    result="$(printf '%s' "$result" | jq --argjson e "$entry" '. + [$e]')"
  done <<<"$numbers"
  printf '%s' "$result"
}

cmd_setup() {
  local issue_number=""
  local base_ref=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        base_ref="${2:?--base requires a value}"
        shift 2
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        if [[ -z "$issue_number" ]]; then
          issue_number="$1"
          shift
        else
          die "unexpected argument: $1"
        fi
        ;;
    esac
  done
  [[ -n "$issue_number" ]] || die "usage: github-issue setup <issue-number> [--base <ref>]"

  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ -d "$wt_path" ]]; then
    json_error "worktree already exists at ${wt_path} -- use 'github-issue status ${issue_number}' to check state"
  fi

  fetch_remote
  assert_clean_tree

  # Resolve base: default to origin/<default-branch>. Verify it exists.
  local default_br
  default_br="$(default_branch)"
  if [[ -z "$base_ref" ]]; then
    base_ref="origin/${default_br}"
  fi
  git rev-parse --verify --quiet "$base_ref" >/dev/null ||
    die "base ref '${base_ref}' does not resolve -- run 'git fetch origin' or pass a valid --base"
  ok "base: ${base_ref}"

  local issue_json issue_title issue_labels issue_body
  issue_json="$(fetch_issue_metadata "$issue_number")"
  issue_title="$(printf '%s' "$issue_json" | jq -r '.title')"
  issue_labels="$(printf '%s' "$issue_json" | jq -c '.labels')"
  issue_body="$(printf '%s' "$issue_json" | jq -r '.body')"
  ok "fetched: ${issue_title}"

  # Parse blockers. Warn if any are still OPEN but don't block setup — user can
  # proceed knowingly. Blocker state is persisted for use by audit merge-ordering.
  local blockers_json open_blockers_count
  blockers_json="$(parse_blockers "$issue_body")"
  open_blockers_count="$(printf '%s' "$blockers_json" | jq '[.[] | select(.state == "OPEN")] | length')"
  if [[ "$open_blockers_count" -gt 0 ]]; then
    warn "issue #${issue_number} references ${open_blockers_count} open blocker(s):"
    while IFS= read -r line; do
      [[ -n "$line" ]] && warn "  ${line}"
    done < <(printf '%s' "$blockers_json" | jq -r '.[] | select(.state == "OPEN") | "#\(.number) [\(.state)] \(.title)"')
  fi

  local branch_type
  branch_type="$(derive_branch_type_auto "$issue_labels")"
  ok "branch type: ${branch_type}"

  local branch_name
  branch_name="$(build_branch_name "$branch_type" "$issue_number" "$issue_title")"
  ok "branch: ${branch_name}"

  mkdir -p "$(dirname "$wt_path")"
  # Pin branch explicitly to base_ref so the new branch never inherits an
  # accidental stack from whatever HEAD happened to be when this ran.
  git worktree add --no-checkout "$wt_path" -b "$branch_name" "$base_ref"
  register_cleanup "$wt_path"
  checkout_and_unlock "$wt_path"
  create_issue_state "$branch_name" "$wt_path" "$issue_number" "$issue_title" "$issue_body" "$base_ref" "$blockers_json"
  _WT_CLEANUP_PATH=""
  ok "worktree created at ${wt_path}"

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg branch "$branch_name" \
    --arg base_ref "$base_ref" \
    --arg worktree "$wt_path" \
    --arg branch_type "$branch_type" \
    --arg title "$issue_title" \
    --arg issue_body "$issue_body" \
    --argjson blockers "$blockers_json" \
    '{issue_number: ($issue_number|tonumber), branch: $branch, base_ref: $base_ref, worktree: $worktree,
      branch_type: $branch_type, title: $title, issue_body: $issue_body,
      blockers: $blockers, workflow_step: "assess"}')"
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

  # Migrate to current schema version if needed.
  migrate_state "$wt_path"

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

  migrate_state "$wt_path"

  local branch pr_url issue_title default_br base_ref issue_labels
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  issue_title="$(read_state_field issue_title "$wt_path")"
  default_br="$(default_branch)"
  base_ref="$(jq -r '.base_ref // empty' "${wt_path}/.worktree-state.json")"
  [[ -z "$base_ref" ]] && base_ref="origin/${default_br}"

  # Silent pre-push rebase. Refresh base, check whether we're already ahead of
  # it, and rebase only when needed. A successful rebase makes later pushes
  # non-fast-forward, so we switch to --force-with-lease for PR updates.
  fetch_remote
  local rebased=0
  if ! git -C "$wt_path" merge-base --is-ancestor "$base_ref" "$branch" 2>/dev/null; then
    info "rebasing ${branch} onto ${base_ref}..."
    if ! git -C "$wt_path" rebase "$base_ref" >&2; then
      git -C "$wt_path" rebase --abort 2>/dev/null || true
      json_error "rebase onto ${base_ref} produced conflicts -- agent must resolve. Run 'git -C ${wt_path} rebase ${base_ref}' and address conflicts before retrying push."
    fi
    rebased=1
    ok "rebased onto ${base_ref}"
  fi

  # commits-vs-base check (not commits-vs-default; base may differ in future)
  local commit_count
  commit_count="$(git -C "$wt_path" rev-list --count "${base_ref}..${branch}")"
  if [[ "$commit_count" -eq 0 ]]; then
    json_error "no commits on branch ${branch} relative to ${base_ref} -- nothing to push"
  fi

  local action=""
  if [[ -z "$pr_url" ]]; then
    (cd "$wt_path" && safe_push "$branch")
    ok "branch pushed"

    local commit_log pr_body
    commit_log="$(git -C "$wt_path" log --format='- %s%n%w(0,2,2)%b' "${base_ref}..${branch}")"
    pr_body="$(printf '## Summary\nCloses #%s: %s\n\n%s' "$issue_number" "$issue_title" "$commit_log")"

    pr_url="$(cd "$wt_path" && gh pr create \
      --title "$issue_title" \
      --body "$pr_body" \
      --head "$branch")"
    ok "PR created: ${pr_url}"

    # Propagate issue labels to PR. Safe no-op when the issue has none.
    issue_labels="$(gh issue view "$issue_number" --json labels --jq '[.labels[].name]' 2>/dev/null)" || issue_labels="[]"
    local label_count
    label_count="$(printf '%s' "$issue_labels" | jq 'length')"
    if [[ "$label_count" -gt 0 ]]; then
      local label_args=()
      while IFS= read -r name; do
        [[ -n "$name" ]] && label_args+=(--add-label "$name")
      done < <(printf '%s' "$issue_labels" | jq -r '.[]')
      gh pr edit "$pr_url" "${label_args[@]}" >/dev/null 2>&1 || warn "could not apply some labels to PR"
      ok "propagated ${label_count} label(s) from issue to PR"
    fi

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
    # Rebasing rewrites history, so subsequent pushes to an existing PR branch
    # require --force-with-lease. Never --force — avoids clobbering concurrent
    # updates pushed from elsewhere.
    if [[ "$rebased" -eq 1 ]]; then
      (cd "$wt_path" && assert_not_main && git push --force-with-lease origin "$branch")
    else
      (cd "$wt_path" && assert_not_main && git push origin "$branch")
    fi
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

# Compute the set of files changed on branch vs. its base. Used by audit to
# surface cross-worktree overlap. Emits newline-delimited paths; empty on
# offline/error.
branch_touched_files() {
  local wt_dir="$1" branch="$2" base_ref="$3"
  git -C "$wt_dir" diff "${base_ref}...${branch}" --name-only 2>/dev/null || true
}

cmd_audit() {
  fetch_remote

  local wt_base
  wt_base="$(worktree_base)"

  if [[ ! -d "$wt_base" ]]; then
    json_ok '{"worktrees": [], "overlaps": [], "merge_order": []}'
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

    migrate_state "$wt_dir"

    local issue_num issue_title branch pr_url workflow_step base_ref blockers
    issue_num="$(jq -r '.issue_number' "$state_file")"
    issue_title="$(jq -r '.issue_title' "$state_file")"
    branch="$(jq -r '.branch' "$state_file")"
    pr_url="$(jq -r '.pr_url // ""' "$state_file")"
    workflow_step="$(jq -r '.workflow_step' "$state_file")"
    base_ref="$(jq -r '.base_ref // empty' "$state_file")"
    [[ -z "$base_ref" ]] && base_ref="origin/${default_br}"
    blockers="$(jq -c '.workflow_detail.blockers // []' "$state_file")"

    detect_issue_state "$wt_dir" "$branch" "$pr_url" "$default_br"

    # Collect touched-file list for overlap pass below.
    local touched_files_json
    touched_files_json="$(branch_touched_files "$wt_dir" "$branch" "$base_ref" |
      jq -Rsc 'split("\n") | map(select(length > 0))')"

    results="$(printf '%s' "$results" | jq \
      --arg num "$issue_num" \
      --arg title "$issue_title" \
      --arg state "$_detected_state" \
      --arg detail "$_detected_detail" \
      --arg branch "$branch" \
      --arg base_ref "$base_ref" \
      --arg pr_url "$pr_url" \
      --arg worktree "$wt_dir" \
      --arg workflow_step "$workflow_step" \
      --argjson blockers "$blockers" \
      --argjson touched "$touched_files_json" \
      '. + [{issue_number: ($num|tonumber), title: $title, state: $state,
              detail: $detail, branch: $branch, base_ref: $base_ref,
              pr_url: (if $pr_url == "" then null else $pr_url end),
              worktree: $worktree, workflow_step: $workflow_step,
              blockers: $blockers, touched_files: $touched}]')"
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name 'issue-*' -print0 2>/dev/null)

  # Overlap pass: every pair of active worktrees that share >=1 touched file.
  # Surfaces merge-conflict risk before it materializes.
  local overlaps
  overlaps="$(printf '%s' "$results" | jq '
    [
      . as $all
      | range(0; length) as $i
      | range($i+1; length) as $j
      | {
          a: $all[$i].issue_number,
          b: $all[$j].issue_number,
          shared: (($all[$i].touched_files // []) - (($all[$i].touched_files // []) - ($all[$j].touched_files // [])))
        }
      | select((.shared | length) > 0)
    ]
  ')"

  # Merge-ordering: take worktrees whose PR is mergeable (waiting or
  # review_security with an open PR), annotate each with the set of peer
  # issues it unblocks, then sort so issues that unblock the most peers
  # merge first. Non-mergeable worktrees are excluded.
  local merge_order
  merge_order="$(printf '%s' "$results" | jq '
    [ .[] | select(.pr_url != null and (.workflow_step == "waiting" or .workflow_step == "review_security")) ]
    | . as $mergeable
    | map(. as $item
          | . + {
              blocks: [
                $mergeable[]
                | select(.blockers | map(.number) | index($item.issue_number))
                | .issue_number
              ]
            })
    | sort_by(-(.blocks | length))
    | map({issue_number, title, pr_url, workflow_step, blocks})
  ')"

  json_ok "$(jq -n \
    --argjson worktrees "$results" \
    --argjson overlaps "$overlaps" \
    --argjson merge_order "$merge_order" \
    '{worktrees: $worktrees, overlaps: $overlaps, merge_order: $merge_order}')"
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
  local issue_number="${1:?usage: github-issue transition <issue-number> <step> --note '...' [--detail-json '<json>']}"
  local new_step="${2:?usage: github-issue transition <issue-number> <step> --note '...'}"
  shift 2

  local detail_json="{}"
  local note=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --detail-json)
        detail_json="${2:?--detail-json requires a value}"
        shift 2
        ;;
      --note)
        note="${2:?--note requires a value}"
        shift 2
        ;;
      *) die "unknown option: $1" ;;
    esac
  done

  # --note is mandatory. Autonomous resume depends on every transition leaving
  # a trail the next agent can read.
  if [[ -z "$note" ]]; then
    json_error "--note '<short summary of what happened>' is required on transition"
  fi

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

  migrate_state "$wt_path"

  local current_step
  current_step="$(jq -r '.workflow_step' "$state_file")"

  if ! is_valid_transition "$current_step" "$new_step"; then
    json_error "invalid transition: ${current_step} -> ${new_step} -- allowed from ${current_step}: ${VALID_TRANSITIONS[$current_step]:-none}"
  fi

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
    --arg note "$note" \
    --argjson detail "$detail_json" \
    '.workflow_step = $step |
     .updated_at = $t |
     .workflow_detail = (.workflow_detail // {}) * $detail |
     .step_history = (.step_history // []) + [{step: $step, completed_at: $t, note: $note}]')"
  write_state "$updated" "$wt_path"

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg previous_step "$current_step" \
    --arg current_step "$new_step" \
    --arg note "$note" \
    --arg updated_at "$timestamp" \
    '{issue_number: ($issue_number|tonumber), previous_step: $previous_step,
      current_step: $current_step, note: $note, updated_at: $updated_at}')"
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

# Enable GitHub-side auto-merge (squash). The merge lands the moment branch
# protection, required reviews, and CI are all satisfied. The skill's state
# machine still polls status; reconciliation detects the merge and routes to
# done.
cmd_auto_merge() {
  local issue_number="${1:?usage: github-issue auto-merge <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  local pr_url
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  if [[ -z "$pr_url" ]] || [[ "$pr_url" == "null" ]]; then
    json_error "no PR exists for issue #${issue_number} -- push first"
  fi

  local enabled="false"
  local message=""
  if gh pr merge "$pr_url" --auto --squash >/dev/null 2>&1; then
    enabled="true"
    message="auto-merge (squash) enabled"
    ok "$message on ${pr_url}"
  else
    # Most common non-error cause: branch protection doesn't allow auto-merge,
    # or PR is already mergeable and gh would need --merge instead.
    local pr_state
    pr_state="$(gh pr view "$pr_url" --json state,mergeStateStatus 2>/dev/null)" || pr_state="{}"
    message="could not enable auto-merge ($(printf '%s' "$pr_state" | jq -r '.mergeStateStatus // "unknown"'))"
    warn "$message"
  fi

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg pr_url "$pr_url" \
    --arg enabled "$enabled" \
    --arg message "$message" \
    '{issue_number: ($issue_number|tonumber), pr_url: $pr_url,
      auto_merge_enabled: ($enabled == "true"), message: $message}')"
}

# Gather close-context for agent synthesis of a post-mortem comment.
# Returns PR state, review summary (latest reviews + inline comments), CI
# history at close, commit log, and last few step_history notes. The skill
# then writes a short comment on the issue.
cmd_post_mortem() {
  local issue_number="${1:?usage: github-issue post-mortem <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  migrate_state "$wt_path"

  local state_file="${wt_path}/.worktree-state.json"
  local branch pr_url base_ref workflow_step
  branch="$(jq -r '.branch' "$state_file")"
  pr_url="$(jq -r '.pr_url // ""' "$state_file")"
  base_ref="$(jq -r '.base_ref // empty' "$state_file")"
  workflow_step="$(jq -r '.workflow_step' "$state_file")"

  local default_br
  default_br="$(default_branch)"
  [[ -z "$base_ref" ]] && base_ref="origin/${default_br}"

  local pr_json reviews inline_comments checks commits step_notes
  if [[ -n "$pr_url" ]]; then
    pr_json="$(gh pr view "$pr_url" --json state,title,url,author,mergeStateStatus,closedAt,updatedAt 2>/dev/null)" || pr_json="{}"
    local pr_number repo_path
    pr_number="$(printf '%s' "$pr_url" | grep -oE '[0-9]+$' || echo "")"
    repo_path="$(printf '%s' "$pr_url" | sed 's|https://github.com/||; s|/pull/[0-9]*$||')"
    reviews="$(gh api "repos/${repo_path}/pulls/${pr_number}/reviews" \
      --jq '[.[] | {state, body, author: .user.login, submitted_at}]' 2>/dev/null)" || reviews="[]"
    inline_comments="$(gh api "repos/${repo_path}/pulls/${pr_number}/comments" \
      --jq '[.[] | {path, line: (.line // .original_line), body, author: .user.login}]' 2>/dev/null)" || inline_comments="[]"
    checks="$(gh pr checks "$pr_url" --json name,state,conclusion 2>/dev/null)" || checks="[]"
  else
    pr_json="{}"
    reviews="[]"
    inline_comments="[]"
    checks="[]"
  fi

  commits="$(git -C "$wt_path" log --format='%H%x09%s' "${base_ref}..${branch}" 2>/dev/null |
    jq -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {sha: .[0], subject: .[1]})')" ||
    commits="[]"
  step_notes="$(jq -c '[.step_history[-10:][] | {step, completed_at, note}]' "$state_file")"

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg pr_url "$pr_url" \
    --arg workflow_step "$workflow_step" \
    --argjson pr "$pr_json" \
    --argjson reviews "$reviews" \
    --argjson inline_comments "$inline_comments" \
    --argjson checks "$checks" \
    --argjson commits "$commits" \
    --argjson step_notes "$step_notes" \
    '{issue_number: ($issue_number|tonumber), pr_url: (if $pr_url == "" then null else $pr_url end),
      workflow_step: $workflow_step, pr: $pr, reviews: $reviews,
      inline_comments: $inline_comments, checks: $checks, commits: $commits,
      recent_step_notes: $step_notes}')"
}

# ── Entry point ──────────────────────────────────────────────────────────────

case "${1:-}" in
  setup | status | push | audit | cleanup | transition | validate-cwd | check-ci | review-feedback | auto-merge | post-mortem)
    _JSON_MODE=1
    SUBCMD="${1//-/_}"
    shift
    "cmd_${SUBCMD}" "$@"
    ;;
  *)
    die "usage: github-issue <subcommand> [args] -- run 'github-issue --help' for details"
    ;;
esac
