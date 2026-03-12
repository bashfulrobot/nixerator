# dependabot: AI-powered worktree workflow for Dependabot alert remediation

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: dependabot [<alert-number>]"
  info "Creates an isolated git worktree and launches Claude to fix a Dependabot alert."
  info ""
  info "Workflow:"
  info "  dependabot <number>  -- new worktree + Claude session + PR"
  info "  dependabot <number>  -- resume existing worktree (if alert matches)"
  info "  dependabot           -- pick from open alerts or active worktrees"
  exit 0
fi

# ── Helper functions ─────────────────────────────────────────────────────────

fetch_alert() {
  local alert_number="$1"
  gh api "repos/{owner}/{repo}/dependabot/alerts/${alert_number}"
}

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
    --arg type             "dependabot" \
    --arg phase            "setup" \
    --arg branch           "$branch" \
    --arg wt_path          "$wt_path" \
    --arg session_id       "" \
    --arg pr_url           "" \
    --arg alert_number     "$alert_number" \
    --arg package_name     "$package_name" \
    --arg manifest_path    "$manifest_path" \
    --arg patched_version  "$patched_version" \
    --arg advisory_summary "$advisory_summary" \
    --arg started_at       "$timestamp" \
    --arg updated_at       "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path,
      session_id: $session_id, pr_url: $pr_url,
      alert_number: $alert_number, package_name: $package_name,
      manifest_path: $manifest_path, patched_version: $patched_version,
      advisory_summary: $advisory_summary,
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

# ── Alert picker (no-arg mode) ───────────────────────────────────────────────

pick_alert() {
  # Check for existing dependabot worktrees first
  local wt_base
  wt_base="$(worktree_base)"

  local -a wt_descriptions=()
  local -a wt_paths=()
  local -a wt_alert_numbers=()

  if [[ -d "$wt_base" ]]; then
    while IFS= read -r -d '' wt_dir; do
      local state_file="${wt_dir}/.worktree-state.json"
      if [[ -f "$state_file" ]]; then
        local wt_type
        wt_type="$(jq -r '.type' "$state_file")"
        if [[ "$wt_type" == "dependabot" ]]; then
          local pkg phase pr_url alert_num summary
          alert_num="$(jq -r '.alert_number' "$state_file")"
          pkg="$(jq -r '.package_name' "$state_file")"
          summary="$(jq -r '.advisory_summary' "$state_file")"
          phase="$(jq -r '.phase' "$state_file")"
          pr_url="$(jq -r '.pr_url // ""' "$state_file")"
          local label="#${alert_num} ${pkg}: ${summary} [${phase}]"
          if [[ -n "$pr_url" ]]; then
            label="#${alert_num} ${pkg}: ${summary} [${phase}] ${pr_url}"
          fi
          wt_descriptions+=("$label")
          wt_paths+=("$wt_dir")
          wt_alert_numbers+=("$alert_num")
        fi
      fi
    done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -name 'dependabot-*' -print0 2>/dev/null)
  fi

  # Fetch open alerts from GitHub
  info "fetching open Dependabot alerts..."
  local alerts_json
  alerts_json="$(gh api 'repos/{owner}/{repo}/dependabot/alerts?state=open' 2>/dev/null || echo '[]')"

  local alert_count
  alert_count="$(printf '%s' "$alerts_json" | jq 'length')"

  # Build combined menu
  local -a menu_items=()
  local -a menu_types=()  # "worktree" or "alert"
  local -a menu_ids=()    # wt index or alert number

  # Add existing worktrees first
  local i
  for i in "${!wt_descriptions[@]}"; do
    menu_items+=("[active] ${wt_descriptions[$i]}")
    menu_types+=("worktree")
    menu_ids+=("$i")
  done

  # Add open alerts (skip any that already have worktrees)
  if [[ "$alert_count" -gt 0 ]]; then
    while IFS= read -r line; do
      local num pkg severity summary
      num="$(printf '%s' "$line" | jq -r '.number')"
      pkg="$(printf '%s' "$line" | jq -r '.dependency.package.name')"
      severity="$(printf '%s' "$line" | jq -r '.security_advisory.severity')"
      summary="$(printf '%s' "$line" | jq -r '.security_advisory.summary')"

      # Skip if worktree already exists for this alert
      local skip=0
      local j
      for j in "${!wt_alert_numbers[@]}"; do
        if [[ "${wt_alert_numbers[$j]}" == "$num" ]]; then
          skip=1
          break
        fi
      done
      if [[ $skip -eq 1 ]]; then
        continue
      fi

      menu_items+=("#${num} [${severity}] ${pkg} - ${summary}")
      menu_types+=("alert")
      menu_ids+=("$num")
    done < <(printf '%s' "$alerts_json" | jq -c '.[]')
  fi

  if [[ ${#menu_items[@]} -eq 0 ]]; then
    ok "no open Dependabot alerts and no active worktrees"
    exit 0
  fi

  local choice
  choice="$(printf '%s\n' "${menu_items[@]}" | gum choose --header "Dependabot alerts:" || die "aborted")"

  # Find matching selection
  for i in "${!menu_items[@]}"; do
    if [[ "${menu_items[$i]}" == "$choice" ]]; then
      if [[ "${menu_types[$i]}" == "worktree" ]]; then
        local idx="${menu_ids[$i]}"
        handle_existing_worktree "${wt_alert_numbers[$idx]}" "${wt_paths[$idx]}"
      else
        main "${menu_ids[$i]}"
      fi
      return
    fi
  done
}

# ── Existing worktree handling ───────────────────────────────────────────────

handle_existing_worktree() {
  local alert_number="$1" wt_path="$2"

  if [[ ! -f "${wt_path}/.worktree-state.json" ]]; then
    die "worktree exists but no state file found at ${wt_path}/.worktree-state.json"
  fi

  local phase branch pr_url package_name
  phase="$(read_state_field phase "$wt_path")"
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"
  package_name="$(read_state_field package_name "$wt_path")"

  # Detect merged/closed PR
  if [[ "$phase" == "pr_created" ]] && [[ -n "$pr_url" ]]; then
    local pr_state
    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")"
    if [[ "$pr_state" == "MERGED" ]] || [[ "$pr_state" == "CLOSED" ]]; then
      phase_cleanup "$alert_number" "$wt_path"
      return
    fi
  fi

  info "Alert #${alert_number} (${package_name}): phase ${phase}, branch ${branch}"
  if [[ -n "$pr_url" ]]; then
    info "PR: ${pr_url}"
  fi

  local choice
  choice="$(gum choose "Resume Claude" "Check PR" "Remove" "Abort" || die "aborted")"

  case "$choice" in
    "Resume Claude")
      phase_resume "$alert_number" "$wt_path"
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
  local alert_number="$1"
  local wt_path="$2"

  phase_claude_running "$wt_path"
  phase_claude_exited "$wt_path"
  phase_push_updates "$alert_number" "$wt_path"
}

# ── Phase functions ──────────────────────────────────────────────────────────

phase_setup() {
  local alert_number="$1"
  local wt_path="$2"

  section "Setup"

  info "fetching alert #${alert_number} metadata..."
  local alert_json
  alert_json="$(fetch_alert "$alert_number")"

  local alert_state
  alert_state="$(printf '%s' "$alert_json" | jq -r '.state')"
  if [[ "$alert_state" != "open" ]]; then
    die "alert #${alert_number} is ${alert_state}, not open"
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
  ok "branch: ${branch_name}"

  info "creating worktree..."
  mkdir -p "$(dirname "$wt_path")"
  git worktree add --no-checkout "$wt_path" -b "$branch_name"
  ok "worktree created at ${wt_path}"

  register_cleanup "$wt_path"

  checkout_and_unlock "$wt_path"

  info "writing state file..."
  create_dependabot_state "$branch_name" "$wt_path" "$alert_number" \
    "$package_name" "$manifest_path" "$patched_version" "$advisory_summary"
  ok "state file written"

  # Store full alert JSON for Claude's context
  printf '%s' "$alert_json" | jq '.' > "${wt_path}/.dependabot-alert.json"
  ok "alert context saved"

  # Disable cleanup trap -- worktree must survive interruption so user can resume
  _WT_CLEANUP_PATH=""

  set_phase "claude_running" "$wt_path"
  ok "setup complete"
}

phase_claude_running() {
  local wt_path="$1"

  section "Launching Claude"

  local skill_path="$HOME/.claude/skills/dependabot/SKILL.md"
  local branch
  branch="$(read_state_field branch "$wt_path")"

  local skill_content=""
  if [[ -f "$skill_path" ]]; then
    skill_content="$(cat "$skill_path")"
    ok "loaded SKILL.md"
  else
    warn "SKILL.md not found at ${skill_path}"
  fi

  # Build rich context from state and alert JSON
  local package_name manifest_path patched_version advisory_summary
  package_name="$(read_state_field package_name "$wt_path")"
  manifest_path="$(read_state_field manifest_path "$wt_path")"
  patched_version="$(read_state_field patched_version "$wt_path")"
  advisory_summary="$(read_state_field advisory_summary "$wt_path")"

  # Extract additional fields from saved alert JSON if available
  local vuln_range cve_id ghsa_id advisory_desc
  vuln_range="" cve_id="" ghsa_id="" advisory_desc=""
  if [[ -f "${wt_path}/.dependabot-alert.json" ]]; then
    vuln_range="$(jq -r '.security_vulnerability.vulnerable_version_range // ""' "${wt_path}/.dependabot-alert.json")"
    cve_id="$(jq -r '.security_advisory.cve_id // ""' "${wt_path}/.dependabot-alert.json")"
    ghsa_id="$(jq -r '.security_advisory.ghsa_id // ""' "${wt_path}/.dependabot-alert.json")"
    advisory_desc="$(jq -r '.security_advisory.description // ""' "${wt_path}/.dependabot-alert.json")"
  fi

  local system_prompt
  system_prompt="$(printf 'You are working in worktree %s on branch %s.\n\n%s' \
    "$wt_path" "$branch" "$skill_content")"

  local task_prompt
  task_prompt="$(printf 'Fix this Dependabot security vulnerability:\n\nPackage: %s\nManifest: %s\nVulnerable versions: %s\nPatched version: %s\nSummary: %s\nCVE: %s\nGHSA: %s\n\nAdvisory details:\n%s\n\nUpdate the package to at least version %s. Update both the dependency file and lock file. Verify the build still works if a build script exists.' \
    "$package_name" "$manifest_path" "$vuln_range" "$patched_version" \
    "$advisory_summary" "$cve_id" "$ghsa_id" "$advisory_desc" "$patched_version")"

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
        "$task_prompt"
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
          info "tip: run 'dependabot' to resume later"
          exit 0
          ;;
      esac
    else
      warn "no commits on branch -- nothing to push"
      info "worktree preserved at ${wt_path}"
      info "tip: run 'dependabot' to resume later"
      exit 0
    fi
  fi

  ok "${commit_count} commit(s) detected"
  set_phase "pushing" "$wt_path"
}

phase_push_and_pr() {
  local alert_number="$1"
  local wt_path="$2"

  section "Pushing and Creating PR"

  local branch package_name advisory_summary
  branch="$(read_state_field branch "$wt_path")"
  package_name="$(read_state_field package_name "$wt_path")"
  advisory_summary="$(read_state_field advisory_summary "$wt_path")"

  info "pushing branch ${branch}..."
  (cd "$wt_path" && safe_push "$branch")
  ok "branch pushed"

  local pr_title
  pr_title="$(printf 'security(%s): fix %s' "$package_name" "$advisory_summary")"
  # Truncate to 72 chars for clean PR titles
  if [[ ${#pr_title} -gt 72 ]]; then
    pr_title="${pr_title:0:69}..."
  fi

  local pr_body
  pr_body="$(printf '## Summary\n- Fixes Dependabot alert #%s\n- Package: %s\n- %s\n\n## Test plan\n- [ ] Build succeeds\n- [ ] CI passes' \
    "$alert_number" "$package_name" "$advisory_summary")"

  info "creating PR..."
  local pr_url
  pr_url="$(cd "$wt_path" && gh pr create \
    --title "$pr_title" \
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
}

phase_push_updates() {
  local alert_number="$1"
  local wt_path="$2"

  section "Pushing Updates"

  local branch pr_url
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path" 2>/dev/null || echo "")"

  if [[ -z "$pr_url" ]]; then
    # No PR yet, create one
    phase_push_and_pr "$alert_number" "$wt_path"
    return
  fi

  info "pushing updates to ${branch}..."
  (cd "$wt_path" && git push origin "$branch")
  ok "updates pushed to PR: ${pr_url}"

  set_phase "pr_created" "$wt_path"
}

phase_cleanup() {
  local alert_number="$1" wt_path="$2"

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

  # Delete local and remote branches
  git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
  git push origin --delete "$branch" 2>/dev/null || true
  ok "branches cleaned up"

  ok "cleanup complete for alert #${alert_number}"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local alert_number="$1"
  local pkg_slug

  # Fetch alert to get package name for worktree path
  info "fetching alert #${alert_number}..."
  local alert_json
  alert_json="$(fetch_alert "$alert_number")"
  local package_name
  package_name="$(printf '%s' "$alert_json" | jq -r '.dependency.package.name')"
  pkg_slug="$(slugify "$package_name")"

  local wt_path
  wt_path="$(worktree_base)/dependabot-${alert_number}-${pkg_slug}"

  assert_clean_tree
  check_orphan_worktrees

  # Existing worktree check
  if [[ -d "$wt_path" ]]; then
    handle_existing_worktree "$alert_number" "$wt_path"
    exit 0
  fi

  phase_setup "$alert_number" "$wt_path"
  phase_claude_running "$wt_path"
  phase_claude_exited "$wt_path"
  phase_push_and_pr "$alert_number" "$wt_path"

  _WT_CLEANUP_PATH=""
  ok "done! PR created for alert #${alert_number}"
}

# ── Entry point ──────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  pick_alert
else
  ALERT_NUMBER="$1"
  main "$ALERT_NUMBER"
fi
