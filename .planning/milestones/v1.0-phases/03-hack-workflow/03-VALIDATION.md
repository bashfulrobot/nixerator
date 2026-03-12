---
phase: 3
slug: hack-workflow
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None -- Nix module; validation is rebuild success + manual smoke tests |
| **Config file** | N/A |
| **Quick run command** | `just quiet-rebuild` |
| **Full suite command** | `just quiet-rebuild` + `hack --help` exits 0 |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `just quiet-rebuild`
- **After every plan wave:** Run `just quiet-rebuild` + `hack --help` exits 0
- **Before `/gsd:verify-work`:** Full suite must be green + manual smoke test
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | RF-03 | smoke | `just quiet-rebuild` + manual: run hack, verify pager | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | RF-04 | smoke | `just quiet-rebuild` + manual: select No, verify worktree survives | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | RF-05 | smoke | `just quiet-rebuild` + manual: select Yes, verify merge | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `modules/apps/cli/worktree-flow/scripts/hack.sh` -- replace stub with full implementation
- [ ] `modules/apps/cli/worktree-flow/default.nix` -- add `llm-agents.claude-code` to hack-cmd runtimeInputs

*Existing infrastructure covers automated gate (Nix rebuild + shellcheck via writeShellApplication).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `hack "desc"` shows diff in gum pager after Claude exits | RF-03 | Requires interactive terminal + Claude session | Run `hack "test task"` in test repo, verify gum pager appears with diff |
| Approve prompt merges to default branch | RF-05 | Requires interactive gum confirm + git state | Select Yes at prompt, verify `git log` shows merged commits |
| Reject prompt preserves worktree | RF-04 | Requires interactive gum confirm | Select No at prompt, verify worktree directory still exists |
| Ctrl+C triggers cleanup | RF-04 | Requires signal handling test | Press Ctrl+C during gum prompt, verify clean exit without orphaned state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
