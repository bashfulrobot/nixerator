# github-issue: subcommand library for GitHub issue worktree workflows
# Pure JSON output. No TUI, no interactive mode, no launching Claude.
# The skill (SKILL.md) is the sole orchestrator — this script is its hands.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && { [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; }; then
  info "Usage: github-issue <subcommand> [args]"
  info ""
  info "Subcommands:"
  info "  setup <number> [--base <ref>]           -- create worktree pinned to base (default origin/main)"
  info "  resume <number>                         -- re-add a worktree on an existing branch, link its open PR"
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
  info "  verify-landed <pr-number> [--rescue]    -- confirm a merged PR landed on the default branch;"
  info "                                             with --rescue, cherry-pick + push if it didn't"
  info "                                             (use after stacked-PR squash-merge races)"
  info "  post-mortem <number>                    -- gather close-context for agent synthesis"
  info "  queue-state <get|set --json '<json>'|clear>"
  info "                                          -- read/write the github-issues-auto queue cursor (reboot-safe resume)"
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

# github-issue automates GitHub's issue/PR/CI/auto-merge lifecycle end to end,
# and every subcommand shells out to `gh`, which only speaks to GitHub. On a
# Forgejo (or any non-GitHub) origin those calls fail confusingly partway
# through, so guard up front with an actionable message. The self-hosted
# Forgejo (git.srvrs.co) is driven manually via the provider-aware `forge`
# helper and the `tea` CLI rather than by this GitHub-specific orchestrator.
require_github_remote() {
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *github.com*) return 0 ;;
  esac
  die "github-issue supports GitHub remotes only (origin: ${url:-none}). Its CI, review, and auto-merge automation is GitHub-specific. For a Forgejo repo, drive the issue by hand: 'forge issue-json <n>' to read it, branch and commit, 'forge pr-create <title> <body> <base> <head>' to open the PR, then review and merge from the Forgejo UI or the 'tea' CLI."
}

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
  # Optional resume params. Fresh setup calls with 6-7 args, so these default to
  # the original hardcoded values (empty pr_url, assess step, "created" note).
  # resume passes a discovered PR URL, an initial step, and a resume note so the
  # state file lands the next push on cmd_push's PR-update path (pr_url non-empty).
  local pr_url="${8:-}"
  local initial_step="${9:-assess}"
  local setup_note="${10:-Worktree created from ${base_ref}.}"
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
    --arg pr_url "$pr_url" \
    --arg session_id "" \
    --arg workflow_step "$initial_step" \
    --argjson blockers "$blockers_json" \
    --arg setup_note "$setup_note" \
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
      step_history: [{step: "setup", completed_at: $started_at, note: $setup_note}],
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

# ── Single-writer worktree lock ─────────────────────────────────────────────
# Prevents two CLI invocations from clobbering the same worktree's state file
# or pushing the same branch concurrently. flock holds the lock for the
# lifetime of fd 9; the kernel releases it on process exit, so an aborted
# process never leaves a stale lock. -n fails fast instead of blocking.
acquire_worktree_lock() {
  local wt_path="$1"
  local lock_file="${wt_path}/.worktree.lock"
  : >"$lock_file" 2>/dev/null || die "cannot create lock file at ${lock_file}"
  exec 9>"$lock_file"
  if ! flock -n 9; then
    local issue_num
    issue_num="$(basename "$wt_path" | sed 's/^issue-//')"
    json_error_obj "$(jq -nc --arg issue "$issue_num" --arg wt "$wt_path" \
      '{message: ("worktree for issue #" + $issue + " is locked by another github-issue process"),
        cause: "worktree_locked",
        issue_number: ($issue|tonumber),
        worktree: $wt}')"
  fi
}

# Setup uses a base-dir lock keyed on issue number, since the worktree dir
# doesn't exist yet at the moment we need mutual exclusion. Uses fd 7 so it
# can coexist with the worktree lock (fd 9) and the auto-refresh try-lock
# (fd 8) without a future caller silently releasing one by reusing the fd.
acquire_setup_lock() {
  local issue_number="$1"
  local wt_base
  wt_base="$(worktree_base)"
  mkdir -p "$wt_base"
  local lock_file="${wt_base}/.setup-issue-${issue_number}.lock"
  : >"$lock_file" 2>/dev/null || die "cannot create setup lock at ${lock_file}"
  exec 7>"$lock_file"
  if ! flock -n 7; then
    json_error_obj "$(jq -nc --arg issue "$issue_number" \
      '{message: ("another setup for issue #" + $issue + " is already in progress"),
        cause: "setup_locked",
        issue_number: ($issue|tonumber)}')"
  fi
}

# Attempt to silently refresh a waiting PR whose merge_state_status is BEHIND
# (main moved forward while the PR sat in auto-merge). Rebases onto base_ref
# and force-with-lease pushes. Quiet on success; logs a step_history entry
# tagged auto_refresh: true. Exit codes are distinct so callers can tell
# "did real work" from "nothing to do" from "tried and failed":
#   0 — refresh applied (rebase and/or push happened)
#   1 — refresh attempted but failed (rebase conflict, push rejected, etc.)
#   2 — no-op (branch already on top of base and remote in sync, or lock
#       held by another process so we skipped)
auto_refresh_behind() {
  local wt_path="$1"
  local branch base_ref state_file
  state_file="${wt_path}/.worktree-state.json"
  branch="$(jq -r '.branch' "$state_file")"
  base_ref="$(jq -r '.base_ref // empty' "$state_file")"
  [[ -z "$base_ref" ]] && base_ref="origin/$(default_branch)"

  # Skip auto-refresh for protected branches — should never happen on a
  # well-formed state file, but defends against corruption.
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    return 1
  fi

  # Lock coordination. Two callers reach us:
  #   (a) cmd_audit, which holds no lock — we acquire our own try-lock on fd 8.
  #   (b) reconcile_state called from cmd_status, which already holds fd 6 on
  #       the same lock file. flock on a second OFD in the same process for
  #       the same file would block forever, so when _GH_OUTER_LOCK matches
  #       this worktree we skip the inner acquire and reuse the outer hold.
  local inner_locked=0
  local lock_file="${wt_path}/.worktree.lock"
  if [[ "${_GH_OUTER_LOCK:-}" != "$wt_path" ]]; then
    : >"$lock_file" 2>/dev/null || return 1
    exec 8>"$lock_file"
    if ! flock -n 8; then
      exec 8>&-
      return 2
    fi
    inner_locked=1
  fi

  local did_rebase=0 did_push=0 rc=0
  if git -C "$wt_path" merge-base --is-ancestor "$base_ref" "$branch" 2>/dev/null; then
    # Local branch already on top of base. Push only if remote is strictly
    # behind local — i.e., origin/branch is an ancestor of local branch AND
    # the two are not at the same commit. rev-list origin/branch..branch
    # collapses both checks into "are there commits to send?".
    if [[ -n "$(git -C "$wt_path" rev-list "origin/${branch}..${branch}" 2>/dev/null)" ]]; then
      if (cd "$wt_path" && git push --force-with-lease origin "$branch") 2>/dev/null; then
        did_push=1
      else
        rc=1
      fi
    fi
  else
    if git -C "$wt_path" rebase "$base_ref" >/dev/null 2>&1; then
      did_rebase=1
      if (cd "$wt_path" && git push --force-with-lease origin "$branch") 2>/dev/null; then
        did_push=1
      else
        rc=1
      fi
    else
      git -C "$wt_path" rebase --abort 2>/dev/null || true
      rc=1
    fi
  fi

  if [[ "$rc" -ne 0 ]]; then
    [[ "$inner_locked" -eq 1 ]] && exec 8>&-
    return 1
  fi

  # Idempotent no-op: nothing actually changed. Don't log a misleading
  # step_history entry; signal "no work" so callers can avoid setting
  # auto_refreshed=true on this worktree.
  if [[ "$did_rebase" -eq 0 ]] && [[ "$did_push" -eq 0 ]]; then
    [[ "$inner_locked" -eq 1 ]] && exec 8>&-
    return 2
  fi

  local timestamp current updated note
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if [[ "$did_rebase" -eq 1 ]]; then
    note="Auto-refreshed: rebased onto ${base_ref} and force-with-lease pushed to clear BEHIND."
  else
    note="Auto-refreshed: force-with-lease pushed local HEAD to remote (already past ${base_ref})."
  fi
  current="$(cat "$state_file")"
  updated="$(printf '%s' "$current" | jq \
    --arg t "$timestamp" \
    --arg note "$note" \
    '.updated_at = $t |
     .step_history = (.step_history // []) + [{step: .workflow_step, completed_at: $t, auto_refresh: true, note: $note}]')"
  write_state "$updated" "$wt_path"
  ok "auto-refreshed PR for ${branch}"
  [[ "$inner_locked" -eq 1 ]] && exec 8>&-
  return 0
}

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
        local review ci_conclusion merge_status
        review="$(gh pr view "$pr_url" --json reviewDecision --jq '.reviewDecision // ""' 2>/dev/null)" || review=""
        ci_conclusion="$(detect_ci_conclusion "$pr_url")"
        merge_status="$(gh pr view "$pr_url" --json mergeStateStatus --jq '.mergeStateStatus // ""' 2>/dev/null)" || merge_status=""

        if [[ "$ci_conclusion" == "failing" ]] && [[ "$workflow_step" == "waiting" || "$workflow_step" == "push" || "$workflow_step" == "review_dev" || "$workflow_step" == "review_security" ]]; then
          new_step="ci_fix"
          reconcile_note="CI failing on PR — routed to ci_fix."
        elif [[ "$review" == "CHANGES_REQUESTED" ]] && [[ "$workflow_step" == "waiting" ]]; then
          new_step="revamp"
          reconcile_note="Reviewer requested changes — routed to revamp."
        elif [[ "$merge_status" == "BEHIND" ]] && [[ "$workflow_step" == "waiting" ]]; then
          # Auto-heal: rebase + force-with-lease push to clear BEHIND so
          # GitHub re-evaluates auto-merge. Stay in waiting. On rebase
          # conflict, leave it alone — surfaces via merge_state_status in
          # the status payload and the agent handles it.
          auto_refresh_behind "$wt_path" || true
        fi
        ;;
    esac
  else
    if is_branch_merged "$branch" "$base_ref"; then
      if [[ "$workflow_step" != "done" ]]; then
        new_step="done"
        reconcile_note="Branch merged to ${base_ref}."
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

# ── Issue-side lease (cross-machine, per-agent claim) ───────────────────────
# The local flock only guards one filesystem. Two agents on different hosts, or
# two checkouts with separate worktree roots, have independent lock namespaces,
# so both could run setup for the same issue. We assert the claim on the issue
# itself, where every agent can see it.
#
# The whole fleet authenticates as ONE GitHub login, so the assignee cannot
# tell two of our agents apart: it is a human-visible hint, not the token. The
# authoritative claim is a per-agent CLAIM COMMENT, and the winner is the claim
# comment with the LOWEST comment id. Comment ids are server-assigned and
# monotonic, so every agent that reads the full comment list computes the same
# winner. (createdAt has only second granularity and would tie, so we never
# order by it.)
#
# There is no atomic compare-and-swap in the GitHub API, so this is not
# perfectly race-free. The lowest-comment-id rule closes the race except for a
# sub-second window bounded by read-your-writes consistency: two agents that
# both post within one API round-trip, then read before the other's comment is
# visible, could each believe they won. The CLAIM_SETTLE_SECS pause shrinks that
# window, and the in-progress label + claim comment + `fleet-status` are the
# human-visible backstop that reconciles a double-claim after the fact. The
# setup flock is per-host: it serialises this machine's own invocations and
# nothing cross-host.
LEASE_LABEL="in-progress"

# Stable marker lines so humans and future tooling can grep the machine
# breadcrumbs. A claim comment carries CLAIM_MARKER; a cede comment carries
# CEDE_MARKER so it is never mistaken for a live claim during winner selection.
CLAIM_MARKER='<!-- worktree-flow:claim -->'
CEDE_MARKER='<!-- worktree-flow:cede -->'

# Seconds to wait after posting our claim before resolving the winner, so a
# near-simultaneous claim from another host lands and becomes visible first.
CLAIM_SETTLE_SECS="${CLAIM_SETTLE_SECS:-2}"

# Set by _lease_precheck: 1 when this host+worktree already owns the sole claim
# comment (a prior setup died before creating the worktree), so _lease_claim
# skips re-posting a duplicate.
_LEASE_REENTRANT=0

# Fetch the issue's claim comments as a compact JSON array of {id, body} (only
# comments carrying CLAIM_MARKER). Uses the REST endpoint so id is the numeric,
# monotonic database id. Emits a structured error (and exits) if the read fails.
_lease_claim_comments() {
  local issue_number="$1" out rc=0
  out="$(gh api "repos/{owner}/{repo}/issues/${issue_number}/comments" --paginate 2>/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    json_error_obj "$(jq -nc --arg issue "$issue_number" \
      '{message: ("could not read comments on issue #" + $issue + " to resolve the claim"),
        cause: "gh_api_failed", issue_number: ($issue|tonumber)}')"
  fi
  printf '%s' "$out" | jq -c --arg m "$CLAIM_MARKER" \
    '[.[] | select(.body | contains($m)) | {id, body}]'
}

# Refuse setup up front when a DIFFERENT user already holds the issue (a cheap
# one-call read that avoids spamming a claim comment on an obvious conflict).
# Also detect the re-entrant case: if the sole existing claim comment is ours
# (same host+worktree), set _LEASE_REENTRANT so _lease_claim skips re-posting.
# A foreign claim comment is NOT refused here; the lowest-comment-id race in
# _lease_claim is the authority for the same-user cross-host case.
_lease_precheck() {
  local issue_number="$1" me="$2" host="$3" wt_path="$4"
  local meta rc=0
  meta="$(gh issue view "$issue_number" --json assignees 2>/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    json_error_obj "$(jq -nc --arg issue "$issue_number" \
      '{message: ("could not read issue #" + $issue + " to precheck the claim"),
        cause: "gh_read_failed", issue_number: ($issue|tonumber)}')"
  fi
  local foreign_owner
  foreign_owner="$(printf '%s' "$meta" |
    jq -r --arg me "$me" '[.assignees[].login | select(. != $me)] | .[0] // empty')"
  if [[ -n "$foreign_owner" ]]; then
    json_error_obj "$(jq -nc --arg issue "$issue_number" --arg owner "$foreign_owner" \
      '{message: ("issue #" + $issue + " is already claimed by @" + $owner),
        cause: "issue_claimed", issue_number: ($issue|tonumber), owner: $owner}')"
  fi

  local claims
  claims="$(_lease_claim_comments "$issue_number")"
  _LEASE_REENTRANT="$(printf '%s' "$claims" | jq -r --arg h "$host" --arg w "$wt_path" '
    def field(k): ((.[0].body | [match(k + ": ([^\n]+)")] | .[0].captures[0].string) // "");
    if (length == 1) and (field("host") == $h) and (field("worktree") == $w)
    then "1" else "0" end')"
}

# Claim the issue with a per-agent comment lease. Adds the assignee + label as
# best-effort human-visible hints, posts a claim comment stamped with our nonce,
# waits a settle interval, then resolves the winner as the lowest-comment-id
# claim. If our nonce won we proceed; otherwise we cede (leaving the shared
# label/assignee for the winner) and refuse with issue_claimed. Every gh call is
# guarded so a failure surfaces a structured error rather than a raw abort.
_lease_claim() {
  local issue_number="$1" branch="$2" wt_path="$3"
  local host="$4" ts="$5" nonce="$6" reentrant="$7"

  # Best-effort hints. Not the CAS: one login across the fleet means the
  # assignee cannot discriminate our agents. Never fail the claim on these.
  gh issue edit "$issue_number" --add-assignee "@me" >/dev/null 2>&1 ||
    warn "could not add self as assignee on issue #${issue_number}"
  gh issue edit "$issue_number" --add-label "$LEASE_LABEL" >/dev/null 2>&1 ||
    warn "could not add '${LEASE_LABEL}' label to issue #${issue_number} (does it exist in the repo?)"

  # Re-entrant resume: _lease_precheck found the SOLE existing claim comment is
  # already ours (same host+worktree) — a prior setup died after claiming but
  # before 'git worktree add', leaving the claim and no worktree dir. The claim
  # is ours, so proceed immediately. We must NOT fall through to the settle +
  # winner logic below: `nonce` is regenerated fresh on every invocation
  # (host::wt::ts::pid), so it can never equal the stale prior claim's nonce,
  # the winner test would fail against our own comment, and we would cede to
  # ourselves — permanently self-locking the resumed task. Return 0 (claim
  # held), post no new claim comment, run no cede logic.
  if [[ "$reentrant" == "1" ]]; then
    return 0
  fi

  local body
  body="$(printf 'Claimed for work.\n\n%s\nclaim-id: %s\nhost: %s\nworktree: %s\nclaimed-at: %s\nbranch: %s' \
    "$CLAIM_MARKER" "$nonce" "$host" "$wt_path" "$ts" "$branch")"
  gh issue comment "$issue_number" --body "$body" >/dev/null 2>&1 ||
    json_error_obj "$(jq -nc --arg issue "$issue_number" \
      '{message: ("could not post claim comment on issue #" + $issue),
        cause: "gh_comment_failed", issue_number: ($issue|tonumber)}')"

  # Let a near-simultaneous claim become visible, then resolve the winner.
  sleep "$CLAIM_SETTLE_SECS"

  # Winner = lowest comment id. A forged low-id claim could force a legit agent
  # to cede (a claim-jacking DoS), but the repo is single-user and private, so
  # only the user can comment; it also fails safe (refuse, never double-work).
  # Not worth claim-signing under this threat model.
  local claims winner_nonce winner_host
  claims="$(_lease_claim_comments "$issue_number")"
  winner_nonce="$(printf '%s' "$claims" | jq -r '
    (sort_by(.id) | .[0].body // "") | [match("claim-id: ([^\n]+)")] | (.[0].captures[0].string) // ""')"
  winner_host="$(printf '%s' "$claims" | jq -r '
    (sort_by(.id) | .[0].body // "") | [match("host: ([^\n]+)")] | (.[0].captures[0].string) // ""')"

  if [[ -n "$winner_nonce" && "$winner_nonce" == "$nonce" ]]; then
    return 0
  fi

  # We lost: another claim carries a lower comment id. Leave the shared label
  # and assignee in place (the winner still holds them) and cede.
  local cede
  cede="$(printf 'Ceding to a prior claim with a lower comment id.\n\n%s\nyielded-by-host: %s\nyielded-at: %s' \
    "$CEDE_MARKER" "$host" "$ts")"
  gh issue comment "$issue_number" --body "$cede" >/dev/null 2>&1 || true
  json_error_obj "$(jq -nc --arg issue "$issue_number" --arg owner "$winner_host" \
    '{message: ("issue #" + $issue + " was claimed first by host " + (if $owner == "" then "another agent" else $owner end) + " (lower comment id)"),
      cause: "issue_claimed", issue_number: ($issue|tonumber),
      owner: (if $owner == "" then null else $owner end)}')"
}

# Release the lease: drop our own assignee (scoped to us) and post a release
# breadcrumb. Remove the shared in-progress label ONLY when we are the sole
# remaining assignee, so we never strip a label another legitimate holder still
# depends on. Best-effort — a forge hiccup here must never fail cleanup.
_lease_release() {
  local issue_number="$1" branch="$2"
  local me host ts
  me="$(gh api user -q '.login' 2>/dev/null || echo "")"
  host="$(uname -n)"
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Count assignees other than us BEFORE dropping our own, to decide the label.
  local others="unknown" meta rc=0
  meta="$(gh issue view "$issue_number" --json assignees 2>/dev/null)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    others="$(printf '%s' "$meta" | jq -r --arg me "$me" \
      '[.assignees[].login | select(. != $me)] | length')"
  fi

  if [[ -n "$me" ]]; then
    gh issue edit "$issue_number" --remove-assignee "@me" >/dev/null 2>&1 || true
  fi
  # Sole holder only: no other assignee remained, so the label is safe to drop.
  if [[ "$others" == "0" ]]; then
    gh issue edit "$issue_number" --remove-label "$LEASE_LABEL" >/dev/null 2>&1 || true
  fi

  gh issue comment "$issue_number" --body \
    "$(printf 'Lease released (worktree cleaned up).\n\nhost: %s\nbranch: %s\nreleased-at: %s' \
      "$host" "$branch" "$ts")" >/dev/null 2>&1 || true
}

# Reentrant lease takeover for resume. Unlike _lease_claim, resume is a
# deliberate pickup of abandoned work, so it never runs the winner/cede logic
# and never refuses with issue_claimed: the single shared login means the
# assignee cannot tell the resuming host from any prior holder, so serializing
# here would only self-block a legitimate resume. Refresh the human-visible
# hints (assignee, label) and post a resume claim comment stamped with our nonce
# so fleet-status shows the new owner. A forge hiccup must never fail the resume,
# but the claim comment is the ONE authoritative coordination marker fleet-status
# reads to tell hosts apart. Assignee and label are only hints. So the assignee
# and label calls stay best-effort, while the return status reflects whether the
# claim comment actually landed: 0 the lease is recorded, 1 it is not (the caller
# must then report the lease as unrecorded rather than held). Returning 1 here is
# safe under the caller's set -e because cmd_resume calls this in an `if`.
_lease_resume_takeover() {
  local issue_number="$1" branch="$2" wt_path="$3" host="$4" ts="$5" nonce="$6"
  gh issue edit "$issue_number" --add-assignee "@me" >/dev/null 2>&1 ||
    warn "could not add self as assignee on issue #${issue_number}"
  gh issue edit "$issue_number" --add-label "$LEASE_LABEL" >/dev/null 2>&1 ||
    warn "could not add '${LEASE_LABEL}' label to issue #${issue_number} (does it exist in the repo?)"
  local body
  body="$(printf 'Resumed for work (reentrant takeover).\n\n%s\nclaim-id: %s\nhost: %s\nworktree: %s\nclaimed-at: %s\nbranch: %s' \
    "$CLAIM_MARKER" "$nonce" "$host" "$wt_path" "$ts" "$branch")"
  if gh issue comment "$issue_number" --body "$body" >/dev/null 2>&1; then
    return 0
  fi
  warn "could not post resume claim comment on issue #${issue_number}"
  return 1
}

# Detect whether this issue's branch already exists, and where. Prints exactly
# one of: "none", "local", "remote", "both", or "unknown".
#
# The remote side is checked authoritatively with 'git ls-remote' (it asks
# origin directly), NOT the remote-tracking ref, because the fetch upstream is
# best-effort and may be stale or skipped offline. On a network error the remote
# dimension degrades to "unknown" with a warning, rather than silently reporting
# the branch as absent, while the local check (which needs no network) still
# stands. exit-code semantics of 'git ls-remote --exit-code': 0 = ref found,
# 2 = no matching ref, anything else = could not reach the remote. The call is
# wrapped in 'timeout' so a hung transport (a reachable-but-stalled origin) lands
# in the "unknown" arm within seconds instead of blocking setup on the OS TCP
# timeout; timeout's own 124/137 exit is one of the "anything else" codes.
#
# The pattern is the fully qualified 'refs/heads/<branch>', not a bare
# '<branch>'. git ls-remote matches a pattern against the tail path components
# of each ref, so a bare name would also match an unrelated ref like
# 'refs/heads/wip/<branch>' and refuse setup on a false collision. Anchoring at
# 'refs/heads/' narrows that to a ref literally named '.../refs/heads/<branch>',
# which cannot occur in practice.
detect_existing_branch() {
  local branch="$1"
  local on_local=false remote_state ls_rc
  git show-ref --verify --quiet "refs/heads/${branch}" && on_local=true
  timeout 15 git ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1 && ls_rc=0 || ls_rc=$?
  case "$ls_rc" in
    0) remote_state="remote" ;;
    2) remote_state="absent" ;;
    *)
      remote_state="unknown"
      # To stderr explicitly: this function's stdout is the detection result,
      # consumed via command substitution, and warn() prints to stdout outside
      # JSON mode.
      warn "could not reach origin to check for branch '${branch}' (offline?); relying on the local check only" >&2
      ;;
  esac

  if [[ "$on_local" == true && "$remote_state" == "remote" ]]; then
    echo "both"
  elif [[ "$on_local" == true ]]; then
    echo "local"
  elif [[ "$remote_state" == "remote" ]]; then
    echo "remote"
  elif [[ "$remote_state" == "unknown" ]]; then
    echo "unknown"
  else
    echo "none"
  fi
}

# Map detect_existing_branch's result to a resume routing decision. Resume is
# the inverse of the #262 setup preflight: a branch that exists (local, remote,
# or both) can be re-attached; "none" means there is nothing to resume; and
# "unknown" (origin unreachable) fails closed, exactly as setup does.
resume_branch_decision() {
  case "$1" in
    local | remote | both) printf 'resume' ;;
    none) printf 'absent' ;;
    *) printf 'unreachable' ;;
  esac
}

# Count commits the local branch has that origin/<branch> does not, reading the
# fetched remote-tracking ref (no network). Returns 0 when either the local
# branch or the origin ref is absent, so a local-only branch (no origin baseline
# to be "ahead" of) and an in-sync branch both read 0; only genuine unpushed
# commits produce a positive count. Resume uses this to warn before re-attaching
# so origin is preferred without silently discarding local-only work.
count_ahead_of_origin() {
  local branch="$1"
  git show-ref --verify --quiet "refs/heads/${branch}" || {
    printf '0'
    return 0
  }
  git rev-parse --verify --quiet "refs/remotes/origin/${branch}" >/dev/null || {
    printf '0'
    return 0
  }
  git rev-list --count "refs/remotes/origin/${branch}..refs/heads/${branch}"
}

# Count commits origin/<branch> has that the local branch does not (the behind
# side), reading the fetched remote-tracking ref (no network). Returns 0 when
# either ref is absent. Paired with count_ahead_of_origin so resume can tell a
# clean fast-forward from a genuine divergence and word its warning correctly.
count_behind_of_origin() {
  local branch="$1"
  git show-ref --verify --quiet "refs/heads/${branch}" || {
    printf '0'
    return 0
  }
  git rev-parse --verify --quiet "refs/remotes/origin/${branch}" >/dev/null || {
    printf '0'
    return 0
  }
  git rev-list --count "refs/heads/${branch}..refs/remotes/origin/${branch}"
}

# Re-add the worktree on an existing branch per its detected state. Pure git (no
# gh/network), so it is unit-testable in the offline fixture. Never resets a
# branch that carries unpushed commits: the -B prefer-origin path runs only when
# the local branch is not ahead (ahead == 0). Any state that sources from origin
# (remote, or "both" preferring origin's tip) first verifies the tracking ref
# resolves and returns 3 if it does not, rather than letting 'git worktree add
# ... origin/<branch>' abort raw: branch_state comes from a live ls-remote while
# the tracking ref is only as fresh as the best-effort fetch, so a split-brain
# (ls-remote up, fetch down) must fail with a routable cause, not a crash.
add_resume_worktree() {
  local branch_state="$1" ahead="$2" branch="$3" wt_path="$4"
  case "$branch_state" in
    remote)
      git rev-parse --verify --quiet "refs/remotes/origin/${branch}" >/dev/null || return 3
      git worktree add --no-checkout --track -b "$branch" "$wt_path" "origin/${branch}"
      ;;
    both)
      if [[ "$ahead" -gt 0 ]]; then
        git worktree add --no-checkout "$wt_path" "$branch"
      else
        git rev-parse --verify --quiet "refs/remotes/origin/${branch}" >/dev/null || return 3
        git worktree add --no-checkout -B "$branch" "$wt_path" "origin/${branch}"
      fi
      ;;
    local)
      git worktree add --no-checkout "$wt_path" "$branch"
      ;;
    *)
      return 2
      ;;
  esac
}

# Given the JSON array from `gh pr list --json url,isCrossRepository`, print the
# url of the single open PR whose head lives in THIS repo (not a fork), or empty.
# Pure (no gh/network), so the fork-exclusion is unit-testable in the offline
# fixture. `gh pr list --head` filters by head branch NAME only, and the branch
# name is publicly predictable (<type>/<issue>-<slug> derived from the issue's
# labels and title), so a fork PR whose head branch carries the same name would
# otherwise be linked and ride the next push / auto-merge into main. Keeping only
# isCrossRepository == false drops those. Warns to stderr (never stdout, which is
# captured) when more than one same-repo PR remains, since first-pick is then
# arbitrary.
select_same_repo_pr_url() {
  local json="$1" same count
  same="$(printf '%s' "$json" | jq -c '[.[] | select(.isCrossRepository == false)]' 2>/dev/null || printf '[]')"
  count="$(printf '%s' "$same" | jq 'length' 2>/dev/null || echo 0)"
  if [[ "$count" -gt 1 ]]; then
    warn "found ${count} open same-repo PRs; linking the first one" >&2
  fi
  printf '%s' "$same" | jq -r '.[0].url // empty' 2>/dev/null || true
}

# Discover the URL of the OPEN same-repo PR whose head is <branch>, or empty if
# none. Resume writes this into state so the next push updates the PR instead of
# opening a second one. Best-effort: a gh failure yields empty and resume still
# proceeds (the next push then creates the PR). Fork PRs that merely share the
# head branch name are excluded by select_same_repo_pr_url, so an external
# contributor cannot get their PR linked into this issue's state.
discover_open_pr_url() {
  local branch="$1" json
  json="$(gh pr list --head "$branch" --state open --json url,isCrossRepository 2>/dev/null)" || json="[]"
  select_same_repo_pr_url "$json"
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

  # Guard before the number flows into the worktree path, branch name, the
  # .setup-issue-N.lock path, and gh issue refs. A non-numeric value (e.g.
  # "../../x") would otherwise only trip a later gate. Structured so the
  # orchestrator can route on cause.
  [[ "$issue_number" =~ ^[0-9]+$ ]] || json_error_obj "$(jq -nc --arg got "$issue_number" \
    '{message: ("expected a numeric issue number, got '\''" + $got + "'\''"),
      cause: "invalid_issue_number", issue_number: $got}')"

  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  acquire_setup_lock "$issue_number"

  if [[ -d "$wt_path" ]]; then
    json_error_obj "$(jq -nc --arg wt "$wt_path" --arg issue "$issue_number" \
      '{message: ("worktree already exists at " + $wt + " -- use '\''github-issue status " + $issue + "'\'' to check state"),
        cause: "worktree_exists", worktree: $wt, issue_number: ($issue|tonumber)}')"
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

  # Branch-existence preflight (#262). The issue-side lease below is the real
  # serializer; this is a best-effort backstop that catches an already-visible
  # branch before we claim the issue or add the worktree, so an agent that
  # slipped past the lease, or a prior run whose worktree was removed without
  # deleting the branch, does not silently start a second copy of the work. It
  # runs before the lease claim and 'git worktree add', so a refusal leaves no
  # claim, branch, or worktree behind. Structured so the orchestrator can route
  # on cause. Re-establishing a worktree for a still-open branch is manual for
  # now; a proper resume is tracked in #267.
  #
  # "unknown" means origin was unreachable, so the remote dimension (the case
  # this guard exists to catch) could not be checked. Refuse fail-closed with a
  # distinct cause rather than proceed: a flaky or blocked git transport must not
  # let a duplicate slip through the exact window the guard closes. Setup already
  # needed the network for the issue metadata above, so a genuinely offline run
  # has failed before reaching here; "unknown" is the split-brain case (git
  # transport down while 'gh api' is up), where fail-closed is correct.
  local branch_state
  branch_state="$(detect_existing_branch "$branch_name")"
  case "$branch_state" in
    none) ;;
    unknown)
      json_error_obj "$(jq -nc --arg branch "$branch_name" --arg issue "$issue_number" \
        '{message: ("could not reach origin to check whether branch '\''" + $branch + "'\'' already exists; refusing rather than risk starting a duplicate of issue #" + $issue + ". Retry once origin is reachable, or run '\''github-issue status " + $issue + "'\''."),
          cause: "branch_check_unreachable", branch: $branch, issue_number: ($issue|tonumber)}')"
      ;;
    *)
      json_error_obj "$(jq -nc --arg branch "$branch_name" --arg issue "$issue_number" --arg where "$branch_state" \
        '{message: ("branch '\''" + $branch + "'\'' already exists (" + $where + ") -- another agent may have started issue #" + $issue + ", or a prior run left it behind. Check the PR or run '\''github-issue status " + $issue + "'\'' before starting."),
          cause: "branch_exists", branch: $branch, issue_number: ($issue|tonumber), location: $where}')"
      ;;
  esac

  # Issue-side lease. Claim on the issue itself before creating the worktree so
  # an agent on another host or worktree root (past this machine's flock) sees
  # the claim first. Refuses with cause "issue_claimed" if already held. This
  # aborts BEFORE 'git worktree add' below, so a refusal leaves no partial
  # worktree behind.
  local me host claim_ts nonce
  me="$(gh api user -q '.login' 2>/dev/null)" || json_error_obj "$(jq -nc \
    '{message: "could not resolve the GitHub login (gh api user) to claim the issue",
      cause: "gh_auth_failed"}')"
  host="$(uname -n)"
  claim_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  # Per-invocation nonce: unique to THIS agent/run (host, worktree, UTC time, pid).
  nonce="${host}::${wt_path}::${claim_ts}::$$"
  _lease_precheck "$issue_number" "$me" "$host" "$wt_path"
  _lease_claim "$issue_number" "$branch_name" "$wt_path" "$host" "$claim_ts" "$nonce" "$_LEASE_REENTRANT"
  ok "claimed issue #${issue_number} (assignee @${me}, label ${LEASE_LABEL})"

  mkdir -p "$(dirname "$wt_path")"
  # Pin branch explicitly to base_ref so the new branch never inherits an
  # accidental stack from whatever HEAD happened to be when this ran. The
  # preflight above refuses a branch it could see, but it is not a hard
  # guarantee: the lease claim runs between that check and this line, so a
  # concurrent agent could create the branch in the gap. 'git worktree add -b'
  # is the backstop -- it refuses to reuse an existing branch and aborts under
  # 'set -e' (as a raw git error, not the structured branch_exists cause), so
  # the worst case is a hard failure here, never a silent duplicate.
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

# Re-establish a worktree on an issue's still-open branch. The inverse of setup:
# setup refuses when the branch exists (#262), resume refuses when it does not.
# Prefers origin as the source of truth, keeps local-only commits (warning when
# the local branch is ahead), links the open PR so the next push updates it, and
# takes the lease as a reentrant takeover rather than ceding. See #267.
cmd_resume() {
  local issue_number=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*) die "unknown option: $1" ;;
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
  [[ -n "$issue_number" ]] || die "usage: github-issue resume <issue-number>"

  [[ "$issue_number" =~ ^[0-9]+$ ]] || json_error_obj "$(jq -nc --arg got "$issue_number" \
    '{message: ("expected a numeric issue number, got '\''" + $got + "'\''"),
      cause: "invalid_issue_number", issue_number: $got}')"

  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  acquire_setup_lock "$issue_number"

  if [[ -d "$wt_path" ]]; then
    json_error_obj "$(jq -nc --arg wt "$wt_path" --arg issue "$issue_number" \
      '{message: ("worktree already exists at " + $wt + " -- use '\''github-issue status " + $issue + "'\'' to check state"),
        cause: "worktree_exists", worktree: $wt, issue_number: ($issue|tonumber)}')"
  fi

  fetch_remote
  assert_clean_tree

  local default_br base_ref
  default_br="$(default_branch)"
  base_ref="origin/${default_br}"

  local issue_json issue_title issue_labels issue_body
  issue_json="$(fetch_issue_metadata "$issue_number")"
  issue_title="$(printf '%s' "$issue_json" | jq -r '.title')"
  issue_labels="$(printf '%s' "$issue_json" | jq -c '.labels')"
  issue_body="$(printf '%s' "$issue_json" | jq -r '.body')"
  ok "fetched: ${issue_title}"

  local branch_type branch_name
  branch_type="$(derive_branch_type_auto "$issue_labels")"
  branch_name="$(build_branch_name "$branch_type" "$issue_number" "$issue_title")"
  ok "branch: ${branch_name}"

  # Resume requires an existing branch. Inverse of the #262 setup preflight:
  # setup refuses when the branch exists, resume refuses when it does not.
  # "unknown" (origin unreachable) fails closed, matching setup.
  local branch_state decision
  branch_state="$(detect_existing_branch "$branch_name")"
  decision="$(resume_branch_decision "$branch_state")"
  case "$decision" in
    resume) ;;
    absent)
      json_error_obj "$(jq -nc --arg branch "$branch_name" --arg issue "$issue_number" \
        '{message: ("branch '\''" + $branch + "'\'' exists neither locally nor on origin -- nothing to resume. Use '\''github-issue setup " + $issue + "'\'' to start fresh."),
          cause: "no_existing_branch", branch: $branch, issue_number: ($issue|tonumber)}')"
      ;;
    unreachable)
      json_error_obj "$(jq -nc --arg branch "$branch_name" --arg issue "$issue_number" \
        '{message: ("could not reach origin to check whether branch '\''" + $branch + "'\'' exists -- retry once origin is reachable, or run '\''github-issue status " + $issue + "'\''."),
          cause: "branch_check_unreachable", branch: $branch, issue_number: ($issue|tonumber)}')"
      ;;
  esac

  # Surface still-open blockers, matching setup. Resume does not refuse on them
  # (the branch already exists), but a resumed issue with open blockers deserves
  # the same notice setup gives.
  local blockers_json open_blockers_count
  blockers_json="$(parse_blockers "$issue_body")"
  open_blockers_count="$(printf '%s' "$blockers_json" | jq '[.[] | select(.state == "OPEN")] | length')"
  if [[ "$open_blockers_count" -gt 0 ]]; then
    warn "issue #${issue_number} references ${open_blockers_count} open blocker(s):"
    while IFS= read -r line; do
      [[ -n "$line" ]] && warn "  ${line}"
    done < <(printf '%s' "$blockers_json" | jq -r '.[] | select(.state == "OPEN") | "#\(.number) [\(.state)] \(.title)"')
  fi

  # The contract is a still-open branch. If the branch's PR already merged (the
  # branch just was not deleted), say so up front rather than letting it degrade
  # to "nothing to push" later. Best-effort; is_branch_merged is non-fatal and a
  # condition here, so its exit status never aborts under set -e.
  if is_branch_merged "$branch_name" "$base_ref"; then
    warn "branch '${branch_name}' looks already merged; resuming anyway, but the next push will likely have nothing to add"
  fi

  # Prefer origin as the source of truth. When the local branch carries unpushed
  # commits keep them and warn; the worktree add never resets a branch that is
  # ahead. Distinguish a clean fast-forward from a real divergence so the warning
  # points at the reconcile the next push will need.
  local ahead=0 behind=0
  case "$branch_state" in
    both)
      ahead="$(count_ahead_of_origin "$branch_name")"
      behind="$(count_behind_of_origin "$branch_name")"
      if [[ "$ahead" -gt 0 && "$behind" -gt 0 ]]; then
        warn "local branch '${branch_name}' has diverged from origin (${ahead} ahead, ${behind} behind); keeping local commits, the next push will need a reconcile against origin/${branch_name}"
      elif [[ "$ahead" -gt 0 ]]; then
        warn "local branch '${branch_name}' is ${ahead} commit(s) ahead of origin; keeping local commits, not resetting to origin"
      fi
      ;;
    local)
      warn "branch '${branch_name}' exists only locally; origin has no copy, the next push will publish it"
      ;;
  esac

  # Re-add the worktree on the EXISTING branch BEFORE taking the lease, so a
  # failed add never strands a reentrant takeover on an issue with no worktree.
  # add_resume_worktree verifies the origin tracking ref for the origin-sourced
  # states (return 3) and never resets a branch that is ahead.
  mkdir -p "$(dirname "$wt_path")"
  local add_rc=0
  add_resume_worktree "$branch_state" "$ahead" "$branch_name" "$wt_path" || add_rc=$?
  if [[ "$add_rc" -eq 3 ]]; then
    json_error_obj "$(jq -nc --arg branch "$branch_name" --arg issue "$issue_number" \
      '{message: ("origin tracking ref for '\''" + $branch + "'\'' did not resolve after fetch (origin unreachable or a stale fetch); retry once origin is reachable before resuming issue #" + $issue + "."),
        cause: "branch_check_unreachable", branch: $branch, issue_number: ($issue|tonumber)}')"
  elif [[ "$add_rc" -ne 0 ]]; then
    json_error_obj "$(jq -nc --arg branch "$branch_name" --arg issue "$issue_number" --arg wt "$wt_path" \
      '{message: ("could not add a worktree for branch '\''" + $branch + "'\'' at " + $wt + " (git worktree add failed; a stale worktree entry or the branch checked out elsewhere?). Run '\''git worktree prune'\'' and retry."),
        cause: "worktree_add_failed", branch: $branch, issue_number: ($issue|tonumber), worktree: $wt}')"
  fi
  register_cleanup "$wt_path"
  checkout_and_unlock "$wt_path"

  # Reentrant takeover of the issue lease (never cedes; single shared login).
  # Runs only after the worktree exists and cleanup is armed, so an add failure
  # above leaves the issue lease untouched.
  local me host claim_ts nonce
  me="$(gh api user -q '.login' 2>/dev/null)" || json_error_obj "$(jq -nc \
    '{message: "could not resolve the GitHub login (gh api user) to claim the issue",
      cause: "gh_auth_failed"}')"
  host="$(uname -n)"
  claim_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  nonce="${host}::${wt_path}::${claim_ts}::$$"
  # `if` so the return-1 (claim comment failed to post) does not trip set -e, and
  # so the success line only fires when the lease is actually recorded. If the
  # forge is degraded, resume still proceeds (the worktree is real), but the
  # message says the coordination marker is missing so a multi-host operator
  # knows fleet-status will show no owner.
  if _lease_resume_takeover "$issue_number" "$branch_name" "$wt_path" "$host" "$claim_ts" "$nonce"; then
    ok "resumed lease on issue #${issue_number} (assignee @${me}, label ${LEASE_LABEL})"
  else
    warn "could not record the lease claim on issue #${issue_number} (forge degraded); resuming anyway, but fleet-status will show no owner -- coordinate manually if another host may pick this up"
  fi

  # Discover the open PR so the next push updates it rather than opening a second.
  local pr_url
  pr_url="$(discover_open_pr_url "$branch_name")"
  if [[ -n "$pr_url" ]]; then
    ok "linked existing PR: ${pr_url}"
  else
    warn "no open PR found for '${branch_name}'; the next push will create one"
  fi

  create_issue_state "$branch_name" "$wt_path" "$issue_number" "$issue_title" \
    "$issue_body" "$base_ref" "$blockers_json" "$pr_url" "implement" \
    "Worktree resumed on existing branch ${branch_name}."
  _WT_CLEANUP_PATH=""
  ok "worktree resumed at ${wt_path}"

  json_ok "$(jq -n \
    --arg issue_number "$issue_number" \
    --arg branch "$branch_name" \
    --arg base_ref "$base_ref" \
    --arg worktree "$wt_path" \
    --arg branch_type "$branch_type" \
    --arg title "$issue_title" \
    --arg pr_url "$pr_url" \
    --arg branch_state "$branch_state" \
    --argjson ahead "$ahead" \
    '{issue_number: ($issue_number|tonumber), branch: $branch, base_ref: $base_ref, worktree: $worktree,
      branch_type: $branch_type, title: $title,
      pr_url: (if $pr_url == "" then null else $pr_url end),
      resumed: true, branch_state: $branch_state, ahead_of_origin: $ahead,
      workflow_step: "implement"}')"
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

  # Multi-agent freshness — refresh refs and PR state before reconciling so
  # long-running sessions don't see stale base or auto-merge state.
  fetch_remote

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

  # Reconcile state with external signals — but only if no mutating command
  # is currently active on this worktree. The lock guards a read-modify-write
  # over the whole state file; without it, a concurrent transition could
  # drop step_history entries. Try-lock on fd 6 (distinct from setup=7,
  # auto-refresh=8, mutating=9) so this never blocks status itself.
  local reconciled=true
  local lock_file="${wt_path}/.worktree.lock"
  : >"$lock_file" 2>/dev/null || true
  exec 6>"$lock_file"
  if flock -n 6; then
    _GH_OUTER_LOCK="$wt_path"
    reconcile_state "$wt_path" "$branch" "$pr_url" "$default_br"
    _GH_OUTER_LOCK=""
    exec 6>&-
  else
    reconciled=false
    exec 6>&-
  fi

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
      --arg merge_status "$_detected_merge_status" \
      --arg number "$pr_number" \
      '{url: $url, state: $state, review_decision: $review,
        merge_state_status: (if $merge_status == "" then null else $merge_status end),
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
    --argjson reconciled "$reconciled" \
    '{issue_number: ($issue_number|tonumber), state: $state, detail: $detail,
      worktree: $worktree, branch: $branch, workflow_step: $workflow_step,
      workflow_detail: $workflow_detail, step_history: $step_history,
      title: $title, issue_body: $issue_body, pr: $pr, reconciled: $reconciled}')"
}

cmd_push() {
  local issue_number="${1:?usage: github-issue push <issue-number>}"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  acquire_worktree_lock "$wt_path"
  migrate_state "$wt_path"

  local branch pr_url issue_title default_br base_ref issue_labels
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  issue_title="$(read_state_field issue_title "$wt_path")"
  default_br="$(default_branch)"
  base_ref="$(jq -r '.base_ref // empty' "${wt_path}/.worktree-state.json")"
  [[ -z "$base_ref" ]] && base_ref="origin/${default_br}"

  # Up-front protected-branch guard. Done here as a structured error so the
  # actual push subshells can't have assert_not_main inside them (its die()
  # would print JSON to subshell stdout, get discarded, and we'd misreport
  # the failure as push_failed).
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    local msg="refusing to push protected branch ${branch} — state file looks corrupted"
    json_error_obj "$(jq -nc --arg branch "$branch" --arg msg "$msg" \
      '{message: $msg, cause: "protected_branch", branch: $branch}')"
  fi

  # Silent pre-push rebase. Refresh base, check whether we're already ahead of
  # it, and rebase only when needed. A successful rebase makes later pushes
  # non-fast-forward, so we switch to --force-with-lease for PR updates.
  fetch_remote
  local rebased=0
  if ! git -C "$wt_path" merge-base --is-ancestor "$base_ref" "$branch" 2>/dev/null; then
    info "rebasing ${branch} onto ${base_ref}..."
    if ! git -C "$wt_path" rebase "$base_ref" >&2; then
      git -C "$wt_path" rebase --abort 2>/dev/null || true
      json_error_obj "$(jq -nc --arg branch "$branch" --arg base "$base_ref" --arg wt "$wt_path" \
        '{message: ("rebase onto " + $base + " produced conflicts — agent must resolve. Run mergiraf solve on unmerged paths, then resume with: cd " + $wt + " && git rebase " + $base),
          cause: "rebase_conflict",
          branch: $branch,
          base_ref: $base,
          worktree: $wt}')"
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
    (cd "$wt_path" && git push -u origin "$branch")
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
    local push_stderr push_rc=0
    push_stderr="$(mktemp)"
    if [[ "$rebased" -eq 1 ]]; then
      (cd "$wt_path" && git push --force-with-lease origin "$branch") 2>"$push_stderr" || push_rc=$?
    else
      (cd "$wt_path" && git push origin "$branch") 2>"$push_stderr" || push_rc=$?
    fi
    if [[ "$push_rc" -ne 0 ]]; then
      local err_text
      err_text="$(cat "$push_stderr")"
      rm -f "$push_stderr"
      # Distinguish remote-advanced (another session pushed) from generic push
      # failure (network, auth, hook). The regex matches both paths reaching
      # here: stale-info from --force-with-lease (rebased=1) AND plain
      # non-fast-forward (rebased=0). Both mean "another session has new
      # commits on this branch" so they share cause: lease_failed and the
      # agent does the same thing — fetch and escalate, never retry.
      if printf '%s' "$err_text" | grep -qE 'stale info|rejected.*non-fast-forward|fetch first'; then
        json_error_obj "$(jq -nc --arg branch "$branch" --arg detail "$err_text" \
          '{message: ("push rejected: remote advanced on " + $branch + " — another session has new commits on this branch; do not retry, fetch and inspect"),
            cause: "lease_failed",
            branch: $branch,
            stderr: $detail}')"
      else
        json_error_obj "$(jq -nc --arg branch "$branch" --arg detail "$err_text" \
          '{message: ("push failed on " + $branch),
            cause: "push_failed",
            branch: $branch,
            stderr: $detail}')"
      fi
    fi
    rm -f "$push_stderr"
    ok "updates pushed to PR: ${pr_url}"
    action="updated"
  fi

  # CI summary uses the shared detector so the vocabulary
  # (passing/failing/pending/none) matches what audit and reconcile_state emit.
  local ci_status
  ci_status="$(detect_ci_conclusion "$pr_url")"

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

    # Auto-heal: a waiting PR that is BEHIND main needs a rebase + force-push
    # to clear the staleness and let GitHub re-evaluate auto-merge. Distinguish
    # "did real work" (rc=0) from no-op (rc=2) and failure (rc=1) so we only
    # advertise auto_refreshed=true when something actually changed.
    local refreshed=false
    if [[ "$workflow_step" == "waiting" ]] && [[ "$_detected_merge_status" == "BEHIND" ]]; then
      local refresh_rc=0
      auto_refresh_behind "$wt_dir" || refresh_rc=$?
      if [[ "$refresh_rc" -eq 0 ]]; then
        refreshed=true
        # Re-read PR state post-refresh so merge_state_status reflects reality.
        detect_issue_state "$wt_dir" "$branch" "$pr_url" "$default_br"
      fi
    fi

    # Per-PR CI summary — included in merge_order so the skill can identify a
    # gating PR that is actually ready vs one waiting on CI.
    local ci_status="unknown"
    if [[ -n "$pr_url" ]]; then
      ci_status="$(detect_ci_conclusion "$pr_url")"
    fi

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
      --arg ci_status "$ci_status" \
      --arg merge_status "$_detected_merge_status" \
      --argjson refreshed "$refreshed" \
      --argjson blockers "$blockers" \
      --argjson touched "$touched_files_json" \
      '. + [{issue_number: ($num|tonumber), title: $title, state: $state,
              detail: $detail, branch: $branch, base_ref: $base_ref,
              pr_url: (if $pr_url == "" then null else $pr_url end),
              worktree: $worktree, workflow_step: $workflow_step,
              ci_status: $ci_status,
              merge_state_status: (if $merge_status == "" then null else $merge_status end),
              auto_refreshed: $refreshed,
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

  # Merge-ordering: only worktrees whose PR is mergeable (waiting or
  # review_security with an open PR) appear in the list, but each entry's
  # `blocks` counts EVERY peer that names it as a blocker — including peers
  # still in implement/plan. That matches the prose "issues that unblock
  # others merge first": an upstream PR with downstream issues still being
  # written ranks higher than one with no downstreams. Sort by the size of
  # that fuller set so the next-to-merge floats to the top.
  local merge_order
  merge_order="$(printf '%s' "$results" | jq '
    . as $all
    | [ .[] | select(.pr_url != null and (.workflow_step == "waiting" or .workflow_step == "review_security")) ]
    | map(. as $item
          | . + {
              blocks: [
                $all[]
                | select(.blockers | map(.number) | index($item.issue_number))
                | .issue_number
              ]
            })
    | sort_by(-(.blocks | length))
    | map({issue_number, title, pr_url, workflow_step, ci_status, merge_state_status, blocks})
  ')"

  json_ok "$(jq -n \
    --argjson worktrees "$results" \
    --argjson overlaps "$overlaps" \
    --argjson merge_order "$merge_order" \
    '{worktrees: $worktrees, overlaps: $overlaps, merge_order: $merge_order}')"
}

cmd_cleanup() {
  local issue_number="${1:?usage: github-issue cleanup <issue-number>}"

  # Guard before the number flows into the worktree path, the branch names we
  # delete, the .setup-issue-N.lock path we rm, and gh issue refs. A non-numeric
  # value (e.g. "../../x") would otherwise only trip a later gate. Structured so
  # the orchestrator can route on cause.
  [[ "$issue_number" =~ ^[0-9]+$ ]] || json_error_obj "$(jq -nc --arg got "$issue_number" \
    '{message: ("expected a numeric issue number, got '\''" + $got + "'\''"),
      cause: "invalid_issue_number", issue_number: $got}')"

  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  if [[ ! -d "$wt_path" ]]; then
    json_error "no worktree for issue #${issue_number}"
  fi

  acquire_worktree_lock "$wt_path"

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

  # Release the issue-side lease claimed at setup: drop the in-progress label +
  # self-assignee and post a release breadcrumb so a future agent on any host
  # sees the issue is free again.
  _lease_release "$issue_number" "$branch"
  ok "issue-side lease released"

  # Remove this issue's setup lock file. acquire_setup_lock creates
  # "${worktree_base}/.setup-issue-${issue_number}.lock" (fd 7) but nothing ever
  # deleted it, so the files accumulated forever and read as phantom orphans.
  # The flock is fd-based, so unlinking the file is safe. Match the setup path
  # construction exactly and only touch THIS issue's lock — a reaper for other
  # issues' stale locks is out of scope here.
  rm -f "$(dirname "$wt_path")/.setup-issue-${issue_number}.lock"
  ok "setup lock removed"

  # Report the issue's state — do NOT force-close. The PR body's closing
  # keyword (Closes #N / Fixes #N / Resolves #N) is the source of truth: if
  # present, GitHub already closed the issue at merge time; if absent (e.g.,
  # a multi-phase issue using Refs #N), the contributor deliberately kept it
  # open and we must not override that.
  if [[ -n "$pr_number" ]]; then
    local issue_state
    issue_state="$(gh issue view "$issue_number" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")"
    case "$issue_state" in
      CLOSED)
        ok "issue closed by GitHub on PR merge (closing keyword)"
        ;;
      OPEN)
        ok "issue left open (no closing keyword in PR); close manually when all related work is complete"
        ;;
      *)
        ok "issue state: ${issue_state}"
        ;;
    esac
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

  acquire_worktree_lock "$wt_path"

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

  acquire_worktree_lock "$wt_path"

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

# Verify a merged PR's content actually landed on the default branch, and
# (optionally) recover when it didn't. The classic failure mode this catches
# is the stacked-PR squash race:
#
#   PR A: base=main, head=feat/A
#   PR B: base=feat/A, head=feat/B (stacked on A)
#
# When the user merges A then merges B within seconds, GitHub may squash B
# against its now-stale base before the auto-retarget to main completes. The
# squash commit gets computed (with the right diff) but is unreachable from
# any branch — main never receives B's content even though the GitHub UI
# happily reports B as merged.
#
# Usage:
#   github-issue verify-landed <PR-number>           — read-only check; JSON output.
#                                                       exit 0 if landed or not yet merged.
#                                                       exit 1 if merged but orphaned.
#   github-issue verify-landed <PR-number> --rescue  — cherry-pick the orphan onto the
#                                                       default branch and push.
#                                                       Refuses on dirty working tree,
#                                                       conflicts, or push rejection.
cmd_verify_landed() {
  local pr_number="${1:?usage: github-issue verify-landed <pr-number> [--rescue]}"
  local rescue="false"
  shift
  while (($#)); do
    case "$1" in
      --rescue)
        rescue="true"
        shift
        ;;
      *) die "unknown flag: $1 (usage: github-issue verify-landed <pr-number> [--rescue])" ;;
    esac
  done

  [[ "$pr_number" =~ ^[0-9]+$ ]] || die "PR number must be numeric, got: ${pr_number}"

  local pr_json state merge_commit base_ref_name pr_url
  pr_json="$(gh pr view "$pr_number" --json number,state,mergeCommit,baseRefName,url 2>/dev/null)" ||
    json_error "PR #${pr_number} not found (gh pr view failed)"
  state="$(printf '%s' "$pr_json" | jq -r '.state')"
  merge_commit="$(printf '%s' "$pr_json" | jq -r '.mergeCommit.oid // ""')"
  base_ref_name="$(printf '%s' "$pr_json" | jq -r '.baseRefName')"
  pr_url="$(printf '%s' "$pr_json" | jq -r '.url')"

  if [[ "$state" != "MERGED" ]]; then
    json_ok "$(jq -nc \
      --arg pr "$pr_number" --arg state "$state" --arg url "$pr_url" \
      '{pr_number: ($pr|tonumber), state: $state, url: $url, status: "not_merged",
        message: "PR is not in MERGED state; nothing to verify"}')"
    return
  fi

  [[ -n "$merge_commit" && "$merge_commit" != "null" ]] ||
    json_error "PR #${pr_number} is MERGED but has no mergeCommit.oid (GitHub API anomaly)"

  local default_br
  default_br="$(default_branch)"

  info "fetching latest origin/${default_br}..."
  git fetch origin "$default_br" >/dev/null 2>&1 ||
    warn "git fetch origin ${default_br} failed; verifying against last known refs"

  # If the merge commit isn't in the local object store yet, pull it.
  # `git fetch origin <sha>` works because GitHub allows fetching by SHA.
  if ! git cat-file -e "${merge_commit}^{commit}" 2>/dev/null; then
    git fetch origin "$merge_commit" >/dev/null 2>&1 ||
      warn "could not fetch merge commit ${merge_commit:0:7} into local repo"
  fi

  local landed="false" landed_via="direct"
  if git cat-file -e "${merge_commit}^{commit}" 2>/dev/null; then
    if git merge-base --is-ancestor "$merge_commit" "origin/${default_br}" 2>/dev/null; then
      landed="true"
      landed_via="direct"
    else
      # The merge commit's SHA isn't reachable, but its diff might be on the
      # default branch via cherry-pick (e.g. a prior --rescue run, or a manual
      # recovery). `git cherry <upstream> <head> <limit>` does patch-id
      # matching and prints `-` for commits whose equivalent is already on
      # the upstream. Use the merge commit as both head and limit's source
      # (limit = ${merge_commit}~1) so cherry walks exactly one commit.
      # If the parent isn't fetched locally, cherry fails silently and we
      # stay in orphan land. That's fine: the user's `--rescue` path doesn't
      # depend on this detection.
      if git cat-file -e "${merge_commit}~1^{commit}" 2>/dev/null &&
        [[ "$(git cherry "origin/${default_br}" "$merge_commit" "${merge_commit}~1" 2>/dev/null | awk '{print $1; exit}')" == "-" ]]; then
        landed="true"
        landed_via="cherry_pick_equivalent"
      fi
    fi
  fi

  if [[ "$landed" == "true" ]]; then
    if [[ "$landed_via" == "direct" ]]; then
      ok "PR #${pr_number} merge commit ${merge_commit:0:7} is reachable from origin/${default_br}"
    else
      ok "PR #${pr_number} content is on origin/${default_br} as a cherry-pick equivalent (orphan ${merge_commit:0:7} was previously rescued)"
    fi
    json_ok "$(jq -nc \
      --arg pr "$pr_number" --arg sha "$merge_commit" --arg br "$default_br" \
      --arg url "$pr_url" --arg base "$base_ref_name" --arg via "$landed_via" \
      '{pr_number: ($pr|tonumber), url: $url, status: "landed",
        merge_commit: $sha, default_branch: $br, original_base_ref: $base,
        landed_via: $via,
        message: (if $via == "direct"
                  then "PR content reachable from default branch"
                  else "PR content present on default branch via patch-id-equivalent commit (orphan previously rescued)"
                  end)}')"
    return
  fi

  # Orphan detected.
  local diff_stat="" subject="" parent_sha=""
  if git cat-file -e "${merge_commit}^{commit}" 2>/dev/null; then
    subject="$(git log -1 --format='%s' "$merge_commit" 2>/dev/null || echo "")"
    parent_sha="$(git log -1 --format='%P' "$merge_commit" 2>/dev/null | awk '{print $1}')"
    diff_stat="$(git show --stat --format='' "$merge_commit" 2>/dev/null | tail -1 | sed 's/^ *//')"
  fi

  warn "ORPHAN: PR #${pr_number} merged but ${merge_commit:0:7} is NOT on origin/${default_br}"
  warn "  stacked base at merge time: ${base_ref_name}"
  [[ -n "$diff_stat" ]] && warn "  diff: ${diff_stat}"

  if [[ "$rescue" != "true" ]]; then
    json_ok "$(jq -nc \
      --arg pr "$pr_number" --arg sha "$merge_commit" --arg subj "$subject" \
      --arg parent "$parent_sha" --arg stat "$diff_stat" --arg br "$default_br" \
      --arg base "$base_ref_name" --arg url "$pr_url" \
      '{pr_number: ($pr|tonumber), url: $url, status: "orphaned",
        merge_commit: $sha, merge_commit_subject: $subj,
        merge_commit_parent: $parent, diff_stat: $stat,
        default_branch: $br, original_base_ref: $base,
        recovery_hint: ("github-issue verify-landed " + $pr + " --rescue"),
        message: "PR is MERGED on GitHub but the squash commit is unreachable from the default branch (stacked-PR squash race). Re-run with --rescue to cherry-pick and push."}')"
    return 1
  fi

  # --rescue: cherry-pick orphan onto default branch and push.
  local repo_root
  repo_root="$(git rev-parse --show-toplevel)" ||
    json_error "rescue requires running from inside the repo working tree"

  # Refuse to act on a dirty tree — we'd risk losing uncommitted work.
  if ! git -C "$repo_root" diff --quiet HEAD -- 2>/dev/null || ! git -C "$repo_root" diff --cached --quiet 2>/dev/null; then
    json_error_obj "$(jq -nc --arg pr "$pr_number" --arg sha "$merge_commit" \
      '{message: "working tree has uncommitted changes; commit or stash before --rescue",
        cause: "dirty_tree", pr_number: ($pr|tonumber), merge_commit: $sha}')"
  fi

  # Take a base-dir lock so two concurrent rescues don't race on the same repo.
  local wt_base lock_file
  wt_base="$(worktree_base)"
  mkdir -p "$wt_base"
  lock_file="${wt_base}/.rescue-${pr_number}.lock"
  : >"$lock_file" 2>/dev/null || die "cannot create rescue lock at ${lock_file}"
  exec 5>"$lock_file"
  if ! flock -n 5; then
    json_error_obj "$(jq -nc --arg pr "$pr_number" \
      '{message: ("another rescue for PR #" + $pr + " is already in progress"),
        cause: "rescue_locked", pr_number: ($pr|tonumber)}')"
  fi

  # Make sure the orphan is locally available before checkout.
  git -C "$repo_root" cat-file -e "${merge_commit}^{commit}" 2>/dev/null ||
    git -C "$repo_root" fetch origin "$merge_commit" >/dev/null 2>&1 ||
    json_error "cannot fetch orphan commit ${merge_commit} from origin"

  local current_branch
  current_branch="$(git -C "$repo_root" branch --show-current)"
  if [[ "$current_branch" != "$default_br" ]]; then
    info "switching to ${default_br} (was on ${current_branch})..."
    git -C "$repo_root" switch "$default_br" >/dev/null 2>&1 ||
      json_error_obj "$(jq -nc --arg b "$default_br" \
        '{message: ("cannot switch to " + $b + " (uncommitted changes?)"),
          cause: "checkout_failed"}')"
  fi

  info "fast-forwarding local ${default_br} to origin..."
  git -C "$repo_root" pull --ff-only origin "$default_br" >/dev/null 2>&1 ||
    json_error_obj "$(jq -nc --arg b "$default_br" \
      '{message: ("local " + $b + " is not fast-forwardable from origin; resolve by hand"),
        cause: "ff_failed"}')"

  info "cherry-picking ${merge_commit:0:7}..."
  if ! git -C "$repo_root" cherry-pick "$merge_commit" >/tmp/github-issue-rescue.log 2>&1; then
    local cherry_log
    cherry_log="$(cat /tmp/github-issue-rescue.log 2>/dev/null || echo "")"
    git -C "$repo_root" cherry-pick --abort 2>/dev/null || true
    json_error_obj "$(jq -nc --arg sha "$merge_commit" --arg log "$cherry_log" \
      '{message: "cherry-pick of orphan failed (conflict?); aborted and reverted",
        cause: "cherry_pick_conflict", merge_commit: $sha, output: $log}')"
  fi

  local new_head
  new_head="$(git -C "$repo_root" rev-parse HEAD)"

  info "pushing to origin/${default_br}..."
  if ! git -C "$repo_root" push origin "$default_br" >/tmp/github-issue-rescue.log 2>&1; then
    local push_log
    push_log="$(cat /tmp/github-issue-rescue.log 2>/dev/null || echo "")"
    json_error_obj "$(jq -nc --arg b "$default_br" --arg sha "$new_head" --arg log "$push_log" \
      '{message: ("push to origin/" + $b + " rejected; cherry-pick is committed locally at " + $sha),
        cause: "push_failed", local_head: $sha, output: $log}')"
  fi

  ok "rescued: orphan ${merge_commit:0:7} now on origin/${default_br} as ${new_head:0:7}"
  json_ok "$(jq -nc \
    --arg pr "$pr_number" --arg orig "$merge_commit" --arg new "$new_head" \
    --arg br "$default_br" --arg url "$pr_url" \
    '{pr_number: ($pr|tonumber), url: $url, status: "rescued",
      orphan_commit: $orig, cherry_picked_as: $new, default_branch: $br,
      message: "Orphan squash commit was cherry-picked onto the default branch and pushed"}')"
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

# ── Queue-cursor persistence (github-issues-auto) ─────────────────────────────
#
# The per-issue .worktree-state.json already survives a reboot. The batch
# driver's queue cursor (the ordered queue, the position within it, the
# stacking chain, and the decisions buffer) lived only in the driving session,
# so a killed or rebooted run could not resume and the user had to re-supply the
# queue. This subcommand persists that cursor to a single .queue-state.json in
# the shared worktree base, deliberately OUTSIDE any one worktree so it outlives
# the cleanup of a finished issue's worktree. Writes are atomic (temp file plus
# rename) and serialised with a per-host flock, matching how write_state and the
# setup/worktree locks already work. The github-issues-auto skill owns the JSON
# shape; this command only guarantees durability, atomicity, and valid JSON.
QUEUE_STATE_VERSION=1

# Structural validation for a queue-state payload. Echoes a human reason string
# if the JSON is not a well-formed cursor, or nothing if it is valid. The state
# is fed verbatim into a resuming orchestrator that acts on queue/cursor/
# prev_branch and re-injects the decisions buffer (which is derived from
# attacker-authorable issue bodies) into the LLM's context. Reject a malformed
# or hostile shape at the boundary so a tampered file cannot resume as trusted.
# The skill may add fields freely; only the security-relevant ones are pinned.
_queue_state_validate() {
  printf '%s' "$1" | jq -r '
    if type != "object" then "state must be a JSON object"
    elif (.queue | type) != "array" then "queue must be an array of issue numbers"
    elif (.queue | length) != ([.queue[] | select(type == "number" and . == floor)] | length)
      then "queue must contain only integer issue numbers"
    elif (has("cursor") | not) then "cursor is required"
    elif (.cursor | type) != "number" or (.cursor != (.cursor | floor))
      then "cursor must be an integer"
    elif (.cursor < 0) or (.cursor > (.queue | length))
      then "cursor is out of range for the queue"
    elif (has("prev_branch") and ((.prev_branch | type) != "string"))
      then "prev_branch must be a string"
    elif (has("prev_branch") and ((.prev_branch | test("^[A-Za-z0-9._/-]+$")) | not))
      then "prev_branch has invalid characters"
    elif (has("prs") and ((.prs | type) != "object")) then "prs must be an object"
    else "" end
  '
}

cmd_queue_state() {
  local action="${1:-}"
  [[ $# -gt 0 ]] && shift
  local payload=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        payload="${2:?--json requires a value}"
        shift 2
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        die "unexpected argument: $1"
        ;;
    esac
  done

  # worktree_base resolves via 'git rev-parse', which yields a nonsense base in a
  # bare repo or GIT_DIR and aborts entirely with no repo at all. Test the output
  # value, not just the exit status: --is-inside-work-tree exits 0 and prints
  # "false" inside a bare repo, so an exit-status check would wave it through.
  # Only a real work tree ("true") may proceed; anything else is routable.
  if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]]; then
    json_error_obj "$(jq -nc \
      '{message: "github-issue queue-state must run inside the repository work tree",
        cause: "not_in_repo"}')"
  fi

  local QSTATE_DIR QSTATE_FILE QSTATE_LOCK
  QSTATE_DIR="$(worktree_base)"
  mkdir -p "$QSTATE_DIR"
  QSTATE_FILE="${QSTATE_DIR}/.queue-state.json"
  QSTATE_LOCK="${QSTATE_DIR}/.queue-state.lock"

  # These paths are always created here as regular files, so a symlink at either
  # is planted, not legitimate. Opening the lock with O_TRUNC (below) or reading
  # the state would follow it, letting a same-user process redirect a truncate or
  # a read to an arbitrary target. Refuse rather than follow.
  if [[ -L "$QSTATE_FILE" || -L "$QSTATE_LOCK" ]]; then
    json_error_obj "$(jq -nc \
      '{message: "queue-state path is a symlink; refusing to follow it",
        cause: "queue_state_symlink"}')"
  fi

  case "$action" in
    get)
      if [[ ! -f "$QSTATE_FILE" ]]; then
        json_ok "$(jq -nc '{exists: false, state: null}')"
        return 0
      fi
      # No lock on the read: the atomic rename means any file present is a whole
      # one. If a concurrent clear unlinked it between the test and the read,
      # treat that as not-present rather than letting cat abort under set -e.
      local content
      content="$(cat "$QSTATE_FILE" 2>/dev/null)" || {
        json_ok "$(jq -nc '{exists: false, state: null}')"
        return 0
      }
      # Slurp so "present but not valid JSON" also covers a concatenated
      # multi-document file (which a bare 'jq -e .' would wave through, then die
      # unrouted at the --argjson below). Exactly one JSON value may proceed.
      if ! printf '%s' "$content" | jq -e -s 'length == 1' >/dev/null 2>&1; then
        json_error_obj "$(jq -nc --arg f "$QSTATE_FILE" \
          '{message: ("queue state at " + $f + " is present but not a single valid JSON document; delete it or run '\''github-issue queue-state clear'\'' to start fresh"),
            cause: "queue_state_corrupt", path: $f}')"
      fi
      # Valid JSON, but re-check the shape before handing it to a resumer: a file
      # written by this command's set is already valid, so a failure here means
      # it was hand-edited or planted. Surface it rather than resume on a hostile
      # or broken cursor.
      local qs_reason
      qs_reason="$(_queue_state_validate "$content")"
      if [[ -n "$qs_reason" ]]; then
        json_error_obj "$(jq -nc --arg f "$QSTATE_FILE" --arg r "$qs_reason" \
          '{message: ("queue state at " + $f + " is malformed: " + $r + "; run '\''github-issue queue-state clear'\'' to start fresh"),
            cause: "queue_state_invalid", path: $f}')"
      fi
      json_ok "$(jq -nc --argjson s "$content" '{exists: true, state: $s}')"
      ;;
    set)
      [[ -n "$payload" ]] || die "usage: github-issue queue-state set --json '<json>'"
      # Bound the payload before parsing it. The decisions buffer is issue-body
      # derived, so cap it to keep a runaway or hostile blob from being persisted
      # and re-parsed on every get. 64 KiB is far above any real cursor (queue of
      # numbers, a cursor, a ref, a small PR map, concise decision records) and
      # sits below the kernel's ~128 KiB single-argument limit (MAX_ARG_STRLEN),
      # so the guard is reachable: a larger single --json arg is rejected by the
      # OS at exec with E2BIG before this script ever runs.
      if [[ "${#payload}" -gt 65536 ]]; then
        json_error_obj "$(jq -nc \
          '{message: "queue-state set: --json payload exceeds 64 KiB",
            cause: "queue_state_too_large"}')"
      fi
      # Require exactly one JSON object. Slurp (-s) so a concatenated payload like
      # '{..}{..}' is caught: a bare 'jq -e type=="object"' processes each document
      # and exits on the last truthy one, waving two objects through, after which
      # the stamp writes a two-document file and the confirming --argjson fails
      # under set -e for a silent exit-0 that corrupts persisted state. length==1
      # plus an object type on the sole document closes that, and also rejects an
      # array/number/string/null (which would abort the '. + {..}' stamp).
      if ! printf '%s' "$payload" | jq -e -s 'length == 1 and (.[0] | type == "object")' >/dev/null 2>&1; then
        json_error_obj "$(jq -nc \
          '{message: "queue-state set: --json must be exactly one JSON object",
            cause: "queue_state_not_object"}')"
      fi
      # Structural validation: queue is integer issue numbers, cursor is an
      # in-range integer, prev_branch is a safe ref. Refuse a malformed cursor at
      # the write boundary so a resumer never trusts a hostile or broken shape.
      local qs_reason
      qs_reason="$(_queue_state_validate "$payload")"
      if [[ -n "$qs_reason" ]]; then
        json_error_obj "$(jq -nc --arg r "$qs_reason" \
          '{message: ("queue-state set: " + $r), cause: "queue_state_invalid"}')"
      fi
      : >"$QSTATE_LOCK" 2>/dev/null || die "cannot create queue-state lock at ${QSTATE_LOCK}"
      # fd 5 is safe here: queue-state is a leaf subcommand that never runs in
      # the same process as verify-landed's rescue lock (the only other fd-5
      # user), unlike the nested status -> reconcile -> auto-refresh chain that
      # forces the distinct 6/7/8/9 fds.
      exec 5>"$QSTATE_LOCK"
      if ! flock -n 5; then
        json_error_obj "$(jq -nc \
          '{message: "another github-issue queue-state write is already in progress",
            cause: "queue_state_locked"}')"
      fi
      # Stamp version and write time so a resumer can sanity-check what it reads.
      local stamped tmpfile
      stamped="$(printf '%s' "$payload" | jq -c \
        --argjson v "$QUEUE_STATE_VERSION" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '. + {queue_state_version: $v, written_at: $ts}')"
      tmpfile="$(mktemp "${QSTATE_DIR}/.queue-state.XXXXXX")"
      printf '%s\n' "$stamped" >"$tmpfile"
      mv "$tmpfile" "$QSTATE_FILE"
      json_ok "$(jq -nc --arg f "$QSTATE_FILE" --argjson s "$stamped" \
        '{ok: true, path: $f, state: $s}')"
      ;;
    clear)
      rm -f "$QSTATE_FILE"
      json_ok "$(jq -nc --arg f "$QSTATE_FILE" '{ok: true, cleared: true, path: $f}')"
      ;;
    "")
      die "usage: github-issue queue-state <get|set --json '<json>'|clear>"
      ;;
    *)
      die "unknown queue-state action: ${action} (expected get, set, or clear)"
      ;;
  esac
}

# ── Entry point ──────────────────────────────────────────────────────────────

# Dispatch only when this file is executed as the command, not when it is
# sourced. The bats harness sources it to reach detect_existing_branch and
# friends; there BASH_SOURCE[0] != $0, so the functions are defined without
# dispatching. Keying on how the file was loaded (not an env var) means a stray
# `export` in the caller's environment cannot silently turn a real
# `github-issue setup` into an exit-0 no-op.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    setup | resume | status | push | audit | cleanup | transition | validate-cwd | check-ci | review-feedback | auto-merge | verify-landed | post-mortem)
      _JSON_MODE=1
      require_github_remote
      SUBCMD="${1//-/_}"
      shift
      "cmd_${SUBCMD}" "$@"
      ;;
    queue-state)
      # Pure local-filesystem cursor persistence, no remote calls, so it stays
      # provider-agnostic and skips require_github_remote (github-issues-auto
      # drives GitHub and Forgejo batches alike).
      _JSON_MODE=1
      shift
      cmd_queue_state "$@"
      ;;
    *)
      die "usage: github-issue <subcommand> [args] -- run 'github-issue --help' for details"
      ;;
  esac
fi
