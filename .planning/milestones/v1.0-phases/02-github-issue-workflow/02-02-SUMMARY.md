---
phase: 02-github-issue-workflow
plan: 02
subsystem: cli
tags: [bash, shell, github, gh-cli, worktree, resume, cleanup]

# Dependency graph
requires:
  - phase: 02-github-issue-workflow
    plan: 01
    provides: Phase-dispatch happy-path workflow (phase_setup, phase_claude_running, phase_claude_exited, phase_push_and_pr, state file schema)
  - phase: 01-foundation
    provides: lib.sh primitives (read_state_field, set_phase, register_cleanup, default_branch, worktree_base, safe_push, write_state)
provides:
  - Full re-invocation handling: resume from any phase, restart with cleanup, abort
  - Post-merge cleanup: switch to default branch, remove worktree+prune+branch-delete, post resolution comments
  - Orphan worktree detection and cleanup on every startup
  - Complete github-issue command lifecycle (happy path + all re-invocation paths)
affects: [03-hack-workflow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Numeric start-index pattern for phase resume (avoids bash ;;&  fall-through pitfalls)
    - Disable _WT_CLEANUP_PATH before any intentional worktree removal to prevent double-remove
    - gum confirm pattern for interactive orphan cleanup (SF-04: handles No and Ctrl+C safely)
    - WT-05 cleanup sequence: worktree remove, then prune, then branch delete

key-files:
  created: []
  modified:
    - modules/apps/cli/worktree-flow/scripts/github-issue.sh

key-decisions:
  - "phase_resume uses numeric start index (start=1/2/3) rather than bash ;;&  fall-through for reliable sequential phase execution"
  - "phase_cleanup disables trap via _WT_CLEANUP_PATH= before intentional removal to avoid double-remove on EXIT"
  - "Resolution comment uses short one-liner format (Resolved via #N. Branch and worktree cleaned up.) matching CONTEXT.md decision"

patterns-established:
  - 'Always set _WT_CLEANUP_PATH="" before any intentional git worktree remove to prevent EXIT trap double-remove'
  - "Cleanup order: worktree remove -> prune -> branch delete (WT-05 sequence)"
  - "Use if gum confirm pattern (not gum confirm && ...) for SF-04 compliance under set -e"

requirements-completed: [WT-02, WT-05, WT-06, WT-07, PM-01, PM-02, PM-03, PM-04]

# Metrics
duration: 4min
completed: 2026-03-12
---

# Phase 2 Plan 02: github-issue Resume and Cleanup Summary

**Re-invocation handling with phase-indexed resume, merged-PR detection triggering post-merge cleanup, and orphan worktree scanning on every startup**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-12T04:08:20Z
- **Completed:** 2026-03-12T04:12:45Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `handle_existing_worktree`: detects merged PR state via `gh pr view --json state`, dispatches to cleanup or shows gum choose Resume/Remove & restart/Abort
- Added `phase_resume`: numeric start-index dispatch runs only remaining phases without re-running completed ones
- Added `remove_worktree`: safely removes worktree+prunes+deletes branch for restart path
- Added `check_orphan_worktrees`: scans worktree_base on every startup, offers `gum confirm` to remove dirs without state files
- Added `phase_cleanup`: full PM-01 through PM-04 post-merge cleanup following WT-05 sequence, posts resolution comments on both issue and PR

## Task Commits

Each task was committed atomically:

1. **Task 1: Add resume and re-invocation handling** - `5d15fc8` (feat)
2. **Task 2: Add orphan detection and post-merge cleanup** - `349c623` (feat)

## Files Created/Modified

- `modules/apps/cli/worktree-flow/scripts/github-issue.sh` - Added 5 new functions (149 lines); updated main() to call handle_existing_worktree and check_orphan_worktrees

## Decisions Made

- `phase_resume` uses a numeric start-index (`start=1/2/3`) rather than bash `;;&` fall-through. The plan spec flagged this: `;;&` tests subsequent patterns rather than falling through, so explicit sequential if-guards are safer and clearer.
- `_WT_CLEANUP_PATH=""` is set before every intentional worktree removal. The EXIT trap watches this variable; clearing it before `git worktree remove` prevents the trap from firing a second time after the directory is gone.
- Resolution comments use a short one-liner ("Resolved via #N. Branch and worktree cleaned up.") matching the format decision in CONTEXT.md rather than a verbose message.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 2 complete: `github-issue <number>` now handles the full lifecycle (fresh start, resume from any interrupted phase, post-merge cleanup, orphan detection)
- Phase 3 (hack workflow) can proceed; it shares lib.sh primitives and the worktree-flow module
- The `_WT_CLEANUP_PATH=""` pattern is now established; hack.sh should follow the same convention for intentional cleanup

---

_Phase: 02-github-issue-workflow_
_Completed: 2026-03-12_
