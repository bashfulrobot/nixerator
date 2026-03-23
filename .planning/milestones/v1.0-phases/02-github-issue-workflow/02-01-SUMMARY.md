---
phase: 02-github-issue-workflow
plan: 01
subsystem: cli
tags: [bash, shell, github, gh-cli, worktree, claude-code, nix]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: lib.sh primitives (write_state, set_phase, read_state_field, slugify, worktree_base, register_cleanup, unlock_git_crypt, safe_push)
provides:
  - Full github-issue command replacing stub with complete phase-dispatch workflow
  - Issue metadata fetch, label-based branch type derivation, worktree creation, Claude launch, push, PR creation, issue comment
affects: [02-02-github-issue-resume, 03-hack-workflow]

# Tech tracking
tech-stack:
  added: [llm-agents.claude-code added to github-issue-cmd runtimeInputs]
  patterns:
    - Phase-dispatch linear workflow (setup -> claude_running -> claude_exited -> push_and_pr)
    - Label-to-branchtype case mapping with gum choose fallback
    - unset CLAUDECODE in subshell before claude invocation to prevent nested session refusal
    - session_id capture via stream-json piped through jq | head -1 to temp file
    - Atomic state updates via write_state after each phase transition

key-files:
  created: []
  modified:
    - modules/apps/cli/worktree-flow/default.nix
    - modules/apps/cli/worktree-flow/scripts/github-issue.sh

key-decisions:
  - "Combine push+PR into phase_push_and_pr to avoid partial-state window between push and PR creation"
  - "Existing worktree placeholder: die with message, full resume deferred to Plan 02"
  - "Disable cleanup trap at end of successful run by clearing _WT_CLEANUP_PATH"

patterns-established:
  - "Always unset CLAUDECODE before claude invocation in subshells"
  - "Capture session_id via stream-json to temp file, write to state if non-empty"
  - "Label matching: lowercase label with ${label,,}, case on substrings, first match wins"

requirements-completed: [WT-01, RF-01, RF-02]

# Metrics
duration: 1min
completed: 2026-03-12
---

# Phase 2 Plan 01: github-issue Happy-Path Workflow Summary

**Phase-dispatch github-issue command: fetch issue metadata, create worktree with label-derived branch name, launch Claude with CLAUDECODE unset, push branch, create PR via gh CLI, comment on issue**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-12T04:04:27Z
- **Completed:** 2026-03-12T04:06:14Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `llm-agents.claude-code` to `github-issue-cmd` runtimeInputs so the `claude` binary is available in writeShellApplication's PATH isolation
- Replaced the github-issue.sh stub with a complete 300-line phase-dispatch workflow covering all five phases: setup, claude_running, claude_exited, push_and_pr
- Branch naming uses label-to-type mapping (bug->fix, enhancement->feat, docs, refactor, test, ci, chore, revert, deps) with `gum choose` fallback for unlabeled issues
- Claude launch uses `unset CLAUDECODE` in a subshell to prevent nested session refusal, captures session_id from stream-json output for state persistence
- PR body uses structured format with Summary and Test plan sections per skill conventions
- Issue comment posts PR URL back to the GitHub issue after successful PR creation

## Task Commits

Each task was committed atomically:

1. **Task 1: Add claude-code to runtimeInputs** - `4351bbf` (feat)
2. **Task 2: Implement full github-issue happy-path workflow** - `2bdd53b` (feat)

## Files Created/Modified

- `modules/apps/cli/worktree-flow/default.nix` - Added `llm-agents.claude-code` to github-issue-cmd runtimeInputs
- `modules/apps/cli/worktree-flow/scripts/github-issue.sh` - Full phase-dispatch implementation replacing stub

## Decisions Made

- Combined push and PR creation into a single `phase_push_and_pr` function to eliminate a partial-state window where branch is pushed but PR doesn't exist yet. On re-invocation, the phase would retry PR creation cleanly.
- Existing worktree case uses `die` as a placeholder. Plan 02 replaces this with full resume/cleanup logic.
- Cleanup trap disabled at end of successful run by clearing `_WT_CLEANUP_PATH=""` so the EXIT trap does not remove the successfully created worktree.

## Deviations from Plan

None - plan executed exactly as written. The files already contained the full implementation as uncommitted working tree changes; both were verified with `just quiet-rebuild` before committing.

## Issues Encountered

None - implementation was already present in working tree; rebuild verified shellcheck passes and Nix compilation succeeds.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02-01 complete; `github-issue <number>` now has the full happy-path workflow
- Plan 02-02 (resume/re-invocation, orphan detection, post-merge cleanup) can proceed
- The `phase_claude_running` function already handles session_id persistence, which Plan 02 will leverage for resume
- The `die` placeholder for existing-worktree detection is the explicit entry point Plan 02 will replace

---

_Phase: 02-github-issue-workflow_
_Completed: 2026-03-12_
