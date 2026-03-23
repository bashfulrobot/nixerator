---
phase: 03-hack-workflow
plan: 01
subsystem: cli
tags: [bash, git-worktree, claude-code, gum, shellcheck, nix]

# Dependency graph
requires:
  - phase: 02-github-issue-workflow
    provides: github-issue.sh patterns (phase functions, resume, handle_existing_worktree, remove_worktree, Claude launch subshell)
provides:
  - Full hack command: worktree creation, Claude launch, diff review via gum pager, ff-merge on approve, worktree preservation on reject
  - Resume support: existing worktree detected by slug, Resume/Remove/Abort menu, diff_review resume re-shows diff
  - llm-agents.claude-code in hack-cmd runtimeInputs
affects: [03-hack-workflow]

# Tech tracking
tech-stack:
  added: [llm-agents.claude-code added to hack-cmd runtimeInputs]
  patterns:
    - Numeric start index for phase_resume (same pattern as github-issue)
    - Always _WT_CLEANUP_PATH="" before intentional worktree removal
    - gum confirm wrapped in if statement (SF-04)
    - Three-dot diff (default_br...branch) for diff review
    - git merge --ff-only run from repo root via rev-parse --show-toplevel

key-files:
  created: []
  modified:
    - modules/apps/cli/worktree-flow/scripts/hack.sh
    - modules/apps/cli/worktree-flow/default.nix

key-decisions:
  - "Reused github-issue SKILL.md for hack workflow per locked decision (same skill, different prompt structure)"
  - "phase_resume uses numeric start index; diff_review start=2 so resume always re-shows diff"
  - 'Reject path sets _WT_CLEANUP_PATH="" then exits 0 to preserve worktree'
  - "phase_merge runs git merge --ff-only from repo root to avoid working in deleted worktree"

patterns-established:
  - 'Reject/abandon path: _WT_CLEANUP_PATH="" then exit 0 (preserve worktree)'
  - "All phase functions accept wt_path as first arg for stateless resumability"

requirements-completed: [RF-03, RF-04, RF-05]

# Metrics
duration: 12min
completed: 2026-03-11
---

# Phase 3 Plan 01: Hack Workflow Summary

**Complete hack command with gum pager diff review, gum confirm approve/reject, ff-merge on approve, worktree preservation on reject, and full resume support via numeric phase_resume**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-03-11T00:00:00Z
- **Completed:** 2026-03-11
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced hack.sh stub with 235-line complete workflow implementing all six phases (setup, claude_running, claude_exited, diff_review, merge, cleanup_done)
- Approve path: fast-forward merge to default branch with silent worktree and branch deletion
- Reject path: worktree preserved, copy-pasteable `hack "<description>"` resume command printed, clean exit 0
- Resume detection: existing worktree found by slug match, Resume/Remove/Abort menu, diff_review start index re-shows diff before re-prompting
- Added llm-agents.claude-code to hack-cmd runtimeInputs so claude binary is available in PATH isolation

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement full hack.sh workflow** - `2a28ac1` (feat)
2. **Task 2: Add claude-code to hack-cmd runtimeInputs** - `ebff470` (feat)

**Plan metadata:** (docs commit - see final_commit step)

## Files Created/Modified

- `modules/apps/cli/worktree-flow/scripts/hack.sh` - Full workflow replacing stub: 12 functions, 6 phases, complete resume support
- `modules/apps/cli/worktree-flow/default.nix` - Added llm-agents.claude-code to hack-cmd runtimeInputs

## Decisions Made

- Used the same github-issue SKILL.md for hack workflow (per prior locked decision); prompt format adapted to "Task: {description}" instead of issue body
- phase_resume numeric start index: diff_review maps to start=2 so resume always re-shows diff before approve/reject
- Reject path clears \_WT_CLEANUP_PATH before exit to preserve worktree for future resume
- phase_merge runs from repo root (git rev-parse --show-toplevel) per anti-pattern guidance

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - shellcheck passed on first build, rebuild succeeded without errors.

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

All files confirmed present on disk. All commits confirmed in git history.

## Next Phase Readiness

- hack command is complete and ships as v1 milestone alongside github-issue
- Phase 3 Plan 01 is the final execution plan; phase 03 is complete
- Worktree-flow module v1 milestone achieved: both commands operational with full resume support
