---
name: hack
description: Use when working on a quick hack task, checking hack status, resuming interrupted hack work, addressing PR review feedback, or cleaning up after a merged hack PR. Also trigger when the user wants to create an isolated worktree for a quick task.
---

# Hack Workflow

State-machine orchestrator for quick hack tasks. Uses the `hack` CLI for all mechanical operations (worktree creation, state management, push+PR, cleanup). AI handles only judgment work — implementation, review evaluation.

All work happens in an isolated git worktree. Never implement in the main working tree.

## Worktree Anchoring

**Before every action**, verify working directory:

```bash
hack validate-cwd <slug>
```

If `valid` is false, run the `fix` command. **Repeat after invoking any sub-skill** (verification, receiving-code-review).

## Entry Point

### 1. Audit active worktrees

```bash
hack audit
```

Report any active worktrees. Flag `done` worktrees for cleanup.

### 2. If no description provided — list active hacks

Present any active worktrees from audit. If none, ask user for a description.

### 3. Detect state

```bash
hack status <slug>
```

Route on `workflow_step`. If `workflow_step` is null (v1 migration), fall back to `state`.

## State Routing

| `workflow_step` | Action |
|----------------|--------|
| (no worktree) | `hack setup "<description>"`, proceed to implement |
| `implement` | Code the solution in the worktree |
| `verify` | Invoke `superpowers:verification-before-completion` |
| `push` | `hack push <slug>` |
| `review_dev` | Suggest `/review-dev`, handle findings |
| `review_security` | Suggest `/review-security`, handle findings |
| `waiting` | Re-check status for PR state changes |
| `revamp` | Address review feedback, verify, push |
| `done` | `hack cleanup <slug>` |
| `closed` | Report to user, offer options |

## Step Details

### Setup (no worktree)

```bash
hack setup "<description>"
```

Parse JSON response for `worktree` and `branch`. Change into worktree:

```bash
cd <worktree>
```

Proceed to implement (setup already sets `workflow_step: "implement"`).

### Implement

Execute implementation inside the worktree. The user has described the task — implement it directly. No assess/design/plan phases needed. If the task is complex, the user can invoke brainstorming/planning skills manually.

Follow commit conventions:
- Format: `type(scope): description`
- Sign with `-S`, no Co-Authored-By
- Atomic commits — one logical change per commit

When implementation is believed complete:

```bash
hack transition <slug> verify
```

### Verify

**Invoke `superpowers:verification-before-completion`.** After invoking, validate-cwd.

Run the project's test suite, linters, and build.

- If verification fails: `hack transition <slug> implement` (loop back)
- If verification passes: `hack transition <slug> push`

### Push

```bash
hack push <slug>
```

Report `pr_url` and `ci_status` from response. Then:

```bash
hack transition <slug> review_dev
```

### Review (Dev)

Suggest running `/review-dev` on the PR:

```
"PR created: <pr_url>
Recommend running /review-dev to catch issues before merge."
```

After dev review runs, parse the summary line if present:
- `REVIEW_DEV_SUMMARY: verdict=block` or `verdict=fix`: implement fixes, verify, push
- `verdict=clean`: transition to next step
- No summary line (backward compat): ask user if there are findings to address

If findings addressed (or user declines review):

```bash
hack transition <slug> review_security
```

### Review (Security)

Suggest running `/review-security`:

```
"Dev review complete.
Recommend running /review-security for a security audit before merge."
```

Same summary parsing pattern:
- `REVIEW_SECURITY_SUMMARY: verdict=block` or `verdict=fix`: implement fixes, verify, push
- `verdict=clean`: transition
- No summary line: ask user

After all fixes (or user declines):

```bash
hack transition <slug> waiting
```

### Waiting

Re-check status:

```bash
hack status <slug>
```

Reconciliation auto-detects:
- PR merged -> advances to `done`
- Changes requested -> advances to `revamp`
- PR closed -> advances to `closed`

If still waiting, report current state.

### Revamp

1. Evaluate review feedback technically (don't blindly agree)
2. Implement fixes with focused commits
3. **Invoke `superpowers:verification-before-completion`**
4. Push: `hack push <slug>`

Then:

```bash
hack transition <slug> verify --detail-json '{"revamp_round": <round+1>}'
```

### Done (Cleanup)

```bash
hack cleanup <slug>
```

Removes worktree, deletes branches.

### Closed

PR closed without merge. Report to user. Offer: reopen PR, create new PR, or abandon.

## Interruption Recovery

The skill reads `workflow_step` from `status` and picks up where it left off. The `status` command reconciles state with git/PR signals automatically.

## Conventions

### Commit Format

Format: `<type>(<scope>): <description>`

Rules:
- Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert
- Scope (REQUIRED): lowercase, kebab-case module name
- Description: imperative mood, lowercase start, no period
- Sign commits: always use `-S` flag
- Do NOT add Co-Authored-By lines

### PR Body Format

When creating a PR, the `hack push` command auto-generates:

```
## Summary
<commit log entries>
```
