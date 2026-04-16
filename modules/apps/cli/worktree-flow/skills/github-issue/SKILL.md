---
name: github-issue
description: Use when working on a GitHub issue (by number or URL), checking issue
  work status, resuming interrupted issue work, addressing PR review feedback, or
  cleaning up after a merged PR. Also trigger when the user mentions an issue number
  in the context of implementation work, or asks about the status of ongoing issue work.
---

# GitHub Issue Workflow

State-machine orchestrator for the full GitHub issue lifecycle. Uses the `github-issue` CLI for all mechanical operations (worktree creation, state management, push+PR, cleanup). AI handles only judgment work — classification, design, implementation, review evaluation.

All work happens in an isolated git worktree. Never implement in the main working tree.

## Worktree Anchoring

**Before every action**, verify working directory:

```bash
github-issue validate-cwd <number>
```

If `valid` is false, run the `fix` command. **Repeat after invoking any sub-skill** (brainstorming, writing-plans, executing-plans, verification, receiving-code-review).

## Entry Point

### 1. Audit active worktrees

```bash
github-issue audit
```

Report any active worktrees. Flag `done` worktrees for cleanup.

### 2. If no issue number provided — list open issues

```bash
gh issue list --state open --limit 20 --json number,title,labels
```

Present the list. Let the user pick one.

### 3. Detect state

```bash
github-issue status <number>
```

Route on `workflow_step`. If `workflow_step` is null (v1 migration), fall back to `state`.

## State Routing

| `workflow_step` | Action |
|----------------|--------|
| (no worktree) | `github-issue setup <N>`, proceed to assess |
| `assess` | Read issue body, classify complexity, transition |
| `design` | Invoke `superpowers:brainstorming`. Gate on approval |
| `plan` | Invoke `superpowers:writing-plans` |
| `implement` | Code the solution in the worktree |
| `verify` | Invoke `superpowers:verification-before-completion` |
| `push` | `github-issue push <N>` |
| `review_dev` | Suggest `/review-dev`, handle findings |
| `review_security` | Suggest `/review-security`, handle findings |
| `waiting` | Re-check status for PR state changes |
| `revamp` | `github-issue review-feedback <N>`, evaluate, fix |
| `done` | `github-issue cleanup <N>` |
| `closed` | Report to user, offer options |

## Step Details

### Setup (no worktree)

```bash
github-issue setup <number>
```

Parse JSON response for `worktree` and `branch`. Change into worktree:

```bash
cd <worktree>
```

Proceed to assess (setup already sets `workflow_step: "assess"`).

### Assess

Read the issue body (available in `status` response as `issue_body`). Classify complexity:

| Complexity | Criteria | Transition target |
|------------|----------|-------------------|
| trivial | One-file fix, clear problem | `implement` |
| standard | Multi-file, clear requirements | `plan` |
| complex | Unclear requirements, design needed | `design` |

**Auto-classification:** If the issue body contains implementation guidance — file paths (e.g., `src/foo/bar.ts`), code blocks with snippets, or explicit acceptance criteria / step-by-step instructions — auto-classify at the appropriate level and skip user confirmation:

```
"Auto-classified as <level> (detailed implementation guidance present). Proceeding to <target>."
```

If the issue body is vague or lacks implementation signals, present the assessment and let the user confirm or override as before.

Then transition:

```bash
github-issue transition <N> <target> --detail-json '{"complexity":"<level>"}'
```

### Design

**Invoke `superpowers:brainstorming`.** After invoking, validate-cwd.

Hard gate — do not proceed until design is approved. Then:

```bash
github-issue transition <N> plan
```

### Plan

**Invoke `superpowers:writing-plans`.** After invoking, validate-cwd.

Input: issue body + design (if design ran). Output: implementation plan. Then:

```bash
github-issue transition <N> implement --detail-json '{"plan_file":"PLAN.md"}'
```

### Implement

Execute implementation inside the worktree.

- If a plan exists: **invoke `superpowers:subagent-driven-development`** (independent tasks) or **`superpowers:executing-plans`** (sequential tasks)
- If trivial (no plan): implement directly

Follow commit conventions from `references/conventions.md`:
- Format: `type(scope): description`
- Sign with `-S`, no Co-Authored-By
- Atomic commits — one logical change per commit

When implementation is believed complete:

```bash
github-issue transition <N> verify
```

### Verify

**Invoke `superpowers:verification-before-completion`.** After invoking, validate-cwd.

Run the project's test suite, linters, and build.

- If verification fails: `github-issue transition <N> implement` (loop back)
- If verification passes and `workflow_detail.complexity == "trivial"`: proceed to push, then skip reviews (see **Trivial fast-path** below)
- If verification passes (non-trivial): `github-issue transition <N> push`

**Trivial fast-path:** When complexity is trivial, after verification passes, push and transition directly to waiting — skipping both review steps:

```bash
github-issue transition <N> push
```

Then after push completes:

```
"Trivial change — skipping reviews, proceeding directly to waiting."
```

```bash
github-issue transition <N> waiting
```

### Push

```bash
github-issue push <number>
```

Report `pr_url` and `ci_status` from response. Then:

- If trivial fast-path: `github-issue transition <N> waiting` (reviews already skipped above)
- Otherwise: `github-issue transition <N> review_dev`

### Review (Dev)

Suggest running `/review-dev` on the PR:

```
"PR created: <pr_url>
Recommend running /review-dev to catch issues before merge."
```

After dev review runs, parse the summary line if present:
- `REVIEW_DEV_SUMMARY: verdict=block`: critical issue — fix the blocker, verify, push before continuing
- `REVIEW_DEV_SUMMARY: verdict=fix`: batch all findings in a single pass (see **Batching** below)
- `verdict=clean`: transition to next step
- No summary line (backward compat): ask user if there are findings to address

**Batching minor fixes:** When verdict is `fix`, collect ALL findings from the review. Fix them all in one pass, then run a single verify-push cycle instead of cycling per finding. Log: "Batched N minor fixes into a single commit."

After all fixes (or user declines review):

```bash
github-issue transition <N> review_security
```

### Review (Security)

**UI-only skip:** Before suggesting `/review-security`, check the diff profile:

```bash
git diff <default-branch>..HEAD --name-only
```

If the diff touches **only** UI files (Composables, layout XML, string resources, theme files, icons) with **no** new dependencies, network calls, file I/O, user input handling, or permission changes — auto-skip the security review:

```
"Security review skipped — UI-only changes with no security surface."
```

The user can force a security review by explicitly requesting it.

**Otherwise**, suggest running `/review-security`:

```
"Dev review complete.
Recommend running /review-security for a security audit before merge."
```

After security review runs, parse the summary line if present:
- `REVIEW_SECURITY_SUMMARY: verdict=block`: critical issue — fix the blocker, verify, push before continuing
- `REVIEW_SECURITY_SUMMARY: verdict=fix`: batch all findings in a single pass — fix everything, then one verify-push cycle. Log: "Batched N minor fixes into a single commit."
- `verdict=clean`: transition
- No summary line (backward compat): ask user if there are findings to address

After all fixes (or user declines):

```bash
github-issue transition <N> waiting
```

### Waiting

Re-check status:

```bash
github-issue status <N>
```

Reconciliation auto-detects:
- PR merged -> advances to `done`
- Changes requested -> advances to `revamp`
- PR closed -> advances to `closed`

If still waiting, report current state and CI status:

```bash
github-issue check-ci <N>
```

### Revamp

Fetch review feedback:

```bash
github-issue review-feedback <N>
```

1. **Invoke `superpowers:receiving-code-review`** — evaluate feedback technically, don't blindly agree
2. Implement fixes with focused commits
3. **Invoke `superpowers:verification-before-completion`** — verify changes
4. Push: `github-issue push <N>`
5. Comment on PR summarizing what was addressed

Then:

```bash
github-issue transition <N> verify --detail-json '{"revamp_round": <round+1>}'
```

This cycle repeats if reviewer requests more changes.

### Done (Cleanup)

```bash
github-issue cleanup <number>
```

Removes worktree, deletes branches, closes issue.

### Closed

PR closed without merge. Report to user. Offer: reopen PR, create new PR, or abandon.

## Interruption Recovery

The skill reads `workflow_step` from `status` and picks up where it left off. The `status` command reconciles state with git/PR signals automatically:

| Situation | Auto-reconciliation |
|-----------|-------------------|
| Step says `plan` but commits exist | Advances to `implement` |
| Step says `push` but PR exists | Advances to `review_dev` |
| Step says `waiting` but PR merged | Advances to `done` |
| Step says `waiting` but changes requested | Advances to `revamp` |

No manual recovery needed — just re-invoke the skill.

## Flow Deviations

| Situation | Detection | Action |
|-----------|-----------|--------|
| PR closed without merge | `status` returns `closed` | Report; offer reopen, new PR, or abandon |
| Multi-PR issue | Large scope in assess | Break into sub-tasks; each gets own branch/PR |
| Blocked | User says blocked | Note blocker, suggest exiting. On resume: ask if resolved |
| Merge conflicts | Push rejected | Rebase onto default branch; use `--force-with-lease` |
| CI failure after PR | `check-ci` shows failures | Re-enter implement with CI context; fix, push |
| Issue already closed | `gh issue view` state=CLOSED | Check for merged PR. If found, report done |

## Conventions Quick Reference

See `references/conventions.md` for full details.

- **Commits:** `type(scope): description` — signed with `-S`
- **No AI attribution:** never add Co-Authored-By, Signed-off-by, or any mention of Claude/Anthropic/AI in commits, PR bodies, or issue comments
- **Branches:** `type/issue-number-slug` (e.g., `feat/42-add-jwt-auth`)
- **PR body:** Must include `Closes #<issue-number>`
- **Atomic commits:** One logical change per commit
