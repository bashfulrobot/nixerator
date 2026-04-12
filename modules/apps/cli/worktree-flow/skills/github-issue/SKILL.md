---
name: github-issue
description: Use when working on a GitHub issue (by number or URL), checking issue
  work status, resuming interrupted issue work, addressing PR review feedback, or
  cleaning up after a merged PR. Also trigger when the user mentions an issue number
  in the context of implementation work, or asks about the status of ongoing issue work.
---

# GitHub Issue Workflow

State-machine orchestrator for the full GitHub issue lifecycle — from triage through PR merge. Detects current state on every invocation and routes to the appropriate phase.

Works in two contexts:
- **Worktree mode**: launched by the `github-issue` CLI inside an isolated worktree
- **Standalone mode**: invoked directly in Claude Code (e.g., "work on issue #42")

## Worktree Audit (run on every invocation)

Before routing to a specific issue, scan for existing worktrees and cross-reference their PR state. This catches stale worktrees from previous work that are ready for cleanup.

```bash
# Find all issue worktrees
find "$(git rev-parse --show-toplevel)/../.worktrees" -maxdepth 1 -name 'issue-*' -type d 2>/dev/null
```

For each worktree with a `.worktree-state.json`:
1. Read `branch` and `pr_url` from the state file
2. If `pr_url` exists, check: `gh pr view <pr_url> --json state,reviewDecision`
3. Report a summary to the user:

```
Active issue worktrees:
  #42: add JWT auth [pr_created] — PR merged ⚠️ ready for cleanup
  #17: fix null response [claude_running] — PR: changes requested
  #53: update docs [pushing] — no PR yet
```

If any worktrees have merged PRs, tell the user: "Run `github-issue` (the CLI) to auto-clean merged worktrees, or select one to resume."

If the user asked to list/check status (not work on a specific issue), stop here after the report. If they specified an issue number, continue to state detection below.

## State Detection

**Run this after the worktree audit.** Read `references/state-detection.md` for the full algorithm and edge cases.

Quick version — check signals in priority order, first match wins:

1. PR exists for this issue's branch?
   - Merged → **DONE** (report; cleanup is bash's job in worktree mode)
   - Changes requested → **REVAMP**
   - Approved → **READY** (merge-ready)
   - Open, pending review → **READY** (awaiting review)
   - Closed without merge → report; offer reopen/new-PR/abandon
2. Feature branch exists?
   - Has commits or uncommitted changes → **IMPLEMENT**
   - Clean with plan artifact → **IMPLEMENT**
   - Clean, no plan → **ASSESS**
3. No branch, no PR → **ASSESS**

In worktree mode, also read `.worktree-state.json` for phase, branch, issue metadata — but live gh/git signals override stale state.

## States

### ASSESS

Read the issue and classify complexity to determine how much pipeline to use.

```
Fetch: gh issue view <number> --json title,body,labels,state
  (or use issue body from system prompt in worktree mode)

Classify:
  trivial  (one-file fix, clear problem)     → skip to IMPLEMENT
  standard (multi-file, clear requirements)   → skip to PLAN
  complex  (unclear requirements, design needed) → proceed to DESIGN
```

Present the assessment to the user. Let them confirm or override the classification before proceeding.

### DESIGN

**Invoke `superpowers:brainstorming`.**

This is a hard gate — do not implement until the design is approved. The brainstorming skill explores intent, requirements, and design options before any code is written.

Output: an approved design or spec that feeds into PLAN.

### PLAN

**Invoke `superpowers:writing-plans`.**

Input: issue body + design (if DESIGN ran). Output: an implementation plan with discrete tasks.

### IMPLEMENT

Execute the implementation work.

- If a plan exists → **invoke `superpowers:subagent-driven-development`** (for plans with independent tasks) or **`superpowers:executing-plans`** (for sequential tasks)
- If trivial (no plan) → implement directly

Follow commit conventions from `references/conventions.md`:
- Format: `type(scope): :emoji: description`
- Sign with `-S`, no Co-Authored-By
- Atomic commits — one logical change per commit

### VERIFY

**Invoke `superpowers:verification-before-completion`.**

Run the project's test suite, linters, and build. Evidence before claims, always. If verification fails, loop back to IMPLEMENT with the failure context — do not skip ahead.

### READY

Implementation is verified. Next steps depend on context:

**Worktree mode:** Report completion status and exit. The bash script handles push + PR creation after Claude exits. Do NOT create PRs from inside Claude in worktree mode.

```
"Implementation complete. N commit(s) on branch <branch>.
Exit Claude to proceed to push + PR creation."
```

**Standalone mode:** Claude handles push + PR directly:

```bash
git push -u origin <branch>
gh pr create --title "<issue title>" --body "## Summary
Closes #<number>: <title>

<commit log>"
```

### REVAMP

PR received "changes requested". Read `references/revamp-workflow.md` for the full procedure.

Summary:
1. Fetch review comments (both review-level and inline)
2. **Invoke `superpowers:receiving-code-review`** — evaluate feedback technically, don't blindly agree
3. Implement fixes with focused commits
4. **Invoke `superpowers:verification-before-completion`** — verify changes
5. Push directly to the PR branch: `git push origin <branch>`
6. Comment on PR summarizing what was addressed

This cycle repeats if the reviewer requests more changes.

## Flow Deviations

| Situation | Detection | Action |
|-----------|-----------|--------|
| PR closed without merge | `gh pr view` state=CLOSED | Report; offer reopen, new PR, or abandon |
| Multi-PR issue | Large scope detected in ASSESS | Break into sub-tasks; each gets own branch/PR. Branch naming: `type/42-slug-part-1` |
| Blocked | User says blocked or unresolvable dep | Note blocker, suggest exiting. On resume: ask if resolved |
| Merge conflicts | Push rejected or PR shows conflicts | Rebase onto default branch; use `--force-with-lease` after resolution |
| CI failure after PR | `gh pr checks` shows failures | Re-enter IMPLEMENT with CI context; fix, push, monitor |
| Issue already closed | `gh issue view` state=CLOSED | Check for merged PR. If found, report done. If not, ask user |

## Conventions Quick Reference

See `references/conventions.md` for full details.

- **Commits:** `type(scope): :emoji: description` — signed with `-S`
- **No AI attribution:** never add Co-Authored-By, Signed-off-by, or any mention of Claude/Anthropic/AI in commits, PR bodies, or issue comments
- **Branches:** `type/issue-number-slug` (e.g., `feat/42-add-jwt-auth`)
- **PR body:** Must include `Closes #<issue-number>`
- **Atomic commits:** One logical change per commit
