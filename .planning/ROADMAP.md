# Roadmap: Worktree Flow

## Overview

Build two CLI commands (`github-issue` and `hack`) packaged as a NixOS module that wrap Claude Code in isolated git worktrees. Phase 1 establishes the shared foundation: the Nix module, lib.sh with all safety and lifecycle primitives, and the Claude integration contract. Phase 2 delivers the full github-issue workflow end-to-end including post-merge cleanup. Phase 3 delivers the hack workflow and validates both commands work correctly together, including edge case handling for interrupted sessions and orphaned worktrees.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Nix module scaffold, lib.sh shared functions, safety primitives, Claude integration contract (completed 2026-03-11)
- [x] **Phase 2: github-issue Workflow** - Full github-issue command with worktree lifecycle, PR creation, and post-merge cleanup (completed 2026-03-12)
- [ ] **Phase 3: hack Workflow** - Full hack command with gum diff review, local merge, and both-command integration validation

## Phase Details

### Phase 1: Foundation
**Goal**: The Nix module compiles cleanly and all shared primitives are available so both commands can be built on a stable base
**Depends on**: Nothing (first phase)
**Requirements**: NX-01, NX-02, NX-03, NX-04, CL-01, CL-02, CL-03, CL-04, CL-05, SF-01, SF-02, SF-03, SF-04, SF-05, WT-03, WT-04
**Success Criteria** (what must be TRUE):
  1. Running `nixos-rebuild switch` with the module enabled produces zero errors and both stub commands appear in PATH
  2. lib.sh functions compile into both writeShellApplication derivations without shellcheck warnings
  3. State file writes are atomic (tmpfile+mv pattern) and SKILL.md is deployed to the correct home path
  4. The module registers a trap cleanup handler and gum confirm calls use the safe `if gum confirm` construct throughout lib.sh
  5. git-crypt unlock is verified with `git crypt status` before any Claude launch; push always uses `-u origin <branch>`
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md -- Nix module scaffold, lib.sh shared primitives, stub commands
- [x] 01-02-PLAN.md -- SKILL.md deployment, Claude integration contract demonstration

### Phase 2: github-issue Workflow
**Goal**: Users can run `github-issue <number>` and get a complete isolated Claude session that ends with a PR on GitHub and cleans up after merge
**Depends on**: Phase 1
**Requirements**: WT-01, WT-02, WT-05, WT-06, WT-07, RF-01, RF-02, PM-01, PM-02, PM-03, PM-04
**Success Criteria** (what must be TRUE):
  1. Running `github-issue 42` creates a worktree at `../.worktrees/issue-42/` with a correctly named branch (`fix/<slug>` or `feat/<slug>`) and a written state file
  2. After Claude exits, the script pushes the branch with `-u` and creates a PR with Summary/Test plan body format and comments on the issue with the PR link
  3. Re-invoking `github-issue 42` after interruption resumes from the last recorded phase without re-running completed steps
  4. Re-invoking `github-issue 42` after the PR is merged detects the merged state, switches to default branch, pulls, deletes branches, removes the worktree, and comments resolution on issue and PR
  5. Starting `github-issue 42` when a worktree for issue 42 already exists offers the user a choice to resume or remove, not silent failure
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md -- Core happy-path workflow: worktree creation, Claude launch, push, PR creation, issue comment
- [x] 02-02-PLAN.md -- Resume/re-invocation handling, orphan detection, post-merge cleanup

### Phase 3: hack Workflow
**Goal**: Users can run `hack "<description>"` and get an isolated Claude session with an interactive diff review that merges locally on approval
**Depends on**: Phase 2
**Requirements**: RF-03, RF-04, RF-05
**Success Criteria** (what must be TRUE):
  1. Running `hack "add rate limiting"` creates a worktree at `../.worktrees/hack-<slug>/`, launches Claude, and opens the diff in `gum pager` after Claude exits
  2. Selecting approve in the gum confirm prompt fast-forward merges the branch to the default branch and removes the worktree; selecting reject abandons the merge and leaves the worktree for inspection
  3. Ctrl+C during any gum prompt triggers the EXIT trap, cleans up the worktree, and exits without leaving orphaned state
**Plans**: 1 plan

Plans:
- [ ] 03-01-PLAN.md -- Full hack workflow: worktree creation, Claude launch, diff review, local merge, resume handling

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete   | 2026-03-11 |
| 2. github-issue Workflow | 2/2 | Complete   | 2026-03-12 |
| 3. hack Workflow | 0/1 | Not started | - |
