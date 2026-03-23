# Project Retrospective

_A living document updated after each milestone. Lessons feed forward into future planning._

## Milestone: v1.0 -- Worktree Flow

**Shipped:** 2026-03-12
**Phases:** 3 | **Plans:** 5

### What Was Built

- NixOS module with two CLI commands (`github-issue`, `hack`) wrapping Claude Code in isolated git worktrees
- lib.sh shared primitives: state I/O, trap cleanup, git-crypt unlock, slug generation, safety guards
- Full github-issue lifecycle: worktree creation, Claude launch, push, PR creation, resume, post-merge cleanup
- Full hack lifecycle: worktree creation, Claude launch, gum diff review, local ff-merge, worktree preservation on reject
- SKILL.md deployment via home.file with simplified Claude integration contract

### What Worked

- Phase-dispatch pattern (numeric start index) made resume handling clean and reliable
- writeShellApplication + builtins.readFile for lib.sh inlining gave each command a self-contained derivation
- Separating shell lifecycle ownership from Claude implementation ownership (CL-01) prevented context drift
- Building on existing patterns from gcmt and gcom modules accelerated development

### What Was Inefficient

- Some functions (check_orphan_worktrees, remove_worktree) got duplicated across both scripts instead of being added to lib.sh
- create_state in lib.sh became dead code when both scripts needed richer variants
- hack.sh reuses github-issue SKILL.md which contains irrelevant PR body section

### Patterns Established

- Phase-dispatch with numeric start index for resume (avoids bash ;;& pitfalls)
- Always clear \_WT_CLEANUP_PATH before intentional worktree removal to prevent EXIT trap double-remove
- Combined push+PR into single phase to avoid partial-state windows
- gum confirm always in `if` statement (never bare under set -e)

### Key Lessons

1. Shell lifecycle ownership keeps Claude focused; state files written by shell before/after Claude runs prevent drift
2. lib.sh sharing intent (NX-03) needs enforcement during execution, not just planning; duplicated functions appeared despite the requirement
3. One day from roadmap to shipped MVP is achievable for well-scoped 3-phase milestones

### Cost Observations

- Model mix: primarily opus for execution, sonnet for research/planning
- Sessions: ~5 (one per plan + planning sessions)
- Notable: entire milestone completed in single calendar day

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change                                                      |
| --------- | ------ | ----- | --------------------------------------------------------------- |
| v1.0      | 3      | 5     | First milestone; established phase-dispatch and lib.sh patterns |

### Top Lessons (Verified Across Milestones)

1. Shell owns lifecycle, AI owns implementation -- prevents context drift in Claude Code workflows
2. lib.sh sharing requires active enforcement during execution, not just at planning time
