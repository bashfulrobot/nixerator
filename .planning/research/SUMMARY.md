# Project Research Summary

**Project:** worktree-flow (github-issue + hack commands)
**Domain:** Git worktree lifecycle CLI tooling with Claude Code integration
**Researched:** 2026-03-11
**Confidence:** HIGH

## Executive Summary

worktree-flow is a NixOS module delivering two shell commands (`github-issue` and `hack`) that wrap Claude Code in deterministic git worktrees. The key insight from research is that the current SKILL.md-only approach fails because it asks Claude to manage the worktree lifecycle (branch creation, push, PR), which causes context drift and non-deterministic behavior. The correct architecture inverts this: the shell script owns the entire lifecycle while Claude owns only implementation inside the worktree. This is a well-established pattern in the ecosystem and maps cleanly to existing codebase patterns (gcmt, gcom).

The recommended implementation uses `writeShellApplication` with external script files (the gcmt pattern), a shared `lib.sh` concatenated at build time, `gum` for all interactive UI, `jq` for atomic state file management, and the `gh` CLI for GitHub operations. All of these are already present in the codebase or in nixpkgs unstable, making this a zero-new-dependency project. The two commands differ in their review flows: `github-issue` routes work through GitHub PR review while `hack` uses a local gum-driven diff review and fast-forward merge.

The highest risks are operational: orphaned worktrees from partial failures, silent git-crypt unlock failures exposing encrypted files to Claude, and `gum confirm` exits under strict shell mode leaving worktrees behind. All three have well-documented prevention patterns and must be addressed in Phase 1 before the tool is considered safe to use. A `trap cleanup EXIT` pattern, atomic state file writes, and `if gum confirm` constructs (never bare `gum confirm`) are non-negotiable from the first commit.

---

## Key Findings

### Recommended Stack

The stack is entirely in-codebase or already in nixpkgs. No new dependencies need to be evaluated. `writeShellApplication` (nixpkgs built-in) provides automatic shellcheck, bash strict mode, and PATH isolation, making it the correct packaging primitive. Scripts must live in external files (`./scripts/name.sh` via `builtins.readFile`) rather than inline Nix strings; these scripts are 150-300 lines each and inline embedding defeats editor support and shellcheck integration.

**Core technologies:**

- `writeShellApplication`: script packaging -- strict mode, shellcheck, PATH isolation, already the pattern in gcmt and git modules
- `bash`: script language -- writeShellApplication targets bash explicitly; set -euo pipefail is automatic
- `gum 0.17.0`: interactive terminal UI -- confirm, choose, spin, log, pager, style; already a runtimeInput in gcmt, no new dependency
- `git worktree`: isolated workspaces -- shares .git directory, lightweight, already used in gcom
- `gh 2.87.3`: GitHub operations -- issue fetch, PR creation, branch cleanup; already in git module runtimeInputs
- `jq`: state management -- JSON state file read/write; already used in todoist-report and check-pkg-updates
- `lib.sh` concatenated at build time: shared functions across both scripts -- Nix store paths are not stable, so runtime `source` is not viable; build-time string concatenation is the correct idiom

### Expected Features

**Must have (table stakes):**

- Deterministic worktree creation with `fix/<slug>` or `feat/<slug>` branch naming from issue title
- Worktree placed as sibling to repo (`../.worktrees/`) to keep main repo `git status` clean
- State file written before Claude launches -- if write fails, abort; no state means no recovery
- Phase detection on re-invocation -- detect merged PR or merged branch and skip to cleanup
- Atomic cleanup: `git worktree remove`, `git worktree prune`, local branch delete, optional remote branch delete
- `git push -u origin` before PR creation -- never bare `git push`
- Git repo guard and default branch detection at startup

**Should have (differentiators):**

- Two distinct review flows in one module: `github-issue` via GitHub PR, `hack` via local gum diff review
- State file resume from any phase -- re-invoke after interrupted session, tool reads phase and continues
- Orphaned worktree detection on startup -- warn if prior worktree for same issue/slug exists; offer adopt or remove
- SKILL.md scoped to implementation only -- no lifecycle instructions for Claude, reducing context drift
- Shell owns the lifecycle entirely -- Claude only commits; shell reads observable git/gh state after Claude exits

**Defer to v2+:**

- Rich diff paging (delta/difftastic integration) -- raw `git diff` piped to `gum pager` is sufficient for v1
- Orphaned worktree scan across all open worktrees -- `git worktree list` warning can come later
- Rebase conflict resolution in `hack` merge path -- abort with clear message for v1; user resolves manually

**Anti-features (never build):**

- Manual (no-AI) worktree mode -- `gcom -w` already covers this
- Auto-merge for `github-issue` -- removes the human review gate
- Config file (`.worktreerc`, YAML) -- hardcode sensible defaults; behavior should be obvious from code
- Claude Code `EnterWorktree`/`ExitWorktree` tools -- cedes naming and path control to Claude

### Architecture Approach

The module uses four components with clear ownership boundaries: `default.nix` for Nix packaging, `lib.sh` for shared functions concatenated at build time, and two script files (`github-issue.sh`, `hack.sh`) that source lib functions. SKILL.md lives in the worktree-flow module (not in `claude-code/skills/`) because its lifecycle is owned here. The state file (`.worktree-state.json`) is strictly shell-to-shell; Claude never reads or writes it. Claude communicates results through commits and exit codes only.

**Major components:**

1. `default.nix` -- Nix packaging; wires runtimeInputs; concatenates lib.sh into each writeShellApplication; deploys SKILL.md via home.file
2. `lib.sh` -- shared functions: guards, default-branch detection, slug generation, worktree path builder, state_write/state_read, launch_claude, worktree_cleanup
3. `github-issue.sh` -- full issue lifecycle: worktree creation, Claude launch, push, PR creation via gh, issue comment, post-merge cleanup on re-invocation
4. `hack.sh` -- ad-hoc lifecycle: worktree creation, Claude launch, gum diff review, local ff-only merge, cleanup
5. `SKILL.md` -- Claude's implementation instructions only: commit format, PR body format; no lifecycle
6. `.worktree-state.json` -- runtime state per worktree; phase enum enables resume from any checkpoint

### Critical Pitfalls

1. **Orphaned worktrees from partial failures** -- register `trap cleanup EXIT` immediately after `git worktree add`; write a `WORKTREE_READY` flag as the last setup step so partial setups are detectable on resume. Run `git worktree prune` at the start of every cleanup function.

2. **gum confirm kills the script under strict mode** -- `gum confirm` exits 1 on "No" and 130 on Ctrl+C; `set -e` treats both as fatal. Never use bare `gum confirm`. Always use `if gum confirm "..."` construct. The EXIT trap fires on exit 130, enabling cleanup on Ctrl+C.

3. **git-crypt silent unlock failure** -- `git crypt unlock` can exit 0 while files remain encrypted in a linked worktree. After unlock, verify with `git -C "$wt_path" crypt status`. Abort and remove the worktree if verification fails. Never launch Claude if git-crypt verification fails.

4. **State file corruption from partial writes** -- shell redirection (`jq > file`) is not atomic. Always write to a tempfile and `mv` atomically: `tmp=$(mktemp); jq ... > "$tmp" && mv "$tmp" "$state_file"`. Validate with `jq empty` after write.

5. **writeShellApplication strict mode breaks probe commands** -- every git command used as a conditional check (not an operation) must have `|| true` or an `if` guard. `git rev-parse --verify ref 2>/dev/null || true` is the correct pattern. shellcheck runs at build time -- treat all warnings as errors.

---

## Implications for Roadmap

Based on the dependency graph in FEATURES.md and the build order in ARCHITECTURE.md, a 4-phase structure is recommended.

### Phase 1: Foundation (lib.sh + default.nix + SKILL.md)

**Rationale:** All subsequent phases depend on lib.sh functions being available and the Nix module compiling cleanly. Establishing the module skeleton, shared functions, and SKILL.md first validates the Nix packaging pattern before any script logic is written.
**Delivers:** Compilable Nix module at `modules/apps/cli/worktree-flow/`; `lib.sh` with all shared guards, helpers, state_write/state_read, and launch_claude; simplified SKILL.md deployed via home.file; both writeShellApplication derivations wired (even if scripts are stubs).
**Addresses:** Git repo guard, default branch detection, worktree path builder, state file atomic write pattern, launch_claude function.
**Avoids:** Pitfall 1 (trap must be wired in lib.sh), Pitfall 4 (gum confirm pattern established in lib.sh as the canonical helper), Pitfall 5 (atomic state write in lib.sh from day one), Pitfall 9 (strict mode compliance in all lib functions).

### Phase 2: github-issue Workflow

**Rationale:** github-issue is the higher-complexity flow (requires gh, PR creation, issue commenting, post-merge phase detection). Building it before hack validates the full lifecycle including the most complex cleanup path. lib.sh must be complete before this phase starts.
**Delivers:** Full `github-issue <number>` command: worktree creation, state file, Claude launch, push, PR creation, issue comment, post-merge cleanup on re-invocation, orphaned worktree detection.
**Uses:** `git worktree add`, `gh issue view`, `gh pr create`, `gh issue comment`, `gum` interactive prompts, jq state management.
**Implements:** `github-issue.sh` consuming all lib.sh functions.
**Avoids:** Pitfall 7 (always `git push -u origin` before `gh pr create`), Pitfall 3 (git-crypt verification before Claude launch), Pitfall 8 (all git operations complete before Claude is launched).

### Phase 3: hack Workflow

**Rationale:** hack is structurally similar to github-issue but simpler (no GitHub interaction). Building it after github-issue means all the lib.sh patterns are proven and the only new surface is the gum diff review loop and local ff-only merge. Can be developed largely in parallel with Phase 2 if resourcing allows.
**Delivers:** Full `hack "<description>"` command: worktree creation, state file, Claude launch, gum diff review via `gum pager`, merge confirmation, ff-only local merge, cleanup.
**Uses:** `git diff`, `gum pager`, `git merge --ff-only`, no gh dependency.
**Implements:** `hack.sh` consuming lib.sh functions.
**Avoids:** Pitfall 12 (fetch + rebase check before diff review; abort on conflict), Pitfall 4 (gum confirm in the merge gate).

### Phase 4: Integration and Edge Cases

**Rationale:** End-to-end testing of both flows, interrupted session recovery, and the cross-cutting pitfall mitigations. Many edge cases (existing branch, invocation from inside a worktree, user Ctrl+C during review) can only be validated against both scripts working together.
**Delivers:** Verified interrupt/resume behavior, orphaned worktree recovery path (detect + adopt or remove), branch collision detection (pre-check before `git worktree add`), `.claude/` artifact cleanup in worktree remove, worktree path resolution fix when invoked from inside an existing worktree.
**Addresses:** All deferred edge cases from Phases 1-3; Pitfall 2, Pitfall 6, Pitfall 10, Pitfall 11.

### Phase Ordering Rationale

- lib.sh must precede both scripts because `writeShellApplication` concatenates it at build time; a missing function is a build failure, not a runtime error.
- The Nix module must compile in Phase 1 so every subsequent rebuild produces working binaries even when scripts are incomplete stubs.
- github-issue precedes hack because it exercises more of the stack (gh, state transitions, PR lifecycle); bugs found there improve hack's implementation.
- Integration phase is last because edge cases require both scripts to be functionally complete; testing partial flows produces misleading results.

### Research Flags

Phases with standard patterns (skip research-phase, all patterns verified):

- **Phase 1:** writeShellApplication + lib.sh concatenation pattern is fully documented in the codebase (gcmt reference). No new research needed.
- **Phase 2:** All gh commands and git worktree operations verified against official docs and nixpkgs. No new research needed.
- **Phase 3:** hack is a subset of Phase 2 patterns; no new research needed.
- **Phase 4:** Edge cases are enumerated in PITFALLS.md with prevention code already specified. No research needed; this is implementation work.

No phases require `/gsd:research-phase`. All research questions were resolved during the initial research pass with HIGH confidence.

---

## Confidence Assessment

| Area         | Confidence | Notes                                                                                                                                                        |
| ------------ | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Stack        | HIGH       | All components verified against in-codebase patterns (gcmt, gcom, todoist-report) and official docs. Zero speculative choices.                               |
| Features     | HIGH       | PROJECT.md and current SKILL.md are authoritative; gap analysis against ecosystem tools is well-supported by multiple corroborating sources.                 |
| Architecture | HIGH       | Derived entirely from direct codebase analysis. lib.sh concatenation pattern, state file contract, and Claude invocation approach are all confirmed idioms.  |
| Pitfalls     | HIGH       | Critical pitfalls backed by official issue trackers (gh CLI, git-crypt, Claude Code, gum) and in-codebase reference implementations (gcom cleanup patterns). |

**Overall confidence:** HIGH

### Gaps to Address

- **`claude` in PATH vs runtimeInputs:** `claude-code` module installs claude to `environment.systemPackages`, so it should be in PATH at runtime. However `writeShellApplication` isolates PATH to runtimeInputs. If `claude` is not in runtimeInputs, it will not be found at runtime. Add `pkgs.claude-code` (or the local build derivation) to runtimeInputs in default.nix, or verify the outer system PATH is inherited. Test immediately on first rebuild.
- **gnused necessity:** gnused is specified as the safe choice over coreutils sed on NixOS. Confirm this is necessary for the slug generation patterns used (extended regex, in-place replacement) before publishing the module. If standard POSIX sed suffices, coreutils covers it.
- **SKILL.md deployment path:** Two options exist: deploy via worktree-flow's `home.file` or use the claude-code module's existing skills installation mechanism. The choice affects whether the claude-code module needs to know about worktree-flow. The home.file approach in worktree-flow's default.nix is self-contained and preferred.

---

## Sources

### Primary (HIGH confidence)

- `.planning/PROJECT.md` -- authoritative project requirements and constraints
- `modules/apps/cli/claude-code/skills/github-issue/SKILL.md` -- current skill being replaced/simplified
- `modules/apps/cli/gcmt/default.nix` and `scripts/gcmt.sh` -- canonical writeShellApplication + gum pattern
- `modules/apps/cli/git/default.nix` -- gcom worktree patterns, default branch detection, cleanup functions
- `modules/apps/cli/todoist-report/` -- jq state file pattern reference
- Official Claude Code headless docs: https://code.claude.com/docs/en/headless
- git worktree official docs: https://git-scm.com/docs/git-worktree
- gum v0.17.0 release: https://github.com/charmbracelet/gum/releases
- writeShellApplication reference: https://ryantm.github.io/nixpkgs/builders/trivial-builders/

### Secondary (MEDIUM confidence)

- gh CLI nixpkgs package (2.87.3): https://search.nixos.org/packages?show=gh
- gh pr create lacks --json output: https://github.com/cli/cli/issues/6366 and /11196
- gh pr create pushes to wrong remote: https://github.com/cli/cli/issues/588 and /5872
- git-crypt per-worktree unlock requirement: https://github.com/AGWA/git-crypt/issues/105 and /139
- gum confirm exit codes: https://github.com/charmbracelet/gum/discussions/263 and /351
- Claude Code stale index.lock from background ops: https://github.com/anthropics/claude-code/issues/11005
- Worktree bootstrap orphan issue pattern: https://github.com/anomalyco/opencode/issues/14648

### Tertiary (contextual)

- [coderabbitai/git-worktree-runner](https://github.com/coderabbitai/git-worktree-runner) -- hooks pattern
- [automazeio/ccpm](https://github.com/automazeio/ccpm) -- GitHub Issues + worktrees state management
- [claudefa.st worktree guide](https://claudefa.st/blog/guide/development/worktree-guide) -- parallel sessions design

---

_Research completed: 2026-03-11_
_Ready for roadmap: yes_
