---
phase: 01-foundation
plan: 02
subsystem: cli-tools
tags: [worktree-flow, nix, home-manager, claude-code, shell-scripts, gum]

# Dependency graph
requires:
  - phase: 01-foundation plan 01
    provides: "worktree-flow module scaffold with lib.sh, stub commands, and module structure"
provides:
  - "SKILL.md deployed to ~/.claude/skills/github-issue/SKILL.md via home.file"
  - "Simplified SKILL.md with only commit conventions and PR body format (CL-04)"
  - "Old verbose SKILL.md removed from claude-code module"
  - "Stub commands demonstrating Claude integration lifecycle contract (CL-01 through CL-05)"
  - "section() bug fixed so gum style handles text with leading dashes"
affects: [phase-02-github-issue, phase-03-hack]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "home.file SKILL.md deployment: worktree-flow module owns its own skill files"
    - "gum style text escaping: use -- separator before text to prevent flag parsing"
    - "Shell lifecycle contract: shell announces all phases, Claude operates inside claude_running phase only"

key-files:
  created:
    - modules/apps/cli/worktree-flow/skills/github-issue/SKILL.md
  modified:
    - modules/apps/cli/worktree-flow/default.nix
    - modules/apps/cli/worktree-flow/scripts/github-issue.sh
    - modules/apps/cli/worktree-flow/scripts/hack.sh
    - modules/apps/cli/worktree-flow/scripts/lib.sh
    - modules/apps/cli/claude-code/default.nix

key-decisions:
  - "SKILL.md owned by worktree-flow module, not claude-code: deployed via home.file builtins.readFile"
  - "SKILL.md scope limited to commit conventions and PR body format; shell owns lifecycle per CL-01"
  - "Old github-issue skill removed from claude-code to avoid confusion about authoritative skill location"

patterns-established:
  - "Skill deployment pattern: module that uses the skill deploys it via home.file"
  - "Lifecycle announcement pattern: stub commands announce all phases so shell ownership is explicit"

requirements-completed: [CL-01, CL-02, CL-03, CL-04, CL-05]

# Metrics
duration: 10min
completed: 2026-03-11
---

# Phase 1 Plan 2: Foundation Summary

**SKILL.md deployed via home.file to ~/.claude/skills/github-issue/ with lifecycle contract stubs demonstrating shell-owned phase ownership for CL-01 through CL-05**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-11T14:50:23Z
- **Completed:** 2026-03-11T15:00:23Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Created simplified SKILL.md with only commit conventions and PR body format (removed verbose lifecycle instructions that shell now owns)
- Deployed SKILL.md via worktree-flow home.file to ~/.claude/skills/github-issue/SKILL.md
- Removed old github-issue skill from claude-code module (SKILL.md now owned by worktree-flow)
- Updated github-issue.sh and hack.sh stubs to announce all 5 lifecycle phases with CL-\* annotations
- Fixed pre-existing bug in section() where gum style parsed leading dashes in text as flags

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SKILL.md and update Nix module for home.file deployment** - `5035e80` (feat)
2. **Task 2: Update stub commands with Claude integration contract demonstration** - `3a94d86` (feat)

## Files Created/Modified

- `modules/apps/cli/worktree-flow/skills/github-issue/SKILL.md` - New simplified skill with commit conventions and PR body format only
- `modules/apps/cli/worktree-flow/default.nix` - Added home.file deployment block for SKILL.md
- `modules/apps/cli/worktree-flow/scripts/github-issue.sh` - Updated stub with lifecycle phase announcements
- `modules/apps/cli/worktree-flow/scripts/hack.sh` - Updated stub with lifecycle phase announcements
- `modules/apps/cli/worktree-flow/scripts/lib.sh` - Fixed section() gum style flag parsing bug
- `modules/apps/cli/claude-code/default.nix` - Removed github-issue from skills list

## Decisions Made

- worktree-flow module owns and deploys its own SKILL.md; claude-code module is not responsible for skills of other tools
- SKILL.md contains only commit conventions and PR body format; shell lifecycle is documented in scripts, not in Claude skill files

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed gum style section() failing on text with leading dashes**

- **Found during:** Task 2 (stub command testing)
- **Issue:** `section "Pre-flight checks"` showed gum help page because `gum style --bold --foreground 6 "-- Pre-flight checks --"` treated the leading `--` in the text as an end-of-flags marker
- **Fix:** Changed call to `gum style --bold --foreground="6" -- "-- $* --"` using explicit `--` separator to delimit flags from text
- **Files modified:** modules/apps/cli/worktree-flow/scripts/lib.sh
- **Verification:** `github-issue 42` and `hack "test"` both show section headers correctly and exit 0
- **Committed in:** `3a94d86` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Required for stubs to be testable; no scope creep.

## Issues Encountered

None beyond the auto-fixed section() bug.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Foundation complete: SKILL.md deployed, lib.sh primitives working, state file schema includes session_id field
- github-issue stub demonstrates full CL-01 through CL-05 contract, ready for Phase 2 full implementation
- hack stub demonstrates same lifecycle pattern, ready for Phase 3 full implementation
- Remaining blocker from STATE.md still open: verify `claude` binary is findable at runtime inside writeShellApplication PATH isolation

---

_Phase: 01-foundation_
_Completed: 2026-03-11_
