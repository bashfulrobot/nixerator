---
name: github-issue
description: Use when working on a GitHub issue (by number or URL), checking issue
  work status, resuming interrupted issue work, addressing PR review feedback, or
  cleaning up after a merged PR. Also trigger when the user mentions an issue number
  in the context of implementation work, or asks about the status of ongoing issue work.
---

# GitHub Issue Workflow

State-machine orchestrator for the full GitHub issue lifecycle — from triage through PR merge. Uses the `github-issue` CLI for all mechanical operations (worktree creation, state detection, push+PR, cleanup) and focuses AI on decisions that need judgment.

All work happens in an isolated git worktree. Never implement directly in the main working tree.

## On Every Invocation

### 1. Audit active worktrees

```bash
github-issue audit
```

Report any active worktrees to the user. Flag `DONE` worktrees as ready for cleanup.

### 2. Detect state

```bash
github-issue status <number>
```

Route based on the `state` field in the JSON response.

## State Routing

| State | Action |
|-------|--------|
| `NEW` | Run Setup, then proceed to ASSESS |
| `ASSESS` | cd into worktree, classify issue complexity |
| `IMPLEMENT` | cd into worktree, continue implementation |
| `READY` | PR exists, awaiting review — report status |
| `REVAMP` | cd into worktree, address review feedback |
| `DONE` | PR merged — run Cleanup |
| `CLOSED` | PR closed without merge — report, offer reopen/new-PR/abandon |

## Setup (state: NEW)

```bash
github-issue setup <number>
```

Parse the JSON response to get `worktree` and `branch`. Change into the worktree directory:

```bash
cd <worktree>
```

Proceed to ASSESS.

## ASSESS

Read the issue body (from `github-issue status` output or `gh issue view`) and classify complexity:

| Complexity | Criteria | Next State |
|------------|----------|------------|
| trivial | One-file fix, clear problem | Skip to IMPLEMENT |
| standard | Multi-file, clear requirements | Skip to PLAN |
| complex | Unclear requirements, design needed | Proceed to DESIGN |

Present the assessment. Let the user confirm or override before proceeding.

## DESIGN

**Invoke `superpowers:brainstorming`.**

Hard gate — do not implement until the design is approved.

## PLAN

**Invoke `superpowers:writing-plans`.**

Input: issue body + design (if DESIGN ran). Output: implementation plan with discrete tasks.

## IMPLEMENT

Execute the implementation work inside the worktree.

- If a plan exists → **invoke `superpowers:subagent-driven-development`** (independent tasks) or **`superpowers:executing-plans`** (sequential tasks)
- If trivial (no plan) → implement directly

Follow commit conventions from `references/conventions.md`:
- Format: `type(scope): description`
- Sign with `-S`, no Co-Authored-By
- Atomic commits — one logical change per commit

## VERIFY

**Invoke `superpowers:verification-before-completion`.**

Run the project's test suite, linters, and build. If verification fails, loop back to IMPLEMENT. Do not skip ahead.

## READY

Implementation is verified. Push and create PR:

```bash
github-issue push <number>
```

The command pushes the branch and creates or updates the PR. Report the `pr_url` from the JSON response, then proceed to REVIEW.

## REVIEW

After a PR is created, always suggest running the review pipeline. This is a two-stage gate:

**Stage 1 — Dev Review:** Suggest running `/review-dev` on the PR.

```
"PR created: <pr_url>
Recommend running /review-dev to catch issues before merge."
```

If the dev review produces findings, implement fixes (focused commits), verify with `superpowers:verification-before-completion`, and push:

```bash
github-issue push <number>
```

Once all `/review-dev` fixes are complete, proceed to stage 2.

**Stage 2 — Security Review:** Suggest running `/review-security` on the PR.

```
"Dev review fixes complete and pushed.
Recommend running /review-security for a security audit before merge."
```

If the security review produces findings, implement fixes the same way.

**Both stages are always suggested.** The user may decline, but always recommend them in order.

## REVAMP

PR received "changes requested". Read `references/revamp-workflow.md` for the full procedure.

Summary:
1. Fetch review comments (both review-level and inline)
2. **Invoke `superpowers:receiving-code-review`** — evaluate feedback technically, don't blindly agree
3. Implement fixes with focused commits
4. **Invoke `superpowers:verification-before-completion`** — verify changes
5. Push updates:
   ```bash
   github-issue push <number>
   ```
6. Comment on PR summarizing what was addressed

This cycle repeats if the reviewer requests more changes.

## DONE (Cleanup)

```bash
github-issue cleanup <number>
```

Removes the worktree, deletes branches, and closes the issue.

## Flow Deviations

| Situation | Detection | Action |
|-----------|-----------|--------|
| PR closed without merge | `status` returns `CLOSED` | Report; offer reopen, new PR, or abandon |
| Multi-PR issue | Large scope in ASSESS | Break into sub-tasks; each gets own branch/PR |
| Blocked | User says blocked | Note blocker, suggest exiting. On resume: ask if resolved |
| Merge conflicts | Push rejected | Rebase onto default branch; use `--force-with-lease` |
| CI failure after PR | `gh pr checks` shows failures | Re-enter IMPLEMENT with CI context; fix, push |
| Issue already closed | `gh issue view` state=CLOSED | Check for merged PR. If found, report done |

## Conventions Quick Reference

See `references/conventions.md` for full details.

- **Commits:** `type(scope): description` — signed with `-S`
- **No AI attribution:** never add Co-Authored-By, Signed-off-by, or any mention of Claude/Anthropic/AI in commits, PR bodies, or issue comments
- **Branches:** `type/issue-number-slug` (e.g., `feat/42-add-jwt-auth`)
- **PR body:** Must include `Closes #<issue-number>`
- **Atomic commits:** One logical change per commit
