---
phase: 2
slug: github-issue-workflow
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property               | Value                                                                  |
| ---------------------- | ---------------------------------------------------------------------- |
| **Framework**          | None -- Nix module; validation is rebuild success + manual smoke tests |
| **Config file**        | N/A                                                                    |
| **Quick run command**  | `just quiet-rebuild`                                                   |
| **Full suite command** | `just quiet-rebuild` + manual `github-issue --help`                    |
| **Estimated runtime**  | ~30 seconds                                                            |

---

## Sampling Rate

- **After every task commit:** Run `just quiet-rebuild`
- **After every plan wave:** Run `just quiet-rebuild` + `github-issue --help` exits 0
- **Before `/gsd:verify-work`:** Full smoke test against a real test repo
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID  | Plan | Wave | Requirement | Test Type | Automated Command                             | File Exists | Status     |
| -------- | ---- | ---- | ----------- | --------- | --------------------------------------------- | ----------- | ---------- |
| 02-01-01 | 01   | 1    | WT-01       | smoke     | `just quiet-rebuild` + manual worktree verify | ✅          | ⬜ pending |
| 02-01-02 | 01   | 1    | WT-07       | smoke     | Manual: invoke twice, verify gum choose       | ✅          | ⬜ pending |
| 02-01-03 | 01   | 1    | WT-06       | smoke     | Manual: kill during claude, re-invoke         | ✅          | ⬜ pending |
| 02-01-04 | 01   | 1    | WT-02       | smoke     | Manual: create orphan, re-run                 | ✅          | ⬜ pending |
| 02-02-01 | 02   | 1    | RF-01       | smoke     | `gh pr list` after script run                 | ✅          | ⬜ pending |
| 02-02-02 | 02   | 1    | RF-02       | smoke     | `gh issue view --comments`                    | ✅          | ⬜ pending |
| 02-03-01 | 03   | 2    | PM-01       | smoke     | Manual: merge PR, re-invoke                   | ✅          | ⬜ pending |
| 02-03-02 | 03   | 2    | PM-02       | smoke     | `git branch -a` after cleanup                 | ✅          | ⬜ pending |
| 02-03-03 | 03   | 2    | PM-03       | smoke     | `git worktree list` after cleanup             | ✅          | ⬜ pending |
| 02-03-04 | 03   | 2    | PM-04       | smoke     | `gh issue view` + `gh pr view --comments`     | ✅          | ⬜ pending |

_Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky_

---

## Wave 0 Requirements

- [ ] `modules/apps/cli/worktree-flow/default.nix` -- add `pkgs.llm-agents.claude-code` to runtimeInputs
- [ ] `modules/apps/cli/worktree-flow/scripts/github-issue.sh` -- replace stub with full implementation

_No new test framework needed -- rebuild is the automated gate._

---

## Manual-Only Verifications

| Behavior                             | Requirement | Why Manual                          | Test Instructions                                                                 |
| ------------------------------------ | ----------- | ----------------------------------- | --------------------------------------------------------------------------------- |
| Worktree creation at correct path    | WT-01       | Requires real git repo with remote  | Run `github-issue 42`, verify `git worktree list` shows `../.worktrees/issue-42/` |
| Orphan worktree detection            | WT-02       | Requires corrupted worktree state   | Create orphan worktree, re-run script, verify warning prompt                      |
| Resume from interrupted phase        | WT-06       | Requires interruption mid-execution | Kill during `claude_running` phase, re-invoke, verify state pickup                |
| Existing worktree conflict           | WT-07       | Requires pre-existing worktree      | Invoke twice for same issue, verify gum choose appears                            |
| PR creation with correct body format | RF-01       | Requires real GitHub remote         | Run script, verify `gh pr view --json body` has Summary/Test plan                 |
| Issue comment with PR link           | RF-02       | Requires real GitHub issue          | Verify `gh issue view <n> --comments` shows PR link                               |
| Merged PR detection                  | PM-01       | Requires merged PR state            | Merge PR, re-invoke, verify cleanup triggers                                      |
| Branch cleanup                       | PM-02       | Requires real branches to delete    | After cleanup, verify `git branch -a` shows no feature branch                     |
| Worktree removal                     | PM-03       | Requires active worktree to remove  | After cleanup, verify `git worktree list` clean                                   |
| Resolution comments                  | PM-04       | Requires real GitHub issue+PR       | After cleanup, verify comments on both issue and PR                               |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
