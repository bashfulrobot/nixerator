---
phase: 01-foundation
plan: "01"
subsystem: infra
tags: [nix, bash, shell, worktree, git, git-crypt, gum, jq]

# Dependency graph
requires: []
provides:
  - "worktree-flow Nix module at modules/apps/cli/worktree-flow/"
  - "lib.sh with all shared primitives (colors, safety guards, state I/O, trap cleanup, git-crypt, slug generation)"
  - "github-issue stub command in PATH"
  - "hack stub command in PATH"
affects: [01-02, 01-03, phase-2, phase-3]

# Tech tracking
tech-stack:
  added: [git-crypt, gum, gh, jq, gnused, findutils]
  patterns:
    - "writeShellApplication with builtins.readFile inlining lib.sh into each command"
    - "Atomic state writes via mktemp + mv (WT-04)"
    - "Trap cleanup via _WT_CLEANUP_PATH global + register_cleanup()"
    - "gum confirm always wrapped in if statement (SF-04)"
    - "git-crypt auto-unlock with first-key-wins, no interactive picker (SF-05)"

key-files:
  created:
    - modules/apps/cli/worktree-flow/default.nix
    - modules/apps/cli/worktree-flow/scripts/lib.sh
    - modules/apps/cli/worktree-flow/scripts/github-issue.sh
    - modules/apps/cli/worktree-flow/scripts/hack.sh
  modified:
    - modules/suites/dev/default.nix

key-decisions:
  - "Enabled worktree-flow in suites/dev so it deploys to all workstations via the workstation archetype"
  - "lib.sh inlined via builtins.readFile string interpolation, not a separate derivation"
  - "gnused included in runtimeInputs for forward-compatibility even though current slugify uses POSIX-safe sed"
  - "globals arg included in module function args for Phase 2 home.file SKILL.md deployment"

patterns-established:
  - "lib.sh pattern: shared functions inlined into each writeShellApplication at Nix build time"
  - "Safety pattern: assert_not_main/assert_clean_tree always called before destructive git operations"
  - "State pattern: atomic JSON state file in worktree root, read/write via jq"

requirements-completed:
  [NX-01, NX-02, NX-03, NX-04, SF-01, SF-02, SF-03, SF-04, SF-05, WT-03, WT-04]

# Metrics
duration: 15min
completed: 2026-03-11
---

# Phase 1 Plan 01: Foundation Scaffold Summary

**worktree-flow Nix module with lib.sh containing all shared primitives (safety guards, atomic state I/O, git-crypt auto-unlock, trap cleanup) and stub github-issue/hack commands in PATH after rebuild**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-11T14:34:00Z
- **Completed:** 2026-03-11T14:49:00Z
- **Tasks:** 2
- **Files modified:** 5 (4 created, 1 modified)

## Accomplishments

- lib.sh with 9 function groups ready for Phases 2 and 3 to build on
- Both `github-issue` and `hack` live at `/run/current-system/sw/bin/` and respond to --help
- All safety patterns implemented and shellcheck-clean via writeShellApplication's built-in checker
- Atomic state file I/O and trap cleanup handler established as the foundation for phase tracking

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib.sh with all shared primitives** - `18ab84e` (feat)
2. **Task 2: Create Nix module and stub commands** - `ada8dfe` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `modules/apps/cli/worktree-flow/scripts/lib.sh` - All shared primitives: colors, section headers, safety guards, git-crypt unlock, default branch detection, atomic state I/O, trap cleanup handler, slug generation, worktree path helper
- `modules/apps/cli/worktree-flow/default.nix` - Module with enable option, inlines lib.sh into both writeShellApplication derivations, runtimeInputs: git/git-crypt/gum/gh/jq/coreutils/gnused/findutils
- `modules/apps/cli/worktree-flow/scripts/github-issue.sh` - Stub that validates lib.sh loads correctly, supports --help
- `modules/apps/cli/worktree-flow/scripts/hack.sh` - Stub that validates lib.sh loads correctly, supports --help
- `modules/suites/dev/default.nix` - Added `worktree-flow.enable = true` so all workstations get the module

## Decisions Made

- Enabled in `suites/dev` (not per-host): worktree-flow is a universal developer workflow tool, same blast radius as `git.enable = true`
- `globals` arg kept in module function args even though Plan 01 doesn't use it; needed in Plan 02 for `home.file` SKILL.md deployment
- gnused in runtimeInputs: kept for forward-compatibility (Phase 2 may need GNU sed extensions); current slugify is POSIX-safe

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 9 function groups from lib.sh are available in both commands
- Static checks pass: mktemp atomic write, assert_not_main branch guard, crypt status verification, no bare gum confirm
- Plan 02 can add full github-issue workflow logic on top of this scaffold
- Plan 03 can add full hack workflow logic

---

_Phase: 01-foundation_
_Completed: 2026-03-11_

## Self-Check: PASSED

- modules/apps/cli/worktree-flow/default.nix: FOUND
- modules/apps/cli/worktree-flow/scripts/lib.sh: FOUND
- modules/apps/cli/worktree-flow/scripts/github-issue.sh: FOUND
- modules/apps/cli/worktree-flow/scripts/hack.sh: FOUND
- .planning/phases/01-foundation/01-01-SUMMARY.md: FOUND
- Commit 18ab84e (lib.sh): FOUND
- Commit ada8dfe (module + stubs): FOUND
