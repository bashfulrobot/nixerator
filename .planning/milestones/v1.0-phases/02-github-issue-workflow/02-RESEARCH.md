# Phase 2: github-issue Workflow - Research

**Researched:** 2026-03-11
**Domain:** bash shell scripting, gh CLI, git worktree lifecycle, claude-code CLI invocation
**Confidence:** HIGH

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Branch Naming**

- Type derived from GitHub issue labels via `gh` API: map common labels to gcmt types (bug->fix, enhancement->feat, documentation->docs, etc.)
- Supported branch types (matching gcmt): feat, fix, docs, refactor, test, ci, chore, revert, deps
- Fallback when no label matches: prompt user with `gum choose` from the 9 types
- Slug format: `<type>/<number>-<short-title>` (e.g., `feat/42-rate-limiting`), title slugified and truncated to ~50 chars total

**Resume and Re-invocation**

- When worktree already exists: show compact one-liner state summary (e.g., "Issue #42: phase claude_exited, branch feat/42-rate-limiting"), then `gum choose`: Resume / Remove & restart / Abort
- Resume skips to next incomplete phase (idempotent phase progression)
- Claude resume: try `--resume <session_id>` from state file first, fall back to fresh session if unavailable/expired
- State display is compact, not verbose dump

**PR Creation**

- PR title: use GitHub issue title as-is
- PR status: created as ready for review (not draft)
- PR body: uses SKILL.md Summary/Test plan template format
- After PR creation: auto-comment on the issue with PR link via `gh issue comment` (RF-02)

**Post-merge Cleanup**

- Merge detection: query PR state via `gh pr view --json state` using pr_url from state file
- Cleanup shows each step with ok/info messages (matches existing terminal style)
- Resolution comment on issue/PR: short one-liner (e.g., "Resolved via #<pr-number>. Branch and worktree cleaned up.")
- Idempotent cleanup: skip missing pieces (e.g., worktree already deleted), still clean branches and post comments

### Claude's Discretion

- Label-to-type mapping details (which labels map to which types beyond the obvious ones)
- Exact `gh api` queries for issue metadata and PR state
- How to extract/format the Summary/Test plan body from Claude's commits
- Orphan worktree detection implementation (WT-02)

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>

## Phase Requirements

| ID    | Description                                                                           | Research Support                                                                                           |
| ----- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| WT-01 | Script creates worktree with proper branch naming (`fix/<slug>`, `feat/<slug>`, etc.) | `gh issue view --json labels,title` verified; label mapping and gum choose fallback documented             |
| WT-02 | Script detects and offers to clean orphaned worktrees on startup                      | `git worktree list --porcelain` output format confirmed; pattern documented                                |
| WT-05 | Cleanup sequences as worktree remove, then prune, then branch delete                  | `git worktree remove`, `git worktree prune`, `git branch -d`, `git push origin --delete` patterns verified |
| WT-06 | Re-invocation with same issue number resumes from state file                          | State file read pattern established; phase dispatch logic documented                                       |
| WT-07 | Script errors if worktree already exists (with option to resume)                      | `gum choose` pattern for Resume/Remove/Abort documented; set -e safe                                       |
| RF-01 | github-issue flow pushes branch and creates PR via `gh pr create`                     | `gh pr create --title --body --head` flags verified against gh 2.87.3                                      |
| RF-02 | github-issue flow comments on issue linking the PR                                    | `gh issue comment <number> --body` flag verified                                                           |
| PM-01 | github-issue detects merged PR on re-invocation and enters cleanup phase              | `gh pr view <url> --json state` returns `MERGED`/`OPEN`/`CLOSED`; documented                               |
| PM-02 | Cleanup switches to default branch, pulls, deletes local and remote branches          | git checkout/pull pattern; `git branch -d` + `git push origin --delete` documented                         |
| PM-03 | Cleanup removes worktree directory and prunes                                         | `git worktree remove --force` + `git worktree prune` sequence documented                                   |
| PM-04 | Cleanup comments on issue and PR with resolution summary                              | `gh issue comment` and `gh pr comment` flags verified                                                      |

</phase_requirements>

## Summary

Phase 2 replaces the github-issue.sh stub with a complete end-to-end workflow. The phase is entirely bash scripting -- no new Nix primitives, no new dependencies beyond what Phase 1 already declared. The script uses `gh` CLI (already in runtimeInputs) for all GitHub operations, and the `claude` binary from `pkgs.llm-agents.claude-code` (must be added to runtimeInputs).

The script is organized as a linear phase dispatcher. Each invocation reads the state file (or creates it), determines which phase to run next, and runs it idempotently. Phases are: setup, claude_running, claude_exited, pushing, pr_created, merged, cleanup_done. Re-invocation automatically resumes from the last incomplete phase.

The critical new capability in Phase 2 is the `CLAUDECODE` environment variable handling. The `claude` binary refuses to launch inside an existing Claude session (it detects `CLAUDECODE=1`). The github-issue script must `unset CLAUDECODE` before launching Claude. This is not documented in claude --help but was discovered empirically during research.

**Primary recommendation:** Structure the script as a phase-dispatch function with explicit phase guards. Each phase function checks its own preconditions, executes, updates state, then returns. The main function loops over phases until complete or interrupted.

## Standard Stack

### Core

| Library                     | Version          | Purpose                                                            | Why Standard                               |
| --------------------------- | ---------------- | ------------------------------------------------------------------ | ------------------------------------------ |
| pkgs.gh                     | nixpkgs (2.87.3) | Issue metadata, PR create, issue/PR comments, PR state             | Already in runtimeInputs from Phase 1      |
| pkgs.llm-agents.claude-code | 2.1.72 (current) | Launch Claude session in worktree                                  | Must be added to runtimeInputs for Phase 2 |
| pkgs.jq                     | nixpkgs          | Parse gh JSON output, state file read/write                        | Already in runtimeInputs from Phase 1      |
| pkgs.gum                    | nixpkgs          | `gum choose` for branch type picker and resume/remove/abort prompt | Already in runtimeInputs from Phase 1      |
| pkgs.git                    | nixpkgs          | Worktree create, branch ops, push, checkout                        | Already in runtimeInputs from Phase 1      |
| pkgs.coreutils              | nixpkgs          | mktemp for atomic writes                                           | Already in runtimeInputs from Phase 1      |

### runtimeInputs addition for Phase 2

The only change to `default.nix` is adding `pkgs.llm-agents.claude-code` to both command's `runtimeInputs`:

```nix
runtimeInputs = with pkgs; [
  git
  git-crypt
  gum
  gh
  jq
  coreutils
  gnused
  findutils
  llm-agents.claude-code   # NEW in Phase 2
];
```

### Alternatives Considered

| Instead of                                    | Could Use                               | Tradeoff                                                                        |
| --------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------- |
| `gum choose` for branch type picker           | `select` shell builtin                  | gum is already a dep, provides better UX with arrow keys                        |
| `gh pr view --json state` for merge detection | `gh pr view <url>` and parse text       | `--json state` gives clean machine-readable `MERGED`/`OPEN`/`CLOSED`            |
| Inline PR body with heredoc                   | `gh pr create --body-file -` from stdin | `--body` flag with `$'...'` quoting works; heredoc more readable for multi-line |

## Architecture Patterns

### Recommended Script Structure

```
scripts/github-issue.sh
├── argument parsing / help
├── pre-flight checks (assert_clean_tree, check for existing worktree)
├── existing worktree handler (resume / remove / abort)
├── Phase: setup
│   ├── fetch issue metadata (gh issue view --json)
│   ├── determine branch type (label map + gum fallback)
│   ├── slugify title, construct branch name
│   ├── git worktree add + register_cleanup
│   ├── unlock_git_crypt
│   └── create_state + set_phase claude_running
├── Phase: claude_running
│   ├── build claude prompt (SKILL.md + issue body + repo context)
│   ├── unset CLAUDECODE (CRITICAL: prevents nested session refusal)
│   ├── launch claude (dangerously-skip-permissions, stream-json)
│   ├── capture session_id from stream output
│   └── set_phase claude_exited
├── Phase: claude_exited
│   ├── check git diff --quiet HEAD (any changes?)
│   ├── if no changes: warn and exit
│   └── set_phase pushing
├── Phase: pushing
│   ├── safe_push <branch>
│   └── set_phase pr_created (after gh pr create)
├── Phase: pr_created
│   ├── gh pr create --title --body
│   ├── capture PR URL, write to state file
│   ├── gh issue comment with PR link
│   └── ok + info cleanup instructions
└── merge detection (on re-invocation after pr_created)
    ├── gh pr view <pr_url> --json state
    ├── if MERGED: enter cleanup sequence
    └── cleanup: switch branch, pull, delete local+remote, worktree remove, comments
```

### Pattern 1: Phase Dispatcher

**What:** Each invocation reads current phase from state file, jumps to the appropriate function, executes idempotently.

**When to use:** Every re-invocation of the script.

```bash
# Source: logical pattern for idempotent phase progression
main() {
  local ISSUE_NUMBER="$1"
  local WT_PATH
  WT_PATH="$(worktree_base)/issue-${ISSUE_NUMBER}"

  # Check for existing worktree
  if [[ -d "$WT_PATH" ]]; then
    handle_existing_worktree "$ISSUE_NUMBER" "$WT_PATH"
    return
  fi

  # Fresh start: run all phases in sequence
  phase_setup "$ISSUE_NUMBER" "$WT_PATH"
  phase_claude_running "$WT_PATH"
  phase_claude_exited "$WT_PATH"
  phase_pushing "$WT_PATH"
  phase_pr_created "$ISSUE_NUMBER" "$WT_PATH"
}
```

### Pattern 2: Existing Worktree Handler (WT-06, WT-07)

**What:** When worktree exists, read state, show compact summary, offer Resume/Remove & restart/Abort via gum choose.

```bash
handle_existing_worktree() {
  local issue_number="$1"
  local wt_path="$2"
  local state_file="${wt_path}/.worktree-state.json"

  if [[ ! -f "$state_file" ]]; then
    die "worktree exists but no state file found at ${state_file}"
  fi

  local phase branch
  phase="$(read_state_field phase "$wt_path")"
  branch="$(read_state_field branch "$wt_path")"

  # Check if merged (PM-01)
  local pr_url
  pr_url="$(read_state_field pr_url "$wt_path")"
  if [[ "$phase" == "pr_created" && -n "$pr_url" ]]; then
    local pr_state
    pr_state="$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")"
    if [[ "$pr_state" == "MERGED" ]]; then
      phase_cleanup "$issue_number" "$wt_path"
      return
    fi
  fi

  # Show compact summary and offer choice
  info "Issue #${issue_number}: phase ${phase}, branch ${branch}"
  local choice
  choice="$(gum choose "Resume" "Remove & restart" "Abort")" || die "aborted"

  case "$choice" in
    "Resume")
      phase_resume "$issue_number" "$wt_path" "$phase"
      ;;
    "Remove & restart")
      phase_remove_worktree "$wt_path"
      main "$issue_number"
      ;;
    "Abort")
      info "aborted"
      exit 0
      ;;
  esac
}
```

### Pattern 3: Issue Metadata Fetch + Branch Naming (WT-01)

**What:** Fetch issue title and labels via `gh issue view --json`, derive branch type from label map, fall back to gum choose.

```bash
# Source: gh 2.87.3 verified -- JSON fields: labels, title
# Label objects have .name field

fetch_issue_metadata() {
  local issue_number="$1"
  gh issue view "$issue_number" --json title,labels
}

derive_branch_type() {
  local labels_json="$1"  # JSON array of {name: "..."} objects
  # Map labels to branch types
  local label
  label="$(printf '%s' "$labels_json" | jq -r '.[].name' | head -1)"

  case "$label" in
    bug|"Bug")               printf 'fix'      ;;
    enhancement|"Feature")   printf 'feat'     ;;
    documentation|"Docs")    printf 'docs'     ;;
    refactor|"Refactor")     printf 'refactor' ;;
    test|"Tests")            printf 'test'     ;;
    ci|"CI")                 printf 'ci'       ;;
    chore|"Chore")           printf 'chore'    ;;
    revert|"Revert")         printf 'revert'   ;;
    dependencies|"Deps")     printf 'deps'     ;;
    *)
      # Fallback: prompt user
      gum choose --header "Branch type:" \
        "feat" "fix" "docs" "refactor" "test" "ci" "chore" "revert" "deps"
      ;;
  esac
}

build_branch_name() {
  local branch_type="$1"
  local issue_number="$2"
  local title="$3"
  local slug
  slug="$(slugify "$title")"
  # Total branch name target: ~50 chars
  # "feat/42-" = 8 chars, leaving 42 for slug
  slug="${slug:0:42}"
  slug="${slug%-}"  # trim trailing dash if truncated mid-word
  printf '%s/%s-%s' "$branch_type" "$issue_number" "$slug"
}
```

### Pattern 4: Claude Invocation (with CLAUDECODE workaround)

**What:** Unset CLAUDECODE before launching claude to prevent nested session refusal. Use --dangerously-skip-permissions. Capture session_id from stream-json for resume support.

```bash
# CRITICAL: claude refuses to launch if CLAUDECODE=1 (set by parent claude session)
# The worktree sessions are intended to be launched from a terminal, but
# CLAUDECODE must be unset defensively for all launch paths.
phase_claude_running() {
  local wt_path="$1"

  section "Launching Claude"

  local skill_path="$HOME/.claude/skills/github-issue/SKILL.md"
  local issue_body
  issue_body="$(read_state_field issue_body "$wt_path")"
  local branch
  branch="$(read_state_field branch "$wt_path")"

  local prompt
  prompt="$(printf 'You are working on a GitHub issue in worktree %s on branch %s.\n\n%s\n\nIssue:\n%s' \
    "$wt_path" "$branch" "$(cat "$skill_path" 2>/dev/null)" "$issue_body")"

  # Check for existing session_id (resume path)
  local session_id
  session_id="$(read_state_field session_id "$wt_path")"

  set_phase "claude_running" "$wt_path"

  # Unset CLAUDECODE to allow launching from within a Claude session
  # Also change working directory to the worktree
  local resume_flags=""
  if [[ -n "$session_id" ]]; then
    resume_flags="--resume $session_id"
  fi

  # Launch claude; capture exit code; never fail on non-zero (user may Ctrl+C)
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
    | jq -r 'select(.type == "system") | .session_id // empty' \
    | head -1 > /tmp/wf-session-id-$$
  ) || true

  # Write captured session_id to state
  local captured_id
  captured_id="$(cat /tmp/wf-session-id-$$ 2>/dev/null || echo "")"
  rm -f /tmp/wf-session-id-$$

  if [[ -n "$captured_id" ]]; then
    local current updated timestamp
    current="$(cat "${wt_path}/.worktree-state.json")"
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    updated="$(printf '%s' "$current" | jq \
      --arg sid "$captured_id" \
      --arg t "$timestamp" \
      '.session_id = $sid | .updated_at = $t')"
    write_state "$updated" "$wt_path"
  fi

  set_phase "claude_exited" "$wt_path"
}
```

### Pattern 5: PR Creation (RF-01, RF-02)

**What:** Push branch, create PR with Summary/Test plan body, comment on issue.

```bash
phase_pr_created() {
  local issue_number="$1"
  local wt_path="$2"

  section "Creating PR"

  local branch issue_title
  branch="$(read_state_field branch "$wt_path")"
  issue_title="$(read_state_field issue_title "$wt_path")"

  # Build PR body using SKILL.md format
  local pr_body
  pr_body="$(printf '## Summary\n- Implements #%s: %s\n\n## Test plan\n- [ ] Manual verification of changes\n- [ ] CI passes' \
    "$issue_number" "$issue_title")"

  set_phase "pushing" "$wt_path"
  (cd "$wt_path" && safe_push "$branch")

  set_phase "pr_created" "$wt_path"
  local pr_url
  pr_url="$(cd "$wt_path" && gh pr create \
    --title "$issue_title" \
    --body "$pr_body" \
    --head "$branch")"

  # Write pr_url to state file
  local current updated timestamp
  current="$(cat "${wt_path}/.worktree-state.json")"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(printf '%s' "$current" | jq \
    --arg url "$pr_url" \
    --arg t "$timestamp" \
    '.pr_url = $url | .updated_at = $t')"
  write_state "$updated" "$wt_path"

  # Comment on issue (RF-02)
  gh issue comment "$issue_number" --body "PR ready for review: $pr_url"

  ok "PR created: $pr_url"
}
```

### Pattern 6: Post-merge Cleanup (PM-01 through PM-04)

**What:** Detect MERGED state, run cleanup sequence idempotently.

```bash
phase_cleanup() {
  local issue_number="$1"
  local wt_path="$2"

  section "Post-merge Cleanup"

  local branch pr_url pr_number default
  branch="$(read_state_field branch "$wt_path")"
  pr_url="$(read_state_field pr_url "$wt_path")"
  pr_number="$(printf '%s' "$pr_url" | grep -oE '[0-9]+$')"
  default="$(default_branch)"

  # PM-02: switch to default branch and pull
  git checkout "$default"
  git pull origin "$default"

  # PM-03: remove worktree
  # Disable cleanup trap first (we're doing intentional removal)
  _WT_CLEANUP_PATH=""
  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true

  # PM-02: delete branches
  git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
  git push origin --delete "$branch" 2>/dev/null || true

  # PM-04: comment on issue and PR
  local resolution_msg
  resolution_msg="Resolved via #${pr_number}. Branch and worktree cleaned up."
  gh issue comment "$issue_number" --body "$resolution_msg" 2>/dev/null || true
  gh pr comment "$pr_url" --body "$resolution_msg" 2>/dev/null || true

  ok "cleanup complete"
}
```

### Pattern 7: Orphan Worktree Detection (WT-02)

**What:** On startup, scan for worktree directories under worktree_base that have no matching state file or whose branches no longer exist. Offer to clean them up.

```bash
check_orphan_worktrees() {
  local wt_base
  wt_base="$(worktree_base)"
  [[ -d "$wt_base" ]] || return 0

  local found_orphan=0
  while IFS= read -r -d '' wt_dir; do
    local state="${wt_dir}/.worktree-state.json"
    if [[ ! -f "$state" ]]; then
      warn "orphan worktree (no state file): $wt_dir"
      found_orphan=1
    fi
  done < <(find "$wt_base" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  if [[ $found_orphan -eq 1 ]]; then
    if gum confirm "Remove orphan worktrees?"; then
      git worktree prune
      ok "orphan worktrees pruned"
    fi
  fi
}
```

### Anti-Patterns to Avoid

- **Bare `gum confirm` or `gum choose` without `if`:** Always wrap in `if`; use `|| die "aborted"` for choose to handle Ctrl+C (exit 130).
- **Launching `claude` without `unset CLAUDECODE`:** The `claude` binary checks for `CLAUDECODE=1` and refuses to start if it is set (nested session protection). Always `unset CLAUDECODE` before invoking.
- **`set_phase` after a failing gh command:** Set phase only after the gh operation succeeds; a partial gh run should restart from that phase on resume.
- **Hardcoding branch comparison for merge detection:** Use `gh pr view --json state` not `git branch --merged`; the latter does not detect GitHub squash/rebase merges reliably.
- **Calling `safe_push` from outside the worktree directory:** `safe_push` calls `git push` which uses the current directory's git context; always `cd "$wt_path"` first or use `git -C "$wt_path"`.

## Don't Hand-Roll

| Problem               | Don't Build                | Use Instead                                | Why                                                 |
| --------------------- | -------------------------- | ------------------------------------------ | --------------------------------------------------- |
| Issue metadata fetch  | curl + GitHub API          | `gh issue view --json title,labels`        | Handles auth, repo detection, JSON output           |
| PR creation           | git push + curl GitHub API | `gh pr create --title --body`              | Handles auth, base branch detection, returns PR URL |
| PR state query        | git ls-remote + guess      | `gh pr view <url> --json state`            | Returns clean `MERGED`/`OPEN`/`CLOSED` string       |
| Issue/PR comments     | curl GitHub API            | `gh issue comment`, `gh pr comment --body` | Handles auth, idiomatic                             |
| Branch type picker    | printf + read              | `gum choose`                               | Arrow key navigation, consistent with rest of UI    |
| Session ID extraction | custom protocol            | jq `.session_id` on stream-json events     | claude emits structured JSON events                 |

**Key insight:** All GitHub operations go through `gh`. No direct API calls. The `gh` binary handles authentication, repository detection, and error formatting consistently.

## Common Pitfalls

### Pitfall 1: Nested Claude Session Refusal (CLAUDECODE env var)

**What goes wrong:** When `github-issue` is invoked from within a Claude session (during development), `claude` refuses to launch with "Claude Code cannot be launched inside another Claude Code session."
**Why it happens:** Claude sets `CLAUDECODE=1` in its own environment, and the child process inherits it.
**How to avoid:** Always `unset CLAUDECODE` in the subshell before launching claude. Use `( unset CLAUDECODE; cd "$wt_path"; claude ... )` subshell pattern.
**Warning signs:** Script hangs or immediately exits at the Claude launch phase. Error message mentions "Nested sessions share runtime resources."

### Pitfall 2: `gh pr create` Prompts When --title or --body Missing

**What goes wrong:** Without `--title` and `--body`, `gh pr create` enters interactive mode and hangs in non-interactive contexts.
**Why it happens:** gh detects a TTY and opens an editor.
**How to avoid:** Always pass both `--title` and `--body` explicitly. Use `--body-file -` to pipe from stdin if body is complex.
**Warning signs:** Script hangs at the PR creation phase.

### Pitfall 3: gum choose exit codes under set -e

**What goes wrong:** `gum choose` exits 130 on Ctrl+C. Under `set -e`, this kills the script without running cleanup.
**Why it happens:** set -e treats any non-zero exit as fatal.
**How to avoid:** `choice="$(gum choose "A" "B" "C")" || die "aborted"`. The `|| die` handles non-zero without set -e propagating.
**Warning signs:** Script silently exits when user presses Ctrl+C during a gum choose prompt.

### Pitfall 4: State File Missing pr_url Field on Resume

**What goes wrong:** If script is interrupted after PR creation but before writing pr_url to state file, resume cannot find the PR for merge detection.
**Why it happens:** State update after `gh pr create` is a separate atomic write; if the process is killed between them, state is stale.
**How to avoid:** Set phase and write pr_url in the same jq pipeline before commenting on the issue. PR creation is the critical checkpoint.
**Warning signs:** Re-invocation always goes to pushing phase even though PR exists.

### Pitfall 5: Cleanup Trap Running on Intentional Cleanup

**What goes wrong:** The `cleanup()` trap registered in setup calls `git worktree remove --force` on exit. During `phase_cleanup()`, we intentionally remove the worktree, but then EXIT fires the trap again and tries to remove the already-removed worktree.
**Why it happens:** The trap is registered unconditionally on EXIT.
**How to avoid:** Before intentional cleanup, set `_WT_CLEANUP_PATH=""` to disable the trap (the `cleanup()` function checks `if [[ -n "$_WT_CLEANUP_PATH" ]]`).
**Warning signs:** Spurious "worktree not found" error message during cleanup.

### Pitfall 6: safe_push Branch Guard from Wrong Directory

**What goes wrong:** `safe_push` calls `git rev-parse --abbrev-ref HEAD`. If the current directory is the main repo (not the worktree), HEAD is main/master and the branch guard fires.
**Why it happens:** git commands use the CWD's git context by default.
**How to avoid:** Always `cd "$wt_path"` before calling `safe_push`, or use `git -C "$wt_path" push -u origin "$branch"` directly.
**Warning signs:** "refusing to operate on protected branch 'main'" error during push phase even when the worktree is on a feature branch.

### Pitfall 7: Issue with No Labels Requires gum choose

**What goes wrong:** If issue has no labels, `jq '.[].name'` returns empty. The case statement falls through to the gum fallback. If not handled, empty case match may silently proceed.
**Why it happens:** New issues often have no labels.
**How to avoid:** The case default `*` matcher should always include the gum choose fallback. Test the empty-labels path specifically.
**Warning signs:** Branch named "/42-title" (type missing) when issue has no labels.

## Code Examples

### Issue metadata fetch

```bash
# Source: gh 2.87.3, verified JSON fields
ISSUE_JSON="$(gh issue view "$ISSUE_NUMBER" --json title,labels,body)"
ISSUE_TITLE="$(printf '%s' "$ISSUE_JSON" | jq -r '.title')"
ISSUE_LABELS="$(printf '%s' "$ISSUE_JSON" | jq -c '.labels')"
ISSUE_BODY="$(printf '%s' "$ISSUE_JSON" | jq -r '.body')"
```

### PR state check for merge detection

```bash
# Source: gh 2.87.3 -- .state returns MERGED, OPEN, or CLOSED
PR_STATE="$(gh pr view "$PR_URL" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")"
if [[ "$PR_STATE" == "MERGED" ]]; then
  phase_cleanup ...
fi
```

### Remote branch deletion

```bash
# Delete local branch (force if not merged per git's check)
git -C "$(git rev-parse --show-toplevel)" branch -d "$BRANCH" 2>/dev/null \
  || git -C "$(git rev-parse --show-toplevel)" branch -D "$BRANCH" 2>/dev/null \
  || true
# Delete remote branch
git push origin --delete "$BRANCH" 2>/dev/null || true
```

### State file with pr_url field

```bash
# Add pr_url field to existing state atomically
update_state_pr_url() {
  local pr_url="$1"
  local wt_path="$2"
  local timestamp current updated
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  current="$(cat "${wt_path}/.worktree-state.json")"
  updated="$(printf '%s' "$current" | jq \
    --arg url "$pr_url" \
    --arg t "$timestamp" \
    '.pr_url = $url | .updated_at = $t')"
  write_state "$updated" "$wt_path"
}
```

### Initial state with issue-specific fields

```bash
# Extend create_state for issue type (add issue_number, issue_title, issue_body)
create_issue_state() {
  local branch="$1" wt_path="$2" issue_number="$3" issue_title="$4" issue_body="$5"
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
```

## State of the Art

| Old Approach                | Current Approach                                                         | When Changed | Impact                                               |
| --------------------------- | ------------------------------------------------------------------------ | ------------ | ---------------------------------------------------- |
| Stub with echo annotations  | Full workflow implementation                                             | Phase 2      | Actual worktree creation, Claude launch, PR, cleanup |
| No claude invocation        | `claude --dangerously-skip-permissions -p <prompt>`                      | Phase 2      | Real isolated Claude sessions                        |
| State schema without pr_url | State schema extended with pr_url, issue_number, issue_title, issue_body | Phase 2      | Enables merge detection and resume from any phase    |

**Deprecated/outdated:**

- The Phase 1 stub's echo-only annotations: replaced entirely by real implementation.

## Open Questions

1. **stream-json session_id field name**
   - What we know: claude --output-format stream-json emits newline-delimited JSON events; existing JSONL session files use `session_id` field; the `--resume` flag accepts a session UUID
   - What's unclear: Whether the stream-json output uses `session_id` or `sessionId` in the event envelope (camelCase vs snake_case)
   - Recommendation: Implement defensively -- try both `jq -r '.session_id // .sessionId // empty'`. The session_id extraction is in Claude's Discretion; fall back to empty string gracefully.

2. **claude binary in interactive vs -p mode**
   - What we know: The CONTEXT.md locks `claude -p` with `--output-format stream-json`; the claude binary is at `pkgs.llm-agents.claude-code`
   - What's unclear: Whether `claude -p` with a complex multi-line prompt needs quoting protection for special characters
   - Recommendation: Pass issue body through the state file (stored as JSON string by jq), retrieve with `read_state_field`, pass to claude via a temp file or heredoc to avoid shell quoting issues.

3. **Label-to-type mapping completeness**
   - What we know: CONTEXT.md marks this as Claude's Discretion; 9 supported types (feat/fix/docs/refactor/test/ci/chore/revert/deps)
   - What's unclear: How to handle repos that use custom label taxonomies (e.g., "type: bug" instead of "bug")
   - Recommendation: Match on `.name` containing known type keywords (case-insensitive substring match), not exact match. Fall back to gum choose on no match.

## Validation Architecture

### Test Framework

| Property           | Value                                                                  |
| ------------------ | ---------------------------------------------------------------------- |
| Framework          | None -- Nix module; validation is rebuild success + manual smoke tests |
| Config file        | N/A                                                                    |
| Quick run command  | `just quiet-rebuild`                                                   |
| Full suite command | `just quiet-rebuild` + manual invocation of `github-issue --help`      |

### Phase Requirements to Test Map

| Req ID | Behavior                                                       | Test Type | Automated Command                                      | File Exists? |
| ------ | -------------------------------------------------------------- | --------- | ------------------------------------------------------ | ------------ |
| WT-01  | `github-issue 42` creates worktree with correct branch name    | smoke     | Manual: run on a real repo, verify `git worktree list` | Wave 0       |
| WT-02  | Orphan worktrees detected on startup                           | smoke     | Manual: create orphan, re-run, verify prompt           | Wave 0       |
| WT-05  | Cleanup removes worktree, prunes, deletes branches             | smoke     | Manual: post-merge re-invocation                       | Wave 0       |
| WT-06  | Re-invocation resumes from last phase                          | smoke     | Manual: kill during claude_running, re-invoke          | Wave 0       |
| WT-07  | Existing worktree offers Resume/Remove/Abort                   | smoke     | Manual: invoke twice, verify gum choose appears        | Wave 0       |
| RF-01  | Branch pushed and PR created                                   | smoke     | `gh pr list` after script run                          | Wave 0       |
| RF-02  | Issue comment with PR link                                     | smoke     | `gh issue view <number> --comments`                    | Wave 0       |
| PM-01  | Merged PR detected on re-invocation                            | smoke     | Manual: merge PR, re-invoke                            | Wave 0       |
| PM-02  | Default branch switched, pulled, local+remote branches deleted | smoke     | `git branch -a` after cleanup                          | Wave 0       |
| PM-03  | Worktree removed and pruned                                    | smoke     | `git worktree list` after cleanup                      | Wave 0       |
| PM-04  | Resolution comment on issue and PR                             | smoke     | `gh issue view` and `gh pr view --comments`            | Wave 0       |

### Sampling Rate

- **Per task commit:** `just quiet-rebuild` (verifies Nix syntax and shellcheck)
- **Per wave merge:** `just quiet-rebuild` + `github-issue --help` exits 0
- **Phase gate:** Full smoke test against a real test repo

### Wave 0 Gaps

- [ ] `modules/apps/cli/worktree-flow/scripts/github-issue.sh` -- replace stub with full implementation
- [ ] `modules/apps/cli/worktree-flow/default.nix` -- add `pkgs.llm-agents.claude-code` to runtimeInputs

_(No new test framework needed -- rebuild is the automated gate)_

## Sources

### Primary (HIGH confidence)

- `/home/dustin/git/nixerator/modules/apps/cli/worktree-flow/scripts/lib.sh` -- verified state file schema, existing helpers
- `/home/dustin/git/nixerator/modules/apps/cli/worktree-flow/scripts/github-issue.sh` -- current stub to be replaced
- `/home/dustin/git/nixerator/modules/apps/cli/worktree-flow/default.nix` -- existing runtimeInputs, confirmed `pkgs.llm-agents.claude-code` as attribute path
- `/home/dustin/git/nixerator/modules/apps/cli/claude-code/default.nix` -- confirmed `pkgs.llm-agents.claude-code` package reference
- `gh --version` output: 2.87.3 -- confirmed available flags: `--json`, `--jq`, `--body`, `--title`, `--head`
- `gh help issue view` -- confirmed JSON fields: labels, title, body
- `gh help pr view` -- confirmed JSON fields: state (MERGED/OPEN/CLOSED), url
- `gh help pr create` -- confirmed: --title, --body, --head, no --draft needed (ready for review default)
- `gh help issue comment` -- confirmed: --body flag
- `gh help pr comment` -- confirmed: --body flag
- `claude --help` output: 2.1.72 -- confirmed: `-p`, `--dangerously-skip-permissions`, `--output-format stream-json`, `--resume`
- `git worktree list --porcelain` -- confirmed output format for orphan detection

### Secondary (MEDIUM confidence)

- Empirical: `CLAUDECODE=1` env var refusal message observed during research -- "Claude Code cannot be launched inside another Claude Code session"
- `~/.claude/projects/*/...jsonl` -- `session_id` field confirmed in event objects (snake_case)

### Tertiary (LOW confidence)

- stream-json event envelope field name for session_id (snake_case vs camelCase) -- not directly testable in nested session context; implement defensively

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH -- all tools verified against installed versions
- Architecture: HIGH -- patterns derived directly from lib.sh primitives already built in Phase 1
- gh CLI flags: HIGH -- verified against installed gh 2.87.3
- Claude invocation: HIGH -- flags verified from `claude --help`; CLAUDECODE pitfall observed empirically
- stream-json session_id field name: LOW -- not directly testable; implement defensively

**Research date:** 2026-03-11
**Valid until:** 2026-04-10 (stable tools; claude-code version may update)
