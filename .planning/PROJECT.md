# Worktree Flow

## What This Is

A NixOS module providing two CLI commands (`github-issue` and `hack`) that wrap Claude Code in isolated git worktrees. Each command creates a worktree, launches Claude inside it for implementation work, handles review/merge, and cleans up. Packaged via `writeShellApplication` with gum for interactive UI. Includes resume support, orphan detection, and post-merge cleanup.

## Core Value

Every Claude Code session gets full git isolation so parallel work never collides, and deterministic shell logic handles the worktree lifecycle so the AI never drifts.

## Requirements

### Validated

- v1.0: Worktree lifecycle (WT-01..07) -- worktree creation, branch naming, cleanup, resume, orphan detection
- v1.0: Claude integration (CL-01..05) -- shell owns lifecycle, state tracking, session resume
- v1.0: Review flows (RF-01..05) -- github-issue PR creation, hack diff review + local merge
- v1.0: Safety (SF-01..05) -- push guards, dirty tree check, gum prompt safety, git-crypt unlock
- v1.0: Nix packaging (NX-01..04) -- module scaffold, writeShellApplication, lib.sh sharing
- v1.0: Post-merge cleanup (PM-01..04) -- merged PR detection, branch/worktree cleanup, resolution comments

### Active

(None -- define with `/gsd:new-milestone`)

### Out of Scope

- Manual (no-AI) worktree mode -- hack always launches Claude; use gcom for manual worktrees
- Claude Code EnterWorktree/ExitWorktree -- manual git worktree add gives full control over naming and state
- Auto-merge for github-issue -- user always merges PRs on GitHub
- GitHub review for hack flow -- hack reviews and merges locally in terminal

## Context

Shipped v1.0 with 1,078 LOC (shell + nix + markdown).
Tech stack: Bash (writeShellApplication), gum, gh, jq, git-crypt, NixOS/home-manager.
30 requirements satisfied across 3 phases, 5 plans.
5 tech debt items identified in audit (duplicated functions, dead code, shared SKILL.md).

## Key Decisions

| Decision                                             | Rationale                                                                     | Outcome |
| ---------------------------------------------------- | ----------------------------------------------------------------------------- | ------- |
| Manual `git worktree add` over `EnterWorktree`       | Full control over branch naming, worktree path, and state file location       | Good    |
| New standalone module, not in claude-code            | Separation of concerns; worktree flow is its own tool                         | Good    |
| gum for interactive UI                               | Already a dependency (gcmt uses it), rich terminal UI                         | Good    |
| Local merge for `hack`, GitHub PR for `github-issue` | Different review needs: quick ad-hoc vs collaborative issue work              | Good    |
| State file in worktree root                          | Survives context compression, enables resume from any step                    | Good    |
| lib.sh inlined via builtins.readFile                 | Each command gets its own copy at build time; avoids runtime path issues      | Good    |
| SKILL.md owned by worktree-flow module               | Self-contained; deployed via home.file builtins.readFile                      | Good    |
| Numeric start index for phase_resume                 | Avoids bash ;;& fall-through pitfalls for reliable sequential phase execution | Good    |
| Combined push+PR into single phase                   | Avoids partial-state window where push succeeds but PR fails                  | Good    |

## Constraints

- **Packaging**: Must use `pkgs.writeShellApplication` with explicit `runtimeInputs` (gum, git, gh, jq)
- **Module pattern**: Standard nixerator module at `modules/apps/cli/worktree-flow/` with `apps.cli.worktree-flow.enable` option
- **Script location**: Shell scripts in `modules/apps/cli/worktree-flow/scripts/`
- **Worktree location**: `../.worktrees/issue-<number>/` or `../.worktrees/hack-<slug>/` (sibling to repo, not inside it)
- **Git safety**: Never force push, always use `-u` on first push, never push to main/master directly
- **Nix conventions**: `nix fmt`, `statix`, `deadnix` before committing

---

_Last updated: 2026-03-12 after v1.0 milestone_
