---
name: github-issue
description: Use when working on a GitHub issue (by number or URL), checking issue
  work status, resuming interrupted issue work, addressing PR review feedback, or
  cleaning up after a merged PR. Also trigger when the user mentions an issue number
  in the context of implementation work, or asks about the status of ongoing issue work.
---

# GitHub Issue Workflow

State-machine orchestrator for the full GitHub issue lifecycle. Uses the `github-issue` CLI for mechanical operations (worktree creation pinned to main, state management, pre-push rebase, push+PR+label-propagation, auto-merge, cleanup). AI handles only judgment work — classification, design, implementation, review evaluation, conflict resolution.

All work happens in an isolated git worktree. Never implement in the main working tree.

## Branching Rules

- **Base is always `origin/main`** (or the repo's default branch). The CLI pins the branch to this base at `setup` time; the worktree does not inherit from current HEAD. A SessionStart `git-sync` hook keeps local main fresh.
- **No stacking.** Do not branch off another in-progress branch. If issue B depends on issue A, wait for A to merge, then start B.
- `setup` accepts `--base <ref>` for explicit override. Do not use this unless the user asked for stacking.

## Worktree Anchoring

The skill uses the `EnterWorktree` tool to persist cwd at the session level, so every subsequent Bash call runs inside the worktree without needing a `cd <worktree> &&` prefix. This is set up once during **Setup** and holds across sub-skill invocations.

**Fallback check** — if a sub-skill (brainstorming, writing-plans, executing-plans, verification, receiving-code-review) appears to have disturbed cwd, re-verify:

```bash
github-issue validate-cwd <number>
```

If `valid` is false, call `EnterWorktree` with `path: <worktree-path>` to re-anchor, or run the `fix` command as a last resort.

## Multi-Agent Awareness

The skill assumes parallel sessions running on the same machine, each in its own worktree, each on a different issue. Four hot spots fall out of that topology:

- **One session per worktree.** Before resuming an existing worktree, read `step_history[-1].completed_at` from the `status` response. If it's < 5 minutes old and the last `note` reads as work-in-progress (no completion phrasing like "verified", "pushed", "all green"), ask the user before continuing — another live session may be mid-step.
- **Stale `origin/main` mid-session.** The CLI fetches inside `setup` and `push`, but `status` does not. On long-running sessions, treat PR/CI fields in a `status` response as potentially stale and re-run `status` (or `gh pr view`) before significant decisions: leaving `waiting`, leaving `audit`, deciding to push.
- **`push` rejection without a rebase conflict.** A non-zero exit from `github-issue push` that is *not* a rebase-conflict error means `--force-with-lease` rejected — the remote branch moved since this session last pushed. Do NOT retry. Run `git fetch origin <branch>`, inspect what landed, and escalate to the user.
- **Merge-order coordination.** When `audit` returns a non-empty `merge_order`, surface gating PRs before the user picks an issue (see Entry Point §1).

## Transition notes

Every `github-issue transition` **requires** `--note '<short summary>'`. The note is persisted in `step_history` and becomes the breadcrumb the next agent (or you, resuming tomorrow) reads to pick up context. Write a one-sentence note covering *what happened this step and any loose threads*.

Open threads the agent knows about but hasn't resolved (e.g., intermittent test failure, questionable assumption, TODO in a file) go into `workflow_detail.open_threads` via:

```bash
github-issue transition <N> <step> --note "..." --detail-json '{"open_threads": ["verify intermittent failure in src/foo.test.ts:142"]}'
```

## Entry Point

### 1. If no issue number provided — audit active work

```bash
github-issue audit
```

Returns `{worktrees, overlaps, merge_order}`:
- `worktrees`: list of active issue worktrees with step, PR, base_ref, blockers, touched_files.
- `overlaps`: pairs of worktrees sharing touched files — surfaces merge-conflict risk ahead of time.
- `merge_order`: mergeable PRs ordered by blocker graph (issues that unblock others merge first).

If `merge_order` is non-empty, surface it before listing open issues — the first entry is the next PR to push or merge. If the user's intended issue appears in another entry's `blocks` list, recommend handling the gating issue first.

Then list open issues so the user can pick one:

```bash
gh issue list --state open --limit 20 --json number,title,labels
```

### 2. If an issue number is provided — skip audit, go straight to status

```bash
github-issue status <number>
```

`audit` is fleet-survey; it is unnecessary overhead when you already know which issue you're touching.

### 3. Detect state and route

Route on `workflow_step`.

**If a worktree already exists**, anchor the session to it immediately using the `EnterWorktree` tool with `path: <worktree>` from the status response. All subsequent Bash calls will then run inside the worktree.

## State Routing

| `workflow_step` | Action |
|----------------|--------|
| (no worktree) | `github-issue setup <N>`, proceed to assess |
| `assess` | Read issue body, classify complexity, transition |
| `design` | Invoke `superpowers:brainstorming`. Gate on approval |
| `plan` | Invoke `superpowers:writing-plans` |
| `implement` | Code the solution in the worktree |
| `verify` | Invoke `superpowers:verification-before-completion` |
| `push` | `github-issue push <N>` (rebases silently, creates PR, propagates labels) |
| `review_dev` | Invoke `/review-dev` via Skill tool, handle findings; on clean auto-chain to `review_security` |
| `review_security` | Invoke `/review-security` via Skill tool, handle findings. On clean: `github-issue auto-merge <N>`, transition to `waiting` |
| `waiting` | Re-check status; on `mergeable: BEHIND` re-run `github-issue push <N>` to refresh the rebase |
| `revamp` | Review feedback received — `github-issue review-feedback <N>`, evaluate, fix |
| `ci_fix` | Post-push CI failure — diagnose from `check-ci`, fix, re-verify, push |
| `done` | `github-issue cleanup <N>` |
| `closed` | `github-issue post-mortem <N>`, draft comment on issue, offer options |

## Step Details

### Setup (no worktree)

```bash
github-issue setup <number>
```

Parse JSON response for `worktree`, `branch`, `base_ref`, and `blockers`. If any blocker is `OPEN`, surface it to the user — with the no-stacks rule, open blockers mean this issue probably shouldn't be started yet.

Switch the session into the worktree using the `EnterWorktree` tool with `path: <worktree>`.

Proceed to assess (setup already sets `workflow_step: "assess"`).

### Assess

Read the issue body (available in `status` response as `issue_body`). Classify complexity:

| Complexity | Criteria | Transition target |
|------------|----------|-------------------|
| trivial | One-file fix, clear problem | `implement` |
| standard | Multi-file, clear requirements | `plan` |
| complex | Unclear requirements, design needed | `design` |

**Auto-classification without user confirmation** — only when ALL THREE signals are present in the issue body:

1. **Prescriptive file paths** — "modify `src/auth/jwt.ts`", "add handler in `src/api/routes.ts`". Stack-trace locations (`at src/foo.ts:42`) do NOT count; they describe bug sites, not work sites.
2. **Prescriptive code** — snippets showing what to write (diff syntax, "change X to Y" phrasing, target structure). Exception traces, error output, or symptom dumps do NOT count.
3. **Explicit acceptance criteria or step-by-step instructions** — a checklist (`- [ ]`), a numbered procedure, or an "Acceptance Criteria" section.

If any of the three is absent, present the assessment and ask the user to confirm or override.

Then transition:

```bash
github-issue transition <N> <target> \
  --note "Classified as <level> — <reason>" \
  --detail-json '{"complexity":"<level>"}'
```

### Design

**Invoke `superpowers:brainstorming`.** After invoking, validate-cwd.

Hard gate — do not proceed until design is approved. Then:

```bash
github-issue transition <N> plan --note "Design approved: <one-sentence summary>"
```

### Plan

**Invoke `superpowers:writing-plans`.** After invoking, validate-cwd.

Input: issue body + design (if design ran). Output: implementation plan. Then:

```bash
github-issue transition <N> implement \
  --note "Plan written with <N> tasks covering <scope>" \
  --detail-json '{"plan_file":"PLAN.md"}'
```

### Implement

Execute implementation inside the worktree.

- If a plan exists: **invoke `superpowers:subagent-driven-development`** (independent tasks) or **`superpowers:executing-plans`** (sequential tasks)
- If trivial (no plan): implement directly

**Commit style on issue branches.** The branch is squash-merged, so the final commit on main is built from the PR title + body. Internal branch commits do not need to be atomic or follow a strict format — commit whenever it's natural. Do NOT add Co-Authored-By, Signed-off-by, or any AI attribution trailer. See `references/conventions.md`.

When implementation is believed complete:

```bash
github-issue transition <N> verify --note "<what got done + any open threads>"
```

### Verify

**Invoke `superpowers:verification-before-completion`.** After invoking, validate-cwd.

Run the project's test suite, linters, and build.

- If verification fails: `github-issue transition <N> implement --note "verify failed: <which suite / what error> — returning to implement"`
- If verification passes: `github-issue transition <N> push --note "All checks green: <suites run>"`

Every PR walks the full review gate. There is no trivial fast-path.

### Push

```bash
github-issue push <number>
```

Mechanics handled by the CLI:
- Silent pre-push rebase onto `base_ref` (origin/main by default). If the rebase conflicts, the CLI fails with a clear escalation message — see **Merge Conflict Resolution** below.
- Push; `--force-with-lease` if rebase rewrote history (never `--force`).
- Create PR if one doesn't exist; update otherwise.
- Propagate issue labels onto the PR.

If `push` exits non-zero **without** a rebase-conflict message, the `--force-with-lease` check failed — another session pushed to this branch since this session's last push. Do NOT retry. Run `git fetch origin <branch>` to see what landed and escalate to the user.

Report `pr_url` and `ci_status` from response. Then:

```bash
github-issue transition <N> review_dev --note "PR created: <url>"
```

### Review (Dev)

Invoke `/review-dev` directly via the `Skill` tool. Announce: `"PR created: <pr_url>. Running /review-dev."`

After dev review completes, parse the summary line:
- `REVIEW_DEV_SUMMARY: verdict=block`: critical issue — fix the blocker, verify, push before continuing
- `REVIEW_DEV_SUMMARY: verdict=fix`: batch all findings in a single pass. Fix them all, then one verify-push cycle. Log: "Batched N minor fixes."
- `verdict=clean`: transition and **immediately auto-chain into `/review-security`** — the diff is unchanged, so security review runs against the same state in the same turn
- No summary line: ask user if there are findings to address

After all fixes (or clean):

```bash
github-issue transition <N> review_security --note "Dev review: <verdict> — <brief>"
```

### Review (Security)

Invoke `/review-security` directly via the `Skill` tool. Announce: `"Running /review-security."`

Security review runs for every PR — there is no UI-only skip path. Small PRs still go through it; it's fast and catches the things that verification alone can't (new dependencies, sketchy patterns, credential leaks).

After security review completes, parse the summary:
- `REVIEW_SECURITY_SUMMARY: verdict=block`: fix the blocker, verify, push
- `REVIEW_SECURITY_SUMMARY: verdict=fix`: batch all findings, then one verify-push cycle
- `verdict=clean`: enable auto-merge and transition to waiting

After fixes are clean:

```bash
github-issue auto-merge <N>
github-issue transition <N> waiting --note "Security review: clean. Auto-merge enabled."
```

GitHub will merge the moment branch protection and required checks are satisfied. Reconciliation detects the merge and routes to `done`.

### Waiting

Re-check status:

```bash
github-issue status <N>
```

Reconciliation auto-detects:
- PR merged → advances to `done`
- Changes requested → advances to `revamp`
- CI failure on open PR → advances to `ci_fix`
- PR closed without merge → advances to `closed`

**Not auto-reconciled — `mergeable: BEHIND`.** When another PR lands in main while this one sits in `waiting`, auto-merge can stall behind the new base. The CLI doesn't fetch in `status` and doesn't reconcile this. Check manually:

```bash
gh pr view <N> --json mergeStateStatus,mergeable
```

If `mergeStateStatus` is `BEHIND` for more than one reconciliation cycle, re-run `github-issue push <N>` — the pre-push rebase will fetch and rebase onto the new main, and the force-with-lease push refreshes the PR so GitHub re-evaluates auto-merge.

If still waiting, report current state and CI status:

```bash
github-issue check-ci <N>
```

### Revamp (review feedback)

Fetch review feedback:

```bash
github-issue review-feedback <N>
```

1. **Invoke `superpowers:receiving-code-review`** — evaluate feedback technically, don't blindly agree
2. Implement fixes
3. **Invoke `superpowers:verification-before-completion`** — verify changes
4. Push: `github-issue push <N>`
5. Comment on PR summarizing what was addressed

Then:

```bash
github-issue transition <N> verify \
  --note "Addressed <N> review comments — <brief>" \
  --detail-json '{"revamp_round": <round+1>}'
```

This cycle repeats if the reviewer requests more changes.

### CI Fix (post-push CI failure)

Distinct from revamp — this is diagnosing a failing CI check after push, not addressing reviewer comments. Do NOT invoke `receiving-code-review`.

1. `github-issue check-ci <N>` — structured failure output with `detailsUrl`s
2. Fetch failing job logs for details (`gh run view <run-id> --log-failed`)
3. Fix the failure directly
4. Re-verify locally
5. Push: `github-issue push <N>`

Then:

```bash
github-issue transition <N> verify --note "Fixed CI failure: <which check> — <root cause>"
```

### Merge Conflict Resolution

When the pre-push rebase conflicts, the CLI aborts the rebase and returns an error. The agent (you) attempts resolution with strict guardrails.

**Hard-escalate signals — DO NOT attempt resolution, hand off to the user immediately if any are true:**

1. **Conflict touches file types that can't be hand-resolved safely:**
   - Lockfiles: `*.lock`, `package-lock.json`, `yarn.lock`, `flake.lock`, `Cargo.lock`, `poetry.lock`
   - Migrations: `**/migrations/**`, `**/db/migrate/**`
   - Generated code: files with `generated` / `DO NOT EDIT` headers
2. **A test file AND its corresponding source file both have conflicts** (semantic divergence risk — tests on both sides may have drifted).

**Resolution procedure (single attempt, no retry loops):**

1. Re-run the rebase manually: `git -C <worktree> rebase <base_ref>`
2. **Run `mergiraf solve <file>` on each unmerged path first.** Mergiraf is registered globally as a merge driver and has already had one pass during the rebase; running `solve` retries syntactic resolution on a single file and often clears markers without manual work. Re-stage anything it fully resolves. The markers that survive `solve` are real semantic divergence.
3. Inspect remaining conflict markers. Resolve each hunk. Use clear judgment — if both sides semantically changed the same logic, escalate.
4. Stage the resolved files: `git add <files>`
5. Continue the rebase: `git rebase --continue`
6. **Mandatory post-resolve verification** — run the project's full test + build + lint suite.
7. If verification passes → push.
8. If verification fails → `git rebase --abort`, escalate to user with:
   - List of conflicting files
   - Which side each hunk came from (ours/theirs)
   - What the resolution attempted
   - Why verification failed
   - Command to resume: `cd <worktree> && git rebase <base_ref>`

**No retry on failure.** One attempt, then escalate. Mergiraf has already exhausted the automated path; trying again on the same unedited state won't change anything. If the first resolution didn't pass verification, the divergence is semantic and needs human judgment.

### Done (Cleanup)

```bash
github-issue cleanup <number>
```

Removes worktree and deletes the local + remote branch. Does **not** force-close the issue — that's driven by the PR body's closing keyword (`Closes #N` / `Fixes #N` / `Resolves #N`). If the keyword was present, GitHub closed the issue when the PR merged. If the PR used `Refs #N` (multi-phase or umbrella issues that should stay open after this PR lands), the issue is left open. Cleanup reports the resulting state but never overrides it. Close manually with `gh issue close <number>` when all related work is complete.

### Closed

PR closed without merge. Gather context and draft a post-mortem comment.

```bash
github-issue post-mortem <N>
```

The response includes PR state, last reviews, inline comments, CI history, commit log, and recent step_history notes. Synthesize a short comment inferring why it was closed, then post to the issue:

```bash
gh issue comment <N> --body "$(cat <<'EOF'
## PR closed without merge

<PR link + close date>

**Inferred reason:** <one-paragraph synthesis>

**State at close:** <commits, CI, review status>

**Options:** reopen, new PR, abandon.
EOF
)"
```

Then offer the user the three options: reopen the PR, create a new one, or abandon.

## Interruption Recovery

The skill reads `workflow_step` and the most recent `step_history` notes to pick up where it left off. The `status` command reconciles state with git/PR signals automatically:

| Situation | Auto-reconciliation |
|-----------|-------------------|
| Step says `plan` but commits exist | Advances to `implement` |
| Step says `push` but PR exists | Advances to `review_dev` |
| Step says `waiting` but PR merged | Advances to `done` |
| Step says `waiting` but changes requested | Advances to `revamp` |
| Step says `waiting` but CI failing | Advances to `ci_fix` |
| Step says `waiting` but PR closed | Advances to `closed` |

No manual recovery needed — re-invoke the skill. The last few `step_history.note` fields plus `workflow_detail.open_threads` tell you what was in flight.

## Flow Deviations

| Situation | Detection | Action |
|-----------|-----------|--------|
| PR closed without merge | `status` returns `closed` | `post-mortem`, draft comment, offer reopen/new/abandon |
| Multi-PR issue | Large scope in assess | Break into sub-tasks; each gets own issue → branch → PR |
| Blocked | Open blocker found at setup, or user reports | Surface; with no-stacks rule, prefer to wait for blocker to merge |
| Merge conflicts | Pre-push rebase failed | Run the Merge Conflict Resolution procedure above |
| CI failure after PR | Reconciled to `ci_fix` | Distinct path from `revamp`; diagnose + fix, no code review skill |
| Issue already closed | `gh issue view` state=CLOSED | Check for merged PR. If found, report done |

## Conventions Quick Reference

See `references/conventions.md` for details.

- **Commits on issue branches:** freeform — branch is squash-merged. No Co-Authored-By, no AI attribution.
- **Squashed merge commit on main:** `type(scope): description` built by the skill from PR title + body.
- **Branches:** `type/issue-number-slug` (e.g., `feat/42-add-jwt-auth`) — CLI builds this from issue labels.
- **PR body:** Must reference the issue. Use `Closes #<issue-number>` (auto-close on merge) for atomic issues. For multi-phase or umbrella issues that should stay open after this PR lands, edit the body to use `Refs #<issue-number>` after `github-issue push` runs — the CLI defaults to `Closes` and does not auto-detect multi-phase scope.

## Known CLI Gaps

Behaviors this skill documents but the CLI does not yet enforce. The agent compensates in prompt-space.

- `status` does not `git fetch` before reading PR/CI fields — long-running sessions may see stale signals. Re-run before significant decisions.
- `push` exits opaquely on `--force-with-lease` rejection (`set -euo pipefail` kills the script without a structured error). Agent distinguishes lease failure from rebase conflict by reading the error text.
- No `session_id` / PID lock on `.worktree-state.json` — concurrent sessions in the same worktree can clobber state. Skill mitigates via `step_history[-1].completed_at` recency heuristic at resume time.
- `reconcile_state` does not detect `mergeStateStatus: BEHIND` from `waiting` — agent must check via `gh pr view` (see Waiting).
- `audit.merge_order` does not include PR mergeable/CI health — agent must `gh pr view` for any gating PR that may need a fresh push.
