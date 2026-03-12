# Requirements: Worktree Flow

**Defined:** 2026-03-11
**Core Value:** Every Claude Code session gets full git isolation so parallel work never collides, and deterministic shell logic handles the worktree lifecycle so the AI never drifts.

## v1 Requirements

### Worktree Lifecycle

- [x] **WT-01**: Script creates worktree with proper branch naming (`fix/<slug>`, `feat/<slug>`, `hack/<slug>` based on context)
- [x] **WT-02**: Script detects and offers to clean orphaned worktrees on startup
- [x] **WT-03**: Script registers trap cleanup handler immediately after `git worktree add`
- [x] **WT-04**: State file writes are atomic (write to tmpfile, then `mv`)
- [x] **WT-05**: Cleanup sequences as worktree remove, then prune, then branch delete
- [x] **WT-06**: Re-invocation with same issue number or description resumes from state file
- [x] **WT-07**: Script errors if worktree already exists for same issue/description (with option to resume)

### Claude Integration

- [x] **CL-01**: Shell script owns all lifecycle (worktree create, state write, push, PR, cleanup); Claude owns only implementation
- [x] **CL-02**: State file written before Claude launch, updated by querying git/gh after Claude exits
- [x] **CL-03**: All git fetch/setup operations complete before launching Claude
- [x] **CL-04**: Simplified SKILL.md contains only commit conventions and PR body format, no lifecycle instructions
- [x] **CL-05**: Claude session ID tracked in state file for `--resume` on re-invocation

### Review Flows

- [x] **RF-01**: github-issue flow pushes branch and creates PR via `gh pr create` with Summary/Test plan body format
- [x] **RF-02**: github-issue flow comments on issue linking the PR
- [x] **RF-03**: hack flow presents diff via gum pager for review
- [x] **RF-04**: hack flow prompts approve/reject via gum confirm
- [x] **RF-05**: hack flow merges to default branch locally on approval (fast-forward only)

### Safety

- [x] **SF-01**: Always uses `git push -u origin <branch>` on first push
- [x] **SF-02**: Never pushes to main/master directly; validates current branch before push
- [x] **SF-03**: Guards against dirty working tree before worktree creation
- [x] **SF-04**: All gum prompts handle exit code 1 (No) and 130 (Ctrl+C) without silent death under `set -e`
- [x] **SF-05**: git-crypt auto-unlock in new worktrees with key verification via `git crypt status`

### Nix Packaging

- [x] **NX-01**: New module at `modules/apps/cli/worktree-flow/` with `apps.cli.worktree-flow.enable` option
- [x] **NX-02**: Both commands packaged via `pkgs.writeShellApplication` with explicit `runtimeInputs`
- [x] **NX-03**: Shared functions in `lib.sh` concatenated at build time via Nix string interpolation
- [x] **NX-04**: Scripts stored in `modules/apps/cli/worktree-flow/scripts/`

### Post-merge Cleanup

- [x] **PM-01**: github-issue detects merged PR on re-invocation and enters cleanup phase
- [x] **PM-02**: Cleanup switches to default branch, pulls, deletes local and remote branches
- [x] **PM-03**: Cleanup removes worktree directory and prunes
- [x] **PM-04**: Cleanup comments on issue and PR with resolution summary

## v2 Requirements

### Enhanced Review

- **RV-01**: hack flow supports per-file diff stepping (approve/reject individual files)
- **RV-02**: difftastic integration for richer diff display

### Multi-repo

- **MR-01**: Support worktree flows across multiple repos for related changes

## Out of Scope

| Feature | Reason |
|---------|--------|
| Manual (no-AI) worktree mode | hack always launches Claude; use gcom for manual worktrees |
| Claude Code EnterWorktree/ExitWorktree | Manual git worktree add gives full control over naming and state |
| Auto-merge for github-issue | User always merges PRs on GitHub |
| GitHub review for hack flow | hack reviews and merges locally in terminal |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WT-01 | Phase 2 | Complete |
| WT-02 | Phase 2 | Complete |
| WT-03 | Phase 1 | Complete |
| WT-04 | Phase 1 | Complete |
| WT-05 | Phase 2 | Complete |
| WT-06 | Phase 2 | Complete |
| WT-07 | Phase 2 | Complete |
| CL-01 | Phase 1 | Complete |
| CL-02 | Phase 1 | Complete |
| CL-03 | Phase 1 | Complete |
| CL-04 | Phase 1 | Complete |
| CL-05 | Phase 1 | Complete |
| RF-01 | Phase 2 | Complete |
| RF-02 | Phase 2 | Complete |
| RF-03 | Phase 3 | Complete |
| RF-04 | Phase 3 | Complete |
| RF-05 | Phase 3 | Complete |
| SF-01 | Phase 1 | Complete |
| SF-02 | Phase 1 | Complete |
| SF-03 | Phase 1 | Complete |
| SF-04 | Phase 1 | Complete |
| SF-05 | Phase 1 | Complete |
| NX-01 | Phase 1 | Complete |
| NX-02 | Phase 1 | Complete |
| NX-03 | Phase 1 | Complete |
| NX-04 | Phase 1 | Complete |
| PM-01 | Phase 2 | Complete |
| PM-02 | Phase 2 | Complete |
| PM-03 | Phase 2 | Complete |
| PM-04 | Phase 2 | Complete |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30
- Unmapped: 0

---
*Requirements defined: 2026-03-11*
*Last updated: 2026-03-11 after roadmap creation*
