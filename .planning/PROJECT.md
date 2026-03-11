# Worktree Flow

## What This Is

A NixOS module providing two CLI commands (`github-issue` and `hack`) that wrap Claude Code in isolated git worktrees. Each command creates a worktree, launches Claude inside it for implementation work, handles review/merge, and cleans up. Packaged via `writeShellApplication` with gum for interactive UI.

## Core Value

Every Claude Code session gets full git isolation so parallel work never collides, and deterministic shell logic handles the worktree lifecycle so the AI never drifts.

## Requirements

### Validated

(None yet -- ship to validate)

### Active

- [ ] `github-issue` command: takes an issue number, creates worktree, launches Claude to implement, commits, pushes, creates PR via `gh`, cleans up after merge
- [ ] `hack` command: takes a description, creates worktree, launches Claude to implement, commits, presents gum-driven diff review in terminal, merges locally on approval, cleans up
- [ ] Both commands packaged as `writeShellApplication` in a new NixOS module at `modules/apps/cli/worktree-flow/`
- [ ] State file (`.github-issue-state.json` or similar) written in worktree for recovery if context drifts or session is interrupted
- [ ] gum-powered interactive UI for phase detection, diff review, merge confirmation, and cleanup prompts
- [ ] Worktree isolation via `git worktree add` with proper branch naming (`fix/<slug>`, `feat/<slug>`)
- [ ] Safe push with `-u` flag to prevent accidental pushes to main
- [ ] SKILL.md for `github-issue` simplified to only contain implementation instructions (commit conventions, PR format), no lifecycle management
- [ ] Parallel safety: multiple terminals running different issues/hacks never see each other's changes

### Out of Scope

- Manual (no-AI) worktree mode -- `hack` always launches Claude
- Claude Code's `EnterWorktree`/`ExitWorktree` tools -- using manual `git worktree add` via bash for full control over naming and state
- Merge on GitHub for ad-hoc flow -- `hack` reviews and merges locally in terminal
- Auto-merge for issue flow -- user always merges PRs on GitHub

## Context

- Nixerator is a NixOS flake with auto-importing modules under `modules/`
- Existing `gcmt` module demonstrates the `writeShellApplication` + gum pattern (runtimeInputs, script in `./scripts/`)
- Existing `gcom` tool in the git module already has worktree support with git-crypt unlocking -- can reference its patterns
- Current `github-issue` SKILL.md handles everything (branching, implementation, PR) in a single AI prompt, which causes context drift and no isolation
- Blog reference (mejba.me) confirms: always `git push -u`, task independence is critical for parallel work, worktrees share `.git` so they're lightweight
- Claude Code skills live in `modules/apps/cli/claude-code/skills/`

## Constraints

- **Packaging**: Must use `pkgs.writeShellApplication` with explicit `runtimeInputs` (gum, git, gh, jq)
- **Module pattern**: Standard nixerator module at `modules/apps/cli/worktree-flow/` with `apps.cli.worktree-flow.enable` option
- **Script location**: Shell scripts in `modules/apps/cli/worktree-flow/scripts/`
- **Worktree location**: `../.worktrees/issue-<number>/` or `../.worktrees/hack-<slug>/` (sibling to repo, not inside it)
- **Git safety**: Never force push, always use `-u` on first push, never push to main/master directly
- **Nix conventions**: `nix fmt`, `statix`, `deadnix` before committing

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Manual `git worktree add` over `EnterWorktree` | Full control over branch naming, worktree path, and state file location | -- Pending |
| New standalone module, not in claude-code | Separation of concerns; worktree flow is its own tool | -- Pending |
| gum for interactive UI | Already a dependency (gcmt uses it), rich terminal UI | -- Pending |
| Local merge for `hack`, GitHub PR for `github-issue` | Different review needs: quick ad-hoc vs collaborative issue work | -- Pending |
| State file in worktree root | Survives context compression, enables resume from any step | -- Pending |

---
*Last updated: 2026-03-11 after initialization*
