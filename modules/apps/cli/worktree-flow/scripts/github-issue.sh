# github-issue: AI-powered worktree workflow for GitHub issues

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: github-issue [<issue-number>]"
  info "Creates an isolated git worktree and launches Claude to work on a GitHub issue."
  info ""
  info "Workflow:"
  info "  github-issue <number>  -- new worktree + Claude session + PR"
  info "  github-issue <number>  -- resume existing worktree (if issue matches)"
  info "  github-issue           -- pick from active issue worktrees"
  exit 0
fi

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

  if [[ -n "$branch_type" ]]; then
    printf '%s' "$branch_type"
  else
    # Fallback: prompt user
    gum choose --header "Branch type:" \
      "feat" "fix" "docs" "refactor" "test" "ci" "chore" "revert" "deps" ||
      die "aborted"
  fi
}

build_branch_name() {
  local branch_type="$1"
  local issue_number="$2"
  local title="$3"
  local slug
  slug="$(slugify "$title")"
  # Prefix is "<type>/<number>-", keep total under ~50 chars
  local prefix_len=$((${#branch_type} + 1 + ${#issue_number} + 1))
  local max_slug=$((50 - prefix_len))
  if [[ $max_slug -lt 5 ]]; then
    max_slug=5
  fi
  slug="${slug:0:$max_slug}"
  slug="${slug%-}" # trim trailing dash from truncation
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
    --arg type "issue" \
    --arg phase "setup" \
    --arg branch "$branch" \
    --arg wt_path "$wt_path" \
    --arg session_id "" \
    --arg pr_url "" \
    --arg issue_number "$issue_number" \
    --arg issue_title "$issue_title" \
    --arg issue_body "$issue_body" \
    --arg started_at "$timestamp" \
    --arg updated_at "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path,
      session_id: $session_id, pr_url: $pr_url,
      issue_number: $issue_number, issue_title: $issue_title, issue_body: $issue_body,
      started_at: $started_at, updated_at: $updated_at}')"
  write_state "$json" "$wt_path"
}

# ── Worktree picker (no-arg mode) ───────────────────────────────────────────

pick_worktree() {
  sweep_merged_worktrees "issue-"

  # Check for existing issue worktrees
  local wt_base
  wt_base="$(worktree_base)"

  local -a wt_descriptions=()
  local -a wt_paths=()
  local -a wt_issue_numbers=()

  local state_file wt_type title phase pr_url issue_num label review_status
  if [[ -d "$wt_base" ]]; then
    while IFS= read -r -d '' wt_dir; do
      state_file="${wt_dir}/.worktree-state.json"
      if [[ -f "$state_file" ]]; then
        wt_type="$(jq -r '.type' "$state_file")"
        if [[ "$wt_type" == "issue" ]]; then
          issue_num="$(jq -r '.issue_number' "$state_file")"
          title="$(jq -r '.issue_title' "$state_file")"
          phase="$(jq -r '.phase' "$state_file")"
          pr_url="$(jq -r '.pr_url // ""' "$state_file")"
          label="#${issue_num}: ${title} [${phase}]"
          if [[ -n "$pr_url" ]]; then
            label="#${issue_num}: ${title} [${phase}] ${pr_url}"
            review_status="$(gh pr view "$pr_url" --json reviewDecision --jq '.reviewDecision' 2>/dev/null)" || review_status=""
            if [[ -n "$review_status" ]] && [[ "$review_status" != "null" ]]; then
              label="${label} (${review_status,,})"
            fi
          fi
          wt_descriptions+=("$label")
          wt_paths+=("$wt_dir")
          wt_issue_numbers+=("$issue_num")
        fi
      fi
    done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name 'issue-*' -print0 2>/dev/null)
  fi

  # Fetch open issues from GitHub (oldest 10)
  info "fetching open issues..."
  local issues_json
  issues_json="$(gh issue list --state open --limit 10 --json number,title,labels --jq 'sort_by(.number) | .[:10]' 2>/dev/null || echo '[]')"

  # Build combined menu
  local -a menu_items=()
  local -a menu_types=() # "worktree" or "issue"
  local -a menu_ids=()   # wt index or issue number

  # Add existing worktrees first
  local i
  for i in "${!wt_descriptions[@]}"; do
    menu_items+=("[active] ${wt_descriptions[$i]}")
    menu_types+=("worktree")
    menu_ids+=("$i")
  done

  # Add open issues (skip any that already have worktrees)
  local num skip j issue_title issue_labels
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    num="$(printf '%s' "$line" | jq -r '.number')"
    issue_title="$(printf '%s' "$line" | jq -r '.title')"
    issue_labels="$(printf '%s' "$line" | jq -r '[.labels[].name] | join(", ")')"

    # Skip if worktree already exists for this issue
    skip=0
    for j in "${!wt_issue_numbers[@]}"; do
      if [[ "${wt_issue_numbers[$j]}" == "$num" ]]; then
        skip=1
        break
      fi
    done
    if [[ $skip -eq 1 ]]; then
      continue
    fi

    local issue_label="#${num}: ${issue_title}"
    if [[ -n "$issue_labels" ]]; then
      issue_label="${issue_label} [${issue_labels}]"
    fi
    menu_items+=("$issue_label")
    menu_types+=("issue")
    menu_ids+=("$num")
  done < <(printf '%s' "$issues_json" | jq -c '.[]')

  if [[ ${#menu_items[@]} -eq 0 ]]; then
    ok "no open issues and no active worktrees"
    exit 0
  fi

  local choice
  choice="$(printf '%s\n' "${menu_items[@]}" | gum choose --header "GitHub issues:" || die "aborted")"

  # Find matching selection
  for i in "${!menu_items[@]}"; do
    if [[ "${menu_items[$i]}" == "$choice" ]]; then
      if [[ "${menu_types[$i]}" == "worktree" ]]; then
        local idx="${menu_ids[$i]}"
        handle_existing_worktree "${wt_issue_numbers[$idx]}" "${wt_paths[$idx]}"
      else
        main "${menu_ids[$i]}"
      fi
      return
    fi
  done
}

# ── Existing worktree handling ───────────────────────────────────────────────

handle_existing_worktree() {
  local issue_number="$1" wt_path="$2"

  if [[ ! -f "${wt_path}/.worktree-state.json" ]]; then
    die "worktree exists but no state file found at ${wt_path}/.worktree-state.json"
  fi

  local phase branch pr_url
  phase="$(read_state_field phase "$wt_path")"
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"

  # Detect merged/closed PR (regardless of local phase)
  local pr_state=""
  if [[ -n "$pr_url" ]]; then
    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null)" || pr_state=""
  fi
  # Fallback: check branch merge status (covers PRs created outside workflow)
  if [[ "$pr_state" != "MERGED" ]]; then
    if is_branch_merged "$branch"; then
      pr_state="MERGED"
    fi
  fi

  # Merged PR → auto-cleanup
  if [[ "$pr_state" == "MERGED" ]]; then
    backfill_pr_url "$branch" "$wt_path"
    phase_cleanup "$issue_number" "$wt_path"
    return
  fi

  info "Issue #${issue_number}: phase ${phase}, branch ${branch}"
  if [[ -n "$pr_url" ]]; then
    info "PR: ${pr_url}"
  fi

  # Build menu -- closed PR warns, but full options always available
  if [[ "$pr_state" == "CLOSED" ]]; then
    warn "PR was closed without merging"
  fi
  local -a menu_opts=("Resume Claude" "Clean up")
  if [[ "$phase" == "pr_created" ]]; then
    menu_opts+=("Check PR")
  elif [[ "$phase" == "pushing" ]] || [[ "$phase" == "claude_exited" ]]; then
    menu_opts+=("Retry Push+PR")
  fi
  menu_opts+=("Remove" "Abort")

  local choice
  choice="$(gum choose "${menu_opts[@]}" || die "aborted")"

  case "$choice" in
    "Clean up")
      phase_cleanup "$issue_number" "$wt_path"
      ;;
    "Resume Claude")
      phase_resume "$issue_number" "$wt_path"
      ;;
    "Check PR")
      if [[ -z "$pr_url" ]]; then
        warn "no PR created yet"
      else
        gh pr view "$pr_url" --web 2>/dev/null || info "PR: ${pr_url}"
      fi
      ;;
    "Retry Push+PR")
      local state_issue_num
      state_issue_num="$(read_state_field issue_number "$wt_path")"
      phase_push_and_pr "$state_issue_num" "$wt_path"
      ;;
    "Remove")
      if gum confirm "Remove worktree and delete branches? This cannot be undone."; then
        remove_worktree "$wt_path"
      else
        info "aborted"
      fi
      ;;
    "Abort")
      info "aborted"
      exit 0
      ;;
  esac
}

phase_resume() {
  local issue_number="$1"
  local wt_path="$2"

  _RESUME_DEPTH=0
  phase_claude_running "$wt_path"
  phase_claude_exited "$wt_path"
  phase_push_updates "$issue_number" "$wt_path"
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

  # Disable cleanup trap -- worktree must survive interruption so user can resume
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

  # Gather PR review context if a PR exists
  local pr_url review_context=""
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  if [[ -n "$pr_url" ]]; then
    local review_decision
    review_decision="$(gh pr view "$pr_url" --json reviewDecision --jq '.reviewDecision' 2>/dev/null)" || review_decision=""
    if [[ -n "$review_decision" ]] && [[ "$review_decision" != "null" ]]; then
      review_context="PR: ${pr_url} | Review status: ${review_decision}"
      if [[ "$review_decision" == "CHANGES_REQUESTED" ]]; then
        local review_comments
        review_comments="$(gh pr view "$pr_url" --json reviews \
          --jq '[.reviews[] | select(.state == "CHANGES_REQUESTED") | .body] | join("\n---\n")' 2>/dev/null)" || review_comments=""
        if [[ -n "$review_comments" ]]; then
          review_context="${review_context}

Review comments:
${review_comments}"
        fi
        ok "PR has changes requested -- passing review context to Claude"
      fi
    fi
  fi

  local system_prompt
  system_prompt="$(printf 'You are working on a GitHub issue in worktree %s on branch %s.\n%s\n\n%s' \
    "$wt_path" "$branch" "$review_context" "$skill_content")"

  local task_prompt
  if [[ -n "$pr_url" ]] && [[ "${review_decision:-}" == "CHANGES_REQUESTED" ]]; then
    task_prompt="$(printf 'PR review requested changes. Address the review feedback and push updates.\n\nOriginal issue:\n%s' "$issue_body")"
  else
    task_prompt="$(printf 'Implement this GitHub issue:\n\n%s' "$issue_body")"
  fi

  # Check for existing session_id (resume path)
  local session_id
  session_id="$(read_state_field session_id "$wt_path")"

  info "launching claude..."

  if [[ -n "$session_id" ]]; then
    # Resume existing session
    info "resuming session: ${session_id}"
    warn "resuming previous session -- if context seems stale, exit and re-run with a fresh session"
    run_claude "$wt_path" \
      --dangerously-skip-permissions \
      --resume "$session_id"
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

    run_claude "$wt_path" \
      --dangerously-skip-permissions \
      --system-prompt "$system_prompt" \
      --session-id "$session_id" \
      "$task_prompt"
  fi

  set_phase "claude_exited" "$wt_path"
  ok "claude session ended"
}

phase_claude_exited() {
  local wt_path="$1"

  _RESUME_DEPTH=$((${_RESUME_DEPTH:-0} + 1))
  if [[ $_RESUME_DEPTH -gt 5 ]]; then
    warn "resumed 5 times without committing -- exiting to avoid deep recursion"
    info "worktree preserved, run the command again to resume"
    exit 0
  fi

  section "Checking Changes"

  local default_br branch
  default_br="$(default_branch)"
  branch="$(read_state_field branch "$wt_path")"

  # Check for committed changes on this branch vs default branch
  local commit_count
  commit_count="$(git -C "$wt_path" rev-list --count "${default_br}..${branch}")"
  if [[ "$commit_count" -eq 0 ]]; then
    # Check for uncommitted work in the worktree
    local dirty
    dirty="$(git -C "$wt_path" status --porcelain)"
    if [[ -n "$dirty" ]]; then
      warn "uncommitted changes detected in worktree"
      local choice
      choice="$(gum choose --header "No commits yet, but changes exist:" \
        "Resume Claude" "Exit (keep worktree)" || die "aborted")"
      case "$choice" in
        "Resume Claude")
          phase_claude_running "$wt_path"
          phase_claude_exited "$wt_path"
          return
          ;;
        "Exit (keep worktree)")
          info "worktree preserved at ${wt_path}"
          info "tip: run 'github-issue' to resume later"
          exit 0
          ;;
      esac
    else
      warn "no commits on branch -- nothing to push"
      info "worktree preserved at ${wt_path}"
      info "tip: run 'github-issue' to resume later"
      exit 0
    fi
  fi

  ok "${commit_count} commit(s) detected"
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
  (cd "$wt_path" && safe_push "$branch")
  ok "branch pushed"

  # Build summary from issue reference + commit messages
  local default_br commit_log pr_body
  default_br="$(default_branch)"
  commit_log="$(git -C "$wt_path" log --format='- %s%n%w(0,2,2)%b' "${default_br}..${branch}")"
  pr_body="$(printf '## Summary\nCloses #%s: %s\n\n%s' \
    "$issue_number" "$issue_title" "$commit_log")"

  info "creating PR..."
  local pr_url
  pr_url="$(cd "$wt_path" && gh pr create \
    --title "$issue_title" \
    --body "$pr_body" \
    --head "$branch")"
  ok "PR created: ${pr_url}"

  # Write pr_url to state file
  local current updated timestamp
  current="$(cat "${wt_path}/.worktree-state.json")"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(printf '%s' "$current" | jq \
    --arg url "$pr_url" \
    --arg t "$timestamp" \
    '.pr_url = $url | .updated_at = $t')"
  write_state "$updated" "$wt_path"

  set_phase "pr_created" "$wt_path"

  # Comment on issue with PR link
  info "commenting on issue #${issue_number}..."
  gh issue comment "$issue_number" --body "PR ready for review: $pr_url"
  ok "issue comment posted"
}

phase_push_updates() {
  local issue_number="$1"
  local wt_path="$2"

  section "Pushing Updates"

  local branch pr_url
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"

  if [[ -z "$pr_url" ]]; then
    # No PR yet, create one
    phase_push_and_pr "$issue_number" "$wt_path"
    return
  fi

  info "pushing updates to ${branch}..."
  (cd "$wt_path" && git push origin "$branch")
  ok "updates pushed to PR: ${pr_url}"

  set_phase "pr_created" "$wt_path"
}

phase_cleanup() {
  local issue_number="$1" wt_path="$2"

  section "Post-merge Cleanup"

  local branch pr_url pr_number default_br
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  pr_number="$(printf '%s' "$pr_url" | grep -oE '[0-9]+$')"
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

  # Delete local and remote branches
  git branch -D "$branch" 2>/dev/null || true
  git push origin --delete "$branch" 2>/dev/null || true
  ok "branches cleaned up"

  # Comment on issue with resolution summary and close it
  if [[ -n "$pr_number" ]]; then
    local resolution_msg="Resolved via #${pr_number}. Branch and worktree cleaned up."
    gh issue comment "$issue_number" --body "$resolution_msg" 2>/dev/null || true
    gh issue close "$issue_number" 2>/dev/null || true
    ok "resolution comment posted and issue closed"
  fi

  ok "cleanup complete for issue #${issue_number}"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local issue_number="$1"
  local wt_path
  wt_path="$(worktree_base)/issue-${issue_number}"

  # Pre-flight
  fetch_remote
  sweep_merged_worktrees "issue-"
  check_orphan_worktrees

  # If sweep just cleaned up this exact worktree, we're done
  if was_swept "$wt_path"; then
    ok "worktree cleaned up (PR merged/closed) -- nothing to do"
    exit 0
  fi

  # Existing worktree check (no clean tree needed for resume)
  if [[ -d "$wt_path" ]]; then
    handle_existing_worktree "$issue_number" "$wt_path"
    exit 0
  fi

  # Clean tree required only for new worktree creation
  assert_clean_tree

  _RESUME_DEPTH=0
  phase_setup "$issue_number" "$wt_path"
  phase_claude_running "$wt_path"
  phase_claude_exited "$wt_path"
  phase_push_and_pr "$issue_number" "$wt_path"

  _WT_CLEANUP_PATH=""
  ok "done! PR created for issue #${issue_number}"
}

# ── Entry point ──────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  pick_worktree
else
  ISSUE_NUMBER="$1"
  main "$ISSUE_NUMBER"
fi
