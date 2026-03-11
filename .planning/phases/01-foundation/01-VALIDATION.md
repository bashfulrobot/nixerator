---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 1 -- Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None -- Nix module; validation is `nixos-rebuild switch` success |
| **Config file** | N/A |
| **Quick run command** | `just quiet-rebuild` |
| **Full suite command** | `just quiet-rebuild` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `just quiet-rebuild`
- **After every plan wave:** Run `just quiet-rebuild` + manual PATH check
- **Before `/gsd:verify-work`:** Clean rebuild with both binaries in PATH, zero shellcheck warnings
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | NX-01 | smoke | `nixos-rebuild switch` (zero errors) | Wave 0 | pending |
| 01-01-02 | 01 | 1 | NX-02 | smoke | `which github-issue && which hack` post-rebuild | Wave 0 | pending |
| 01-01-03 | 01 | 1 | NX-03 | smoke | `github-issue --help && hack --help` (zero exit) | Wave 0 | pending |
| 01-01-04 | 01 | 1 | NX-04 | manual | `ls modules/apps/cli/worktree-flow/scripts/` | Wave 0 | pending |
| 01-01-05 | 01 | 1 | SF-04 | static | `grep -n 'gum confirm' scripts/lib.sh` -- no bare usage | Wave 0 | pending |
| 01-01-06 | 01 | 1 | WT-04 | static | `grep -n 'mktemp' scripts/lib.sh` -- verify mv follows | Wave 0 | pending |
| 01-01-07 | 01 | 1 | SF-05 | static | `grep -n 'crypt status' scripts/lib.sh` | Wave 0 | pending |
| 01-01-08 | 01 | 1 | SF-02 | static | `grep -n 'main\|master' scripts/lib.sh` -- assert_not_main | Wave 0 | pending |
| 01-01-09 | 01 | 1 | CL-04 | smoke | `ls ~/.claude/skills/github-issue/SKILL.md` post-rebuild | Wave 0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `modules/apps/cli/worktree-flow/default.nix` -- module skeleton
- [ ] `modules/apps/cli/worktree-flow/scripts/lib.sh` -- shared primitives

*Existing infrastructure covers remaining requirements via `just quiet-rebuild`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Scripts dir structure | NX-04 | File layout verification | `ls modules/apps/cli/worktree-flow/scripts/` |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
