---
name: github-issue
description: Use when working on a GitHub issue (by number or URL), checking issue
  work status, resuming interrupted issue work, addressing PR review feedback, or
  cleaning up after a merged PR. Also trigger when the user mentions an issue number
  in the context of implementation work, or asks about the status of ongoing issue work.
---

# GitHub Issue Workflow

State-machine orchestrator for the full GitHub issue lifecycle. Uses the `github-issue` CLI for mechanical operations (worktree creation pinned to main, state management, pre-push rebase, push+PR+label-propagation, auto-merge, cleanup). AI handles only the judgment work: classification, design, implementation, review evaluation, conflict resolution.

All work happens in an isolated git worktree. Never implement in the main working tree.

> **GitHub only.** This skill's automation (CI-gated auto-merge, review-decision
> polling, merge-state orchestration) is specific to GitHub's PR model, so the
> `github-issue` CLI refuses to run on a non-GitHub remote. For an issue on the
> self-hosted Forgejo (`git.srvrs.co`), there is no equivalent automated
> lifecycle. Drive it by hand with the provider-aware `forge` helper
> (`forge issue-json <n>` to read the issue, branch and commit, then
> `forge pr-create <title> <body> <base> <head>`) plus the Forgejo UI or `tea`
> for review and merge. The `log-github-issue` skill is already provider-aware
> if you just need to file a Forgejo issue.

### Forgejo manual claim and release

The GitHub path claims the issue automatically at `setup` and releases it at
`cleanup`. There the authoritative claim is a per-agent claim comment, and the
winner is the claim comment with the lowest (monotonic, server-assigned) comment
id. The assignee only discriminates agents on GitHub, and even there our fleet
runs one login across every host, so the assignee is a hint, not the token.

On Forgejo it is weaker still. Every agent authenticates with the single shared
`FORGEJO_TOKEN`, so `forge whoami` returns one identity for all agents and the
assignee cannot tell two agents apart at all. The lease degrades to the
human-visible signals: the `in-progress` label, the claim comment, and
`fleet-status` as the reconciliation view. Treat a Forgejo claim as advisory and
confirm with a human before two agents touch the same issue.

**Before you branch (claim):**

```
forge issue-json <n>        # inspect .assignees and .labels first
```

If `.labels` already contains `in-progress`, or `.assignees` lists anyone, stop
and reconcile with `fleet-status`. Another agent likely holds it. The shared
login means you cannot distinguish "someone else" from "me on another host" by
assignee, so read the claim comments before deciding. Otherwise claim it:

```
forge issue-assign <n> @me                       # human-visible hint, not a CAS
forge issue-labels <n> in-progress               # create the label once if the repo lacks it
# Post the claim with each field line-anchored, matching what the GitHub path emits,
# so fleet-status can parse host/worktree/branch line by line and sort by comment id:
forge issue-comment <n> "$(printf 'Claimed for work.\n\n<!-- worktree-flow:claim -->\nclaim-id: %s\nhost: %s\nworktree: %s\nclaimed-at: %s\nbranch: %s' \
  "$(uname -n)::<worktree>::$(date -u +%FT%TZ)::$$" "$(uname -n)" "<worktree>" "$(date -u +%FT%TZ)" "<branch>")"
# Re-read and resolve the winner. Filter to the claim marker FIRST, then take the
# lowest id. The raw list also holds pre-claim human/triage comments (lower ids);
# a bare sort_by(.id) would pick one of those and make you cede by mistake.
forge issue-comments-json <n> | jq '[.[] | select(.body | contains("<!-- worktree-flow:claim -->"))] | sort_by(.id) | .[0]'
# Cede if that winner's claim-id is not the one you just posted.
```

**After the PR merges or you abandon the work (release):**

```
forge issue-unassign <n> @me                     # drop only your own assignee
forge issue-unlabel <n> in-progress              # only if no other assignee remains
forge issue-comment <n> "Lease released. host: $(uname -n), branch: <branch>, at: $(date -u +%FT%TZ)"
```

## Voice for posted content

Anything this skill writes that ends up on GitHub (a PR comment, a post-mortem
comment on a closed issue, the `Addressed review feedback` summary at the end
of a revamp round) must read like a developer wrote it. Not a tool announcing
what it did.

Before posting any agent-authored comment via `gh pr comment` or `gh issue
comment`, run the body through the [`text-polish`](../text-polish/SKILL.md) skill
and apply the full ruleset. Hard constraints that matter most for GitHub
content:

- **No em dashes (`—`) or en dashes (`–`)** in any posted comment. Use a
  comma, period, parentheses, or restructure the sentence.
- **No agent voice.** Strip "as an AI", "I will", "here's a summary of what I
  did", "let me know if". Write as the engineer who handled the work.
- **Use colons sparingly.** Only when introducing a list, a definition, or a
  label/value pair. Decorative colons that could be a comma or a period have
  to go.
- **No AI vocabulary.** Drop *crucial*, *seamless*, *robust*, *delve*,
  *leverage*, *underscore* unless the technical meaning is exact and
  unavoidable.
- **No "Generated by Claude", "Co-authored-by", or any AI attribution.**

The CLI-generated content (PR body built from commit log, automatic merge
commit message) isn't authored by this skill and isn't run through text-polish.
Anything you write by hand into a `gh pr comment` or `gh issue comment` call
is.

## Complete every outstanding item

When working an issue, fix everything you find broken on the way. Review
findings (Critical, Important, *and* Minor), TODOs you read while editing
adjacent code, pre-existing bugs that surface during implementation,
lint/format/test failures that aren't directly caused by your change, dead
imports, stale comments next to the lines you touched. All of it goes into
the same PR.

This expands scope intentionally. Do not file a follow-up issue, do not mark
items "out of scope", do not defer to "future work". The only reason to spin
out a separate issue is if a fix requires a genuinely large, independent
refactor that would dwarf the original change. Default to fixing it inline.

The principle from the project's global guidelines applies: **own every
problem**. If you can fix it in this PR, fix it in this PR.

## Branching Rules

- **Base is always `origin/main`** (or the repo's default branch). The CLI pins the branch to this base at `setup` time; the worktree does not inherit from current HEAD. A SessionStart `git-sync` hook keeps local main fresh.
- **No stacking.** Do not branch off another in-progress branch. If issue B depends on issue A, wait for A to merge, then start B.
- `setup` accepts `--base <ref>` for explicit override. Do not use this unless the user asked for stacking.

## Worktree Anchoring

The skill uses the `EnterWorktree` tool to persist cwd at the session level, so every subsequent Bash call runs inside the worktree without needing a `cd <worktree> &&` prefix. This is set up once during **Setup** and holds across sub-skill invocations.

**Fallback check.** If a sub-skill (brainstorming, writing-plans, executing-plans, verification, receiving-code-review) appears to have disturbed cwd, re-verify:

```bash
github-issue validate-cwd <number>
```

If `valid` is false, call `EnterWorktree` with `path: <worktree-path>` to re-anchor, or run the `fix` command as a last resort.

## Multi-Agent Awareness

The skill assumes parallel sessions running on the same machine, each in its own worktree, each on a different issue. The CLI provides the safety rails; the skill mostly just surfaces what comes back.

- **Single-writer locking.** Mutating commands acquire a `flock` before touching state. `push`, `transition`, `cleanup`, and `auto-merge` lock the per-worktree file; `setup` locks a base-directory file keyed on issue number (the worktree doesn't exist yet at that point). Contended invocations return a structured error with `cause: "worktree_locked"` or `cause: "setup_locked"`. Surface it; do not retry. Another agent owns this worktree right now.
- **Fresh refs.** `status` and `audit` run `git fetch origin --prune` before reading PR/CI signals, so long-running sessions don't see stale base or auto-merge state. `fetch_remote` warns and continues on failure; if you've reason to suspect the network is down (e.g., repeated `gh` failures), treat refs as best-effort.
- **Read-consistent status.** `status` tries to acquire the worktree lock before reconciling. If another mutating command is active, reconciliation is skipped and the response carries `reconciled: false`; the rest of the payload still reflects the last persisted state. Re-run when convenient.
- **Stale `waiting` PRs self-heal.** When `status` or `audit` sees a `waiting` PR with `mergeStateStatus == BEHIND` (another PR landed in main while this one was queued), the CLI rebases onto the new base and force-with-lease pushes to clear the staleness so GitHub re-evaluates auto-merge. Audit entries report `auto_refreshed: true` only when a rebase/push actually happened. The auto-refresh is best-effort and can fail for several reasons (rebase conflict, push rejected, lease lost, network/auth). When it fails, `pr.merge_state_status` stays `BEHIND`. Run `github-issue push <N>` to surface a structured error (`cause` distinguishes `rebase_conflict` from `lease_failed` / `push_failed`) and route from there.
- **Structured push errors.** `github-issue push` returns `{error: {cause, branch, ...}}` where `cause` is `rebase_conflict`, `lease_failed`, or `push_failed`. Route on `cause`; do not parse the message. `lease_failed` specifically means another session pushed to this branch; do NOT retry. Fetch and escalate.
- **Merge-order coordination.** When `audit` returns a non-empty `merge_order`, surface gating PRs before the user picks an issue. Each entry carries `ci_status` and `merge_state_status` so the skill can identify which gating PR is actually ready vs. waiting on CI (see Entry Point §1).

## Transition notes

Every `github-issue transition` **requires** `--note '<short summary>'`. The note is persisted in `step_history` and becomes the breadcrumb the next agent (or you, resuming tomorrow) reads to pick up context. Write a one-sentence note covering *what happened this step and any loose threads*.

Open threads the agent knows about but hasn't resolved (e.g., intermittent test failure, questionable assumption, TODO in a file) go into `workflow_detail.open_threads` via:

```bash
github-issue transition <N> <step> --note "..." --detail-json '{"open_threads": ["verify intermittent failure in src/foo.test.ts:142"]}'
```

## Entry Point

### 1. If no issue number provided, audit active work

```bash
github-issue audit
```

Returns `{worktrees, overlaps, merge_order}`:
- `worktrees`: list of active issue worktrees with step, PR, base_ref, ci_status, merge_state_status, auto_refreshed, blockers, touched_files. `auto_refreshed: true` means the CLI just rebased + force-pushed this worktree to clear a BEHIND state.
- `overlaps`: pairs of worktrees sharing touched files; surfaces merge-conflict risk ahead of time.
- `merge_order`: mergeable PRs ordered by blocker graph (issues that unblock others merge first). Each entry includes `ci_status` and `merge_state_status` so the skill can identify the next *actually-ready* PR.

If `merge_order` is non-empty, surface it before listing open issues. The first entry whose `ci_status == passing` and `merge_state_status` is not `BLOCKED`/`BEHIND` is the next PR to merge. If the user's intended issue appears in another entry's `blocks` list, recommend handling the gating issue first.

Then list open issues so the user can pick one:

```bash
gh issue list --state open --limit 20 --json number,title,labels
```

### 2. If an issue number is provided, skip audit and go straight to status

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
| `waiting` | Re-check status. CLI auto-fetches and auto-heals BEHIND. Only act manually if `pr.merge_state_status == BEHIND` persists across reconciliations (auto-refresh failed; run `github-issue push <N>` to surface a structured `error.cause`). |
| `revamp` | Review feedback received. Run `github-issue review-feedback <N>`, evaluate, fix. |
| `ci_fix` | Post-push CI failure. Diagnose from `check-ci`, fix, re-verify, push. |
| `done` | `github-issue cleanup <N>` |
| `closed` | `github-issue post-mortem <N>`, draft comment on issue, offer options |

## Step Details

### Setup (no worktree)

```bash
github-issue setup <number>
```

Parse JSON response for `worktree`, `branch`, `base_ref`, and `blockers`. If any blocker is `OPEN`, surface it to the user. With the no-stacks rule, open blockers mean this issue probably shouldn't be started yet.

Switch the session into the worktree using the `EnterWorktree` tool with `path: <worktree>`.

If `setup` returns an error object instead, route on `error.cause` (do not parse the message):
- `branch_exists`. This issue's branch already exists locally or on origin (`error.location` says which). Another agent may have started it, or a prior run left it behind. Do NOT auto-create a second worktree. If a different agent is actively working it, surface and stop. If the branch is yours and the worktree was lost (a manual `git worktree remove`, a partial cleanup, or picking the work up on another host), re-establish it with `github-issue resume <N>` (see Resume below).
- `branch_check_unreachable`. origin was unreachable, so the branch-existence check could not run and setup refused fail-closed rather than risk a duplicate. Surface it and retry once origin is reachable; do NOT force past it.
- `worktree_exists`. A worktree for this issue is already on disk. Run `github-issue status <N>` and resume from the recorded step rather than setting up again.
- `issue_claimed`. Another agent holds the issue lease. Surface; do not retry.
- `setup_locked`. Another `github-issue setup` for this issue is mid-flight on this machine. Surface; do not retry.
- `invalid_issue_number`. The argument was not numeric. Fix the call.

Proceed to assess (setup already sets `workflow_step: "assess"`).

### Resume (branch exists, worktree lost)

When an issue's branch and PR are still open on origin but the local worktree is gone, `github-issue resume <N>` re-adds it instead of refusing:

```bash
github-issue resume <number>
```

It re-attaches the worktree on the existing branch and prefers origin as the source of truth. It keeps any local-only commits and warns when the local branch is ahead of origin, so nothing is silently discarded. It links the open PR it finds via `gh pr list --head <branch>`, so the next `github-issue push` updates that PR rather than opening a second one. It takes the issue lease as a reentrant takeover for the resuming host, so a cross-host pickup is not refused with `issue_claimed`. Resume sets `workflow_step: "implement"` so you re-orient on the branch, then carry forward through verify and push as usual.

Switch the session into the worktree with the `EnterWorktree` tool (`path: <worktree>`), then continue from the recorded step.

Route on `error.cause`:
- `no_existing_branch`. Nothing to resume: the branch exists neither locally nor on origin. Use `github-issue setup <N>` to start fresh.
- `worktree_exists`. A worktree is already on disk. Run `github-issue status <N>` and resume from the recorded step.
- `branch_check_unreachable`. origin was unreachable, so resume refused fail-closed. Retry once origin is reachable.

### Assess

Read the issue body (available in `status` response as `issue_body`). Classify complexity:

| Complexity | Criteria | Transition target |
|------------|----------|-------------------|
| trivial | One-file fix, clear problem | `implement` |
| standard | Multi-file, clear requirements | `plan` |
| complex | Unclear requirements, design needed | `design` |

**Auto-classification without user confirmation.** Only when ALL THREE signals are present in the issue body:

1. **Prescriptive file paths.** "Modify `src/auth/jwt.ts`", "add handler in `src/api/routes.ts`". Stack-trace locations (`at src/foo.ts:42`) do NOT count; they describe bug sites, not work sites.
2. **Prescriptive code.** Snippets showing what to write (diff syntax, "change X to Y" phrasing, target structure). Exception traces, error output, or symptom dumps do NOT count.
3. **Explicit acceptance criteria or step-by-step instructions.** A checklist (`- [ ]`), a numbered procedure, or an "Acceptance Criteria" section.

If any of the three is absent, present the assessment and ask the user to confirm or override.

Then transition:

```bash
github-issue transition <N> <target> \
  --note "Classified as <level>. <reason>" \
  --detail-json '{"complexity":"<level>"}'
```

### Design

**Invoke `superpowers:brainstorming`.** After invoking, validate-cwd.

Hard gate. Do not proceed until design is approved. Then:

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

**Commit style on issue branches.** The branch is squash-merged, so the final commit on main is built from the PR title + body. Internal branch commits do not need to be atomic or follow a strict format. Commit whenever it's natural. Do NOT add Co-Authored-By, Signed-off-by, or any AI attribution trailer. See `references/conventions.md`.

When implementation is believed complete:

```bash
github-issue transition <N> verify --note "<what got done + any open threads>"
```

### Verify

**Invoke `superpowers:verification-before-completion`.** After invoking, validate-cwd.

Run the project's test suite, linters, and build.

- If verification fails: `github-issue transition <N> implement --note "verify failed (<which suite, what error>). Returning to implement."`
- If verification passes: `github-issue transition <N> push --note "All checks green: <suites run>"`

Every PR walks the full review gate. There is no trivial fast-path.

### Push

```bash
github-issue push <number>
```

Mechanics handled by the CLI:
- Silent pre-push rebase onto `base_ref` (origin/main by default). If the rebase conflicts, the CLI fails with a clear escalation message. See **Merge Conflict Resolution** below.
- Push; `--force-with-lease` if rebase rewrote history (never `--force`).
- Create PR if one doesn't exist; update otherwise.
- Propagate issue labels onto the PR.

If `push` returns an error object, route on `error.cause`:
- `rebase_conflict`. Agent enters **Merge Conflict Resolution** below.
- `lease_failed`. Another session pushed to this branch. Do NOT retry. Run `git fetch origin <branch>` to see what landed and escalate to the user.
- `push_failed`. Generic network/auth/hook failure. Inspect `error.stderr`.
- `protected_branch`. State file resolved the branch name to `main`/`master`. Should never happen on a well-formed state file; surface as data corruption.
- `worktree_locked` or `setup_locked`. Another `github-issue` process is mid-operation on this worktree (or this issue's setup). Surface; do not retry.

Report `pr_url` and `ci_status` from response. Then:

```bash
github-issue transition <N> review_dev --note "PR created: <url>"
```

### Review (Dev)

Invoke `/review-dev` directly via the `Skill` tool. Announce: `"PR created: <pr_url>. Running /review-dev."`

After dev review completes, parse the summary line:
- `REVIEW_DEV_SUMMARY: verdict=block`. Critical issue. Fix the blocker, plus
  every Important and Minor finding the same review surfaced. Verify and push
  before continuing.
- `REVIEW_DEV_SUMMARY: verdict=fix`. Batch every Critical, Important, **and**
  Minor finding in a single pass. No deferral, no follow-up issues, no "out of
  scope". Then one verify-push cycle. Log: "Batched N fixes."
- `verdict=clean`. Transition and **immediately auto-chain into
  `/review-security`**. The diff is unchanged, so security review runs against
  the same state in the same turn.
- No summary line. Ask the user if there are findings to address.

After all fixes (or clean):

```bash
github-issue transition <N> review_security --note "Dev review: <verdict>. <brief>"
```

### Review (Security)

Invoke `/review-security` directly via the `Skill` tool. Announce: `"Running /review-security."`

Security review runs for every PR. There is no UI-only skip path. Small PRs still go through it; it's fast and catches the things that verification alone can't (new dependencies, sketchy patterns, credential leaks).

After security review completes, parse the summary:
- `REVIEW_SECURITY_SUMMARY: verdict=block`. Fix the blocker plus every High,
  Medium, and Low finding the same review surfaced. Verify and push.
- `REVIEW_SECURITY_SUMMARY: verdict=fix`. Batch every Critical, High, Medium,
  and Low finding in one pass. No deferral. Then one verify-push cycle.
- `verdict=clean`. Enable auto-merge and transition to waiting.

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

**Auto-healed `mergeable: BEHIND`.** When another PR lands in main while this one sits in `waiting`, auto-merge can stall behind the new base. `status` and `audit` automatically attempt a fresh rebase + force-with-lease push to clear it; the new state is surfaced in `pr.merge_state_status`. If `pr.merge_state_status == BEHIND` *persists* after a `status` call, the auto-refresh failed. Most commonly a rebase conflict; also possible are push rejected by branch protection, lease lost to a concurrent push, or network/auth. Run `github-issue push <N>` to get a structured `error.cause` (`rebase_conflict` routes to **Merge Conflict Resolution** below; `lease_failed` is fetch + escalate; `push_failed` is inspect `error.stderr`).

If still waiting, report current state and CI status:

```bash
github-issue check-ci <N>
```

### Revamp (review feedback)

Fetch review feedback:

```bash
github-issue review-feedback <N>
```

1. **Invoke `superpowers:receiving-code-review`** to evaluate feedback technically. Don't blindly agree.
2. Implement fixes.
3. **Invoke `superpowers:verification-before-completion`** to verify changes.
4. Push: `github-issue push <N>`.
5. Comment on the PR summarizing what was addressed. Run the comment body
   through the [`text-polish`](../text-polish/SKILL.md) skill before calling
   `gh pr comment`. See [Voice for posted content](#voice-for-posted-content).

Then:

```bash
github-issue transition <N> verify \
  --note "Addressed <N> review comments. <brief>" \
  --detail-json '{"revamp_round": <round+1>}'
```

This cycle repeats if the reviewer requests more changes.

### CI Fix (post-push CI failure)

Distinct from revamp. This is diagnosing a failing CI check after push, not addressing reviewer comments. Do NOT invoke `receiving-code-review`.

1. `github-issue check-ci <N>`. Structured failure output with `detailsUrl`s.
2. Fetch failing job logs for details (`gh run view <run-id> --log-failed`)
3. Fix the failure directly
4. Re-verify locally
5. Push: `github-issue push <N>`

Then:

```bash
github-issue transition <N> verify --note "Fixed CI failure in <which check>. <root cause>"
```

### Merge Conflict Resolution

When the pre-push rebase conflicts, the CLI aborts the rebase and returns an error. The agent (you) attempts resolution with strict guardrails.

**Hard-escalate signals.** DO NOT attempt resolution; hand off to the user immediately if any are true:

1. **Conflict touches file types that can't be hand-resolved safely:**
   - Lockfiles: `*.lock`, `package-lock.json`, `yarn.lock`, `flake.lock`, `Cargo.lock`, `poetry.lock`
   - Migrations: `**/migrations/**`, `**/db/migrate/**`
   - Generated code: files with `generated` / `DO NOT EDIT` headers
2. **A test file AND its corresponding source file both have conflicts** (semantic divergence risk; tests on both sides may have drifted).

**Resolution procedure (single attempt, no retry loops):**

1. Re-run the rebase manually: `git -C <worktree> rebase <base_ref>`
2. **Run `mergiraf solve <file>` on each unmerged path first.** Mergiraf is registered globally as a merge driver and has already had one pass during the rebase; running `solve` retries syntactic resolution on a single file and often clears markers without manual work. Re-stage anything it fully resolves. The markers that survive `solve` are real semantic divergence.
3. Inspect remaining conflict markers. Resolve each hunk. Use clear judgment; if both sides semantically changed the same logic, escalate.
4. Stage the resolved files: `git add <files>`
5. Continue the rebase: `git rebase --continue`
6. **Mandatory post-resolve verification.** Run the project's full test + build + lint suite.
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

Removes worktree and deletes the local + remote branch. Does **not** force-close the issue; that's driven by the PR body's closing keyword (`Closes #N` / `Fixes #N` / `Resolves #N`). If the keyword was present, GitHub closed the issue when the PR merged. If the PR used `Refs #N` (multi-phase or umbrella issues that should stay open after this PR lands), the issue is left open. Cleanup reports the resulting state but never overrides it. Close manually with `gh issue close <number>` when all related work is complete.

### Verifying a merged PR actually landed

After cleanup, the GitHub UI may report a PR as merged even when its squash commit is unreachable from the default branch. The classic trigger is the stacked-PR squash race: a child PR (base = parent's feature branch) merged within seconds of the parent, before GitHub finished auto-retargeting the child's base to main. The squash gets the right diff but lands in an orphan commit.

```bash
github-issue verify-landed <PR-number>
```

Read-only. Exits 0 with `status: "landed"` when the PR's content is on origin's default branch; exits 1 with `status: "orphaned"` and a `recovery_hint` when it isn't. Returns `status: "not_merged"` (exit 0) when the PR is not in `MERGED` state.

`landed` responses include `landed_via`:

- `"direct"` — `mergeCommit.oid` is a literal ancestor of origin's default branch. The normal case.
- `"cherry_pick_equivalent"` — the SHA isn't reachable, but a patch-id-equivalent commit is (detected via `git cherry`). Means the orphan was previously rescued (via `--rescue` or by hand) and re-running `--rescue` on this PR is a no-op.

To recover an orphan:

```bash
github-issue verify-landed <PR-number> --rescue
```

Refuses on a dirty working tree, switches to the default branch, fast-forwards, cherry-picks the orphan, and pushes to origin. Routes failures via `error.cause`: `dirty_tree`, `checkout_failed`, `ff_failed`, `cherry_pick_conflict`, `push_failed`, `rescue_locked`. On `cherry_pick_conflict` the cherry-pick is auto-aborted and `error.output` carries git's error so you can route to **Merge Conflict Resolution** above.

### Closed

PR closed without merge. Gather context and draft a post-mortem comment.

```bash
github-issue post-mortem <N>
```

The response includes PR state, last reviews, inline comments, CI history,
commit log, and recent step_history notes. Synthesize a short comment inferring
why it was closed.

Run the comment body through the [`text-polish`](../text-polish/SKILL.md) skill
before posting. See [Voice for posted content](#voice-for-posted-content).
Then post to the issue:

```bash
gh issue comment <N> --body "$(cat <<'EOF'
## PR closed without merge

<PR link + close date>

**Inferred reason.** <one paragraph synthesis>

**State at close.** <commits, CI, review status>

**Options.** reopen, new PR, or abandon.
EOF
)"
```

Then offer the user the three options: reopen the PR, create a new one, or
abandon.

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

No manual recovery needed. Re-invoke the skill. The last few `step_history.note` fields plus `workflow_detail.open_threads` tell you what was in flight.

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

- **Commits on issue branches.** Freeform; the branch is squash-merged. No Co-Authored-By, no AI attribution.
- **Squashed merge commit on main:** `type(scope): description` built by the skill from PR title + body.
- **Branches.** `type/issue-number-slug` (e.g., `feat/42-add-jwt-auth`). The CLI builds this from issue labels.
- **PR body.** Must reference the issue. Use `Closes #<issue-number>` (auto-close on merge) for atomic issues. For multi-phase or umbrella issues that should stay open after this PR lands, edit the body to use `Refs #<issue-number>` after `github-issue push` runs. The CLI defaults to `Closes` and does not auto-detect multi-phase scope.
