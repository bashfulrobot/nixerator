# Feature Landscape

**Domain:** Worktree-based Claude Code workflow CLI tooling (github-issue + hack commands)
**Researched:** 2026-03-11
**Overall confidence:** HIGH (project context from PROJECT.md + SKILL.md is authoritative; ecosystem findings from multiple corroborating sources)

---

## Table Stakes

Features users expect. Missing = the tool feels broken or unsafe.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `git worktree add` with deterministic branch naming | Isolation is the entire value proposition; without it you just have a fancy wrapper around `claude` | Low | `fix/<slug>` or `feat/<slug>` derived from issue title or description; branch uniqueness check before creation |
| Worktree outside repo root | Prevents accidental `git add -A` from picking up sibling worktrees; makes `git status` in main repo clean | Low | `../.worktrees/issue-<number>/` or `../.worktrees/hack-<slug>/`; sibling pattern already validated in PROJECT.md |
| Atomic cleanup on success | Leaving stale worktrees and branches is the #1 pain point in all worktree tooling | Medium | Remove worktree dir, delete local branch, delete remote branch (github-issue), call `git worktree prune` |
| `git push -u` on first push | Prevents "refusing to push to main" accidents; establishes tracking | Low | Always `-u origin <branch>`; never bare `git push` |
| Claude launched inside worktree | The AI must see only the isolated working tree, not the main repo | Low | `cd <wt-path> && claude -p ...` or `claude --cwd <wt-path>`; working dir determines what Claude reads |
| Phase detection on re-invocation | Users re-invoke after merging; tool must not re-implement | Medium | Check for existing merged PR (github-issue) or check if branch already merged (hack); state file is the reliable signal |
| State file written before Claude launches | If Claude's context drifts or session crashes, the shell wrapper must know where to resume | Medium | JSON in worktree root: `{ "phase": "implement", "issue": 42, "branch": "fix/...", "worktree": "..." }` |
| Cleanup prompt before removal | Never silently delete work | Low | `gum confirm "Remove worktree at <path>?"` before `git worktree remove` |
| Git repo guard | Fail fast if invoked outside a git repo | Low | `git rev-parse --git-dir` check at startup; clear error message |
| Default branch detection | Hardcoding `main` breaks repos that use `master` or `develop` | Low | `git symbolic-ref refs/remotes/origin/HEAD` with fallback probe; already proven in gcom |
| Dirty working tree guard (main repo) | Creating a worktree from a dirty main is fine; but the branch base must be clean origin state | Low | Fetch before creating worktree; branch from `origin/<default>` not local HEAD |
| No-push-to-main enforcement | Core git safety constraint | Low | Check `current_branch != default_branch` before any push; die immediately if violated |

---

## Differentiators

Features that set this tool apart from generic worktree managers and the existing SKILL.md approach.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Two distinct review flows in one tool | github-issue targets async collaborative review (GitHub PR); hack targets synchronous local review (gum diff) -- neither tool in the ecosystem handles both correctly | Medium | Separate terminal UX paths; not just a flag difference |
| gum-powered diff review for hack | `git diff main...<branch>` rendered via `gum pager` or piped through `delta`/`difftastic`; user reads before confirming merge | Medium | `gum pager` for scrollable diff; `gum confirm "Merge this?"` for approval gate |
| Lifecycle entirely in shell, not in AI prompt | Current SKILL.md makes Claude do branch creation, push, PR -- this causes context drift and the AI can skip steps | Low | Shell handles all git operations; SKILL.md only carries implementation conventions |
| State file enables resume from any phase | If terminal dies mid-session: re-invoke, tool reads state file, skips completed phases | High | State file has `phase` enum: `created`, `implementing`, `committed`, `pushed`, `pr_open`, `merged`, `cleaned`; each phase transition writes file atomically |
| Parallel safety by construction | Two terminals can run `github-issue 42` and `github-issue 43` simultaneously with zero coordination | Low | Each worktree is a unique path; git enforces one-branch-per-worktree natively; no application-level locking needed |
| SKILL.md reduced to implementation-only | The simplified SKILL.md carries only commit conventions and PR format -- no lifecycle instructions -- so Claude's context is pure implementation | Low | Shell wrapper passes context via `-p` prompt that says "You are inside worktree for issue X; implement only" |
| Orphaned worktree detection on startup | On invocation, list `git worktree list` and warn if prior worktrees for this issue/slug exist | Medium | Detect leftover from a crashed session; offer to adopt (resume) or remove before creating new |
| Issue metadata in PR body | Auto-populate PR body with `gh issue view <number>` content; link back to issue | Low | `Closes #<number>` in commit body and PR; `gh issue comment` after PR created |
| Local ff-only merge for hack | Fast-forward-only merge keeps a clean linear history for ad-hoc work; rebase before merge | Medium | `git fetch origin <default> && git rebase origin/<default>` then `git merge --ff-only`; die if rebase has conflicts with clear message |

---

## Anti-Features

Features to deliberately NOT build. Each one is a temptation that adds complexity without proportional value for this use case.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Manual (no-AI) worktree mode | Adds a code path that conflicts with the design assumption that Claude does the implementation; `gcom` already handles this | Use `gcom -w` for pure-human worktree workflows |
| Claude Code `EnterWorktree`/`ExitWorktree` tools | Cedes control over naming, path, and state file location to Claude; determinism breaks | Manual `git worktree add` in bash, full control over every variable |
| Auto-merge for github-issue | PRs need human eyes; auto-merge removes the safety gate that is the whole point of GitHub review | User merges on GitHub; tool handles post-merge cleanup on re-invocation |
| Merge on GitHub for hack | hack is for quick local ad-hoc work; routing it through GitHub adds latency and ceremony with no benefit | Local merge with gum-driven diff review in terminal |
| Stacked PRs / dependent worktrees | Requires a dependency graph, ordering logic, and rebase chains; enormous complexity for rare use case | One issue per worktree; if work is dependent, do it sequentially |
| Config file (`.worktreerc`, YAML) | Adds an indirection layer that obscures behavior; the two commands have fixed semantics | Hardcode sensible defaults; if a default must change, it is a code change |
| Worktree pool / reuse | Pre-creating idle worktrees wastes disk and complicates state reasoning | Create fresh worktree per invocation; creation is cheap (`git worktree add` is fast) |
| Notification hooks | Out of scope for v1; adds dependency surface | Out of scope; users can wrap commands themselves if desired |
| Remote worktrees (SSH, container) | Entirely different problem domain | Not applicable; local-only |
| Worktree for non-git directories | Edge case with no existing use case in this codebase | Die with clear error: "not inside a git repository" |
| Interactive branch-name editor | Branch name is deterministic from issue number/title; offering to rename adds decision fatigue | Auto-derive; document the naming rule |

---

## Feature Dependencies

```
git repo guard
  └── default branch detection
        └── worktree creation (git worktree add with branch from origin/<default>)
              └── state file write (phase: created)
                    └── Claude launch (inside worktree, SKILL.md conventions only)
                          └── state file update (phase: implementing -> committed -> pushed)
                                ├── [github-issue path]
                                │     └── PR creation (gh pr create)
                                │           └── issue comment (gh issue comment)
                                │                 └── [user merges on GitHub]
                                │                       └── phase detection on re-invocation (phase: merged)
                                │                             └── cleanup (worktree remove, branch delete, prune)
                                └── [hack path]
                                      └── diff review (gum pager + git diff)
                                            └── merge confirmation (gum confirm)
                                                  └── ff-only merge (git merge --ff-only)
                                                        └── cleanup (worktree remove, branch delete, prune)

orphaned worktree detection
  └── startup check (git worktree list)
        └── adopt (resume from state file) OR remove (cleanup + start fresh)
```

**Critical dependency:** State file must be written before Claude launches. If the write fails, the tool must abort -- launching Claude without state means no recovery path exists.

**Parallel safety dependency:** Worktree path uniqueness (`issue-<number>` or `hack-<slug>-<timestamp>`) is the only coordination mechanism needed. Git enforces branch uniqueness natively (cannot check out same branch in two worktrees).

---

## MVP Recommendation

Prioritize (in order):

1. Worktree creation with branch naming, state file, and Claude launch (core isolation guarantee)
2. github-issue: PR creation, issue comment, post-merge cleanup via re-invocation
3. hack: gum diff review, merge confirmation, ff-only local merge, cleanup
4. Phase detection and orphaned worktree detection (makes the tool safe to re-invoke)
5. State file resume (graceful recovery from interrupted sessions)

Defer:

- **Orphaned worktree detection across all open worktrees:** Useful but not blocking; `git worktree list` warning can be v2
- **Rebase-before-merge conflict handling in hack:** Show a clear error and abort; user resolves manually for v1
- **Rich diff paging in hack:** `gum pager` with raw `git diff` output is sufficient for v1; `delta`/`difftastic` integration can come later

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Table stakes | HIGH | PROJECT.md + SKILL.md provide authoritative context; gcom confirms patterns; git docs confirm worktree constraints |
| Differentiators | HIGH | Derived from gap analysis between current SKILL.md approach and PROJECT.md requirements; supported by ecosystem research showing no existing tool covers both review flows |
| Anti-features | HIGH | Directly from PROJECT.md "Out of Scope" section plus ecosystem research confirming complexity of excluded features |
| MVP ordering | MEDIUM | Ordering is judgment call based on dependency graph; not validated with user |

---

## Sources

- Project context: `/home/dustin/dev/nix/nixerator/.planning/PROJECT.md` (authoritative)
- Current skill: `/home/dustin/dev/nix/nixerator/modules/apps/cli/claude-code/skills/github-issue/SKILL.md` (authoritative)
- Existing worktree pattern: `/home/dustin/dev/nix/nixerator/modules/apps/cli/git/default.nix` (gcom reference implementation)
- [coderabbitai/git-worktree-runner](https://github.com/coderabbitai/git-worktree-runner) - ecosystem reference, hooks pattern
- [worktrunk.dev](https://worktrunk.dev/) - post-start hooks pattern, parallel workflow design
- [automazeio/ccpm](https://github.com/automazeio/ccpm) - GitHub Issues + worktrees pattern, state management
- [kbwo/ccmanager](https://github.com/kbwo/ccmanager) - session state copy across worktrees pattern
- [agenttools/worktree](https://github.com/agenttools/worktree) - CLI design for GitHub issue + worktree integration
- [opencode orphaned worktree fix](https://github.com/anomalyco/opencode/pull/14649) - cleanup on bootstrap failure pattern
- [git-scm.com/docs/git-worktree](https://git-scm.com/docs/git-worktree) - lock files, prune behavior, one-branch-per-worktree constraint
- [claudefa.st worktree guide](https://claudefa.st/blog/guide/development/worktree-guide) - parallel sessions without conflicts
- [boundaryml.com podcast: git worktrees for AI agents](https://boundaryml.com/podcast/2025-12-09-git-worktrees) - AI agent + worktree patterns
- [gsd agent tracking](https://deepwiki.com/glittercowboy/get-shit-done/5.8-agent-tracking-and-resume) - state file JSON resume pattern
