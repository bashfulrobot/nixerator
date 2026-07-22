---
name: github-issues-auto
description: >-
  Drive one or more GitHub issues end-to-end through the full lifecycle
  (assess → design → plan → implement → verify → push → /review-dev →
  /review-security), one after another, with no user gates and no auto-merge.
  Every PR is left ready-for-review, never set to auto-merge. The human
  reviews and merges manually. For multi-issue runs each subsequent issue
  is branched off the previous issue's branch so the work composes, and
  every PR is annotated with the merge order. Use whenever the user says
  "/github-issues-auto", "/autonomous-issues" (legacy alias), asks to work
  one or more issues hands-off, says "work issue 42 autonomously", "drive
  issues 12, 14, 18 to PR while I'm away", "stack and ship issues X, Y, Z",
  or otherwise wants GitHub issues processed without supervision. Trigger
  eagerly even if the user only hints at hands-off issue work. This skill
  exists for exactly that case.
---

# Autonomous Issues

Drive a queue of GitHub issues from open issue to ready-for-review PR with no
human gates in between. Merging is entirely the human's job. This skill never
enables auto-merge, never asks for it, and actively disables it if a sub-skill
turns it on.

Per-issue work is delegated to the `github-issue` skill, which already runs
`/review-dev` and `/review-security` internally. This skill adds four things
on top:

1. **Stacking.** Issue N+1 is branched off issue N's branch so changes compose.
2. **Autonomy override.** When the underlying skill would pause for a user
   decision, make the call yourself and document it as a PR comment.
3. **Hard completion of every outstanding item.** Every review finding
   (Critical, Important, *and* Minor), every TODO surfaced during
   implementation, every pre-existing bug noticed in adjacent code, every
   lint/format/test failure that turns up gets fixed in the same PR. No
   deferral, no follow-up issues, no "out of scope". Scope expansion to
   complete the work is expected, not avoided.
4. **No auto-merge, ever.** Auto-merge is disabled on every PR, regardless of
   repo defaults or what `github-issue` would otherwise do. Human reviews and
   merges each PR by hand.

## Voice for posted content

This skill posts two kinds of agent-authored content to GitHub: the
**autonomous decisions** comment on each PR, and the **merge-order block**
prepended to each PR body. Both must read like a developer wrote them, not
like a tool announcing what it did.

Before any call to `forge pr-comment` or `forge pr-edit-body`, run the body
through the [`text-polish`](../text-polish/SKILL.md) skill. Hard constraints for
posted content:

- **No em dashes (`—`) or en dashes (`–`).** Comma, period, parentheses, or
  restructure.
- **No agent voice.** Strip "as an AI", "the agent", "I will", "let me know".
  Write as the engineer who made the call.
- **Use colons sparingly.** Only for lists, definitions, or label/value
  pairs. Decorative colons go away.
- **No AI vocabulary.** Drop *crucial*, *seamless*, *robust*, *delve*,
  *leverage*, *underscore*, *intricate* unless they're load-bearing.
- **No AI attribution** of any kind.

## Invocation

```
/github-issues-auto <N1> [<N2> ...]
```

Each argument is a GitHub issue number. Order matters. Issue N+1 stacks on
issue N. If no numbers are supplied, ask the user once for the queue, then
proceed without further interaction.

## Operating Principles

- **Autonomous by default.** After confirming the queue once, do not ask the
  user anything until the final report. Make decisions, document them, move on.
- **Stacking is the explicit exception to the project's "base on main" rule.**
  This skill's whole point is composing issues, so chaining is intentional.
  No other skill or workflow should infer permission to stack from this one.
- **Reviews are not a checkpoint to negotiate around.** Every finding must be
  remediated in the PR that surfaced it. Do not file a follow-up issue, mark
  a finding "minor, accept", "out of scope", or "addressed in #...". Findings
  leave the queue only by being fixed.
- **Never auto-merge.** Even if the repo default or the underlying skill would
  enable auto-merge, disable it. The human reviews each PR and decides when to
  merge. This is a hard rule. Do not negotiate around it.
- **Don't wait for merges.** Once a PR is open and both reviews are clean,
  immediately start issue N+1. PRs sit in ready for review until the human
  merges them.

## Provider awareness

Forge calls go through `forge`, the provider-aware helper, so the mechanical
steps (fetch issue, comment, edit PR body/base) run on GitHub or on the
self-hosted Forgejo per the repo's `origin` remote. One caveat: the stacked-PR
**merge-order and auto-retarget race** described in step 2e is written against
GitHub's exact squash-merge behaviour. Forgejo's stacked-PR semantics differ
and this skill does not automate them, so on a Forgejo repo treat that guidance
as "verify merge order and base refs manually" rather than a GitHub-specific
race. Auto-merge (step 2f) is a GitHub concept; on Forgejo the underlying
`github-issue` path never enables it, so there is nothing to disable.

## Step 1: Pre-flight

Verify the queue. Each issue must exist and be open:

```bash
for n in $ISSUES; do
  forge issue-json "$n" | jq '{n: .number, t: .title, s: .state}'
done
```

If any is closed or missing, surface it and ask the user once whether to skip
or abort. After this single decision, no more user prompts until the final
report.

Also list any issues currently marked as blockers on the queued issues, and
warn if any blocker is OPEN and not in the queue itself. Stacking on top of
unmerged work outside the queue is risky.

State to track across the loop:

- `queue`. Ordered list of issue numbers.
- `cursor`. Index into `queue` of the issue currently being worked (0-based).
- `prev_branch`. Branch name to base the next issue on (initially `origin/main`).
- `prs`. Map of issue to PR number/url, populated as PRs are created.
- `decisions[issue]`. Buffer of decisions made before that issue's PR existed.

This state lives only in the driving session, so a reboot or a killed session
would lose it and force the user to re-supply the queue. It is persisted to disk
via `github-issue queue-state` (see below), so a run resumes where it left off.

### Resume from disk before prompting

Before treating a no-argument invocation as "ask the user for the queue", and
before starting a fresh queue, check for a persisted cursor:

```bash
github-issue queue-state get
```

- `exists: false`. No run in progress. Proceed normally: use the invocation's
  issue numbers, or ask once if none were supplied.
- `exists: true`. A prior run was interrupted. Read `state.queue`,
  `state.cursor`, `state.prev_branch`, `state.prs`, and `state.decisions`, tell
  the user you are resuming that queue from the recorded cursor, and continue
  the loop at `state.cursor` without re-prompting. If the invocation supplied a
  *different* queue than the persisted one, surface the mismatch and ask once
  whether to resume the saved run or clear it and start the new one
  (`github-issue queue-state clear`). This is the only resume-time prompt.

The persisted `queue-state.json` records the queue-level cursor. Per-issue
progress is still read from each worktree's `.worktree-state.json` in step 2a,
so on resume the in-flight issue picks up from its own recorded `workflow_step`.

## Step 2: Per-Issue Loop

For each issue `N` in `queue`, in order:

### 2a. Establish the worktree on the chained base

First check whether work already exists for this issue:

```bash
github-issue status <N>
```

- **Worktree exists.** Capture `worktree`, `branch`, and `workflow_step`. Skip
  setup; the skill will resume from the recorded step.
- **No worktree, first issue in queue.** Run `github-issue setup <N>`.
- **No worktree, subsequent issue.** Run `github-issue setup <N> --base <prev_branch>`.

Capture the branch name from the response. It becomes `prev_branch` for the
next iteration.

### 2b. Hand off to the `github-issue` skill

Invoke the skill with the issue number:

```
Skill(skill: "github-issue", args: "<N>")
```

The `github-issue` skill walks `assess` → `design` → `plan` → `implement` →
`verify` → `push` → `review_dev` → `review_security` → `waiting`. It already
invokes `/review-dev` and `/review-security` at the right steps and enables
auto-merge on a clean run.

Your job during the handoff is to apply the two override rules below.

### 2c. Override autonomy gates

`github-issue` has gates that normally prompt the user:

| Gate | Default behaviour | Autonomous override |
|------|-------------------|---------------------|
| Assess, ambiguous classification | Asks user to confirm or override | Pick the classification that fits the issue body. Default to `standard` if neither `trivial` nor `complex` is clearly indicated. |
| Design, "do not proceed until design is approved" | Hard gate | Run `superpowers:brainstorming`, treat its output as approved, transition to `plan`. |
| Verdict resolution, review summary missing | Asks user | Re-read the review subagent's output, extract verdict + findings yourself, proceed. |
| Idempotency, review comment already exists | Asks user | Skip posting a duplicate; proceed with the existing review's findings. |

Whenever you take an autonomous action that would otherwise have been a user
prompt, append a record to `decisions[N]`:

```
Question. <one sentence>
Options. <bullet list of alternatives considered>
Decision. <what was chosen>
Rationale. <why, grounded in the issue body and codebase>
```

Post the buffered decisions on the PR once it exists, as a single comment.
Run the body through the [`text-polish`](../text-polish/SKILL.md) skill before
posting. See [Voice for posted content](#voice-for-posted-content). The
template below is a shape, not verbatim text; write each entry as natural
prose:

```bash
forge pr-comment <PR> "$(cat <<'EOF'
<!-- github-issues-auto:decisions -->
## Autonomous decisions

### Decision 1
**Question.** ...
**Options.** ...
**Decision.** ...
**Rationale.** ...

### Decision 2
...
EOF
)"
```

Decisions made *after* the PR exists can be posted individually as they happen.
Each individual post also goes through the text-polish pass before
`forge pr-comment`.

### 2d. Force completion of every review finding

When `/review-dev` posts its summary line:

```
REVIEW_DEV_SUMMARY: verdict=<v> critical=<C> important=<I> minor=<M>
```

Treat the rules below as binding, regardless of what the underlying skill
would otherwise do:

- `verdict=block`. Fix the blocker, plus every Important and Minor finding,
  in the same PR. Verify, push.
- `verdict=fix`. Fix every Critical, Important, *and* Minor finding. Don't
  let any minor finding slide because it's "just polish". Verify, push.
- `verdict=clean`. Pass through.

The same rules apply to `/review-security` (`REVIEW_SECURITY_SUMMARY`).

Re-run the relevant review after fixes; both dev and security must end at
`verdict=clean` before this issue is considered done and the next one begins.
If a second review finds *new* issues, fix those too, then re-review.

**Loop guard.** If the same review keeps surfacing the same finding after two
fix attempts, stop the queue and escalate (see Failure Handling).

### 2e. Annotate merge order on the PR

Once the PR exists, edit its body to add (or refresh) a merge-order block at
the top. Run the block through the [`text-polish`](../text-polish/SKILL.md) skill
before posting. See [Voice for posted content](#voice-for-posted-content). Two
flavours: the **parent PR** (or the only PR in the batch) gets an `[!IMPORTANT]`
block; every **stacked child PR** gets a stronger `[!CAUTION]` block because of
the squash-merge race described below.

**Parent or only PR.** Standard merge-order block:

```bash
forge pr-json <PR> | jq -r '.body' > /tmp/body.md
forge pr-edit-body <PR> "$(cat <<EOF
> [!IMPORTANT]
> PR <i> of <total> in an autonomous batch.
> This PR is **not** set to auto-merge. Review and merge manually.
> Merge in this order to avoid conflicts.
> 1. <#PR1>, <title1>
> 2. <#PR2>, <title2>
> ...

$(cat /tmp/body.md)
EOF
)"
```

**Stacked child PR.** Use the stronger block. The danger is real: when the
human merges the parent and then merges the child within ~30 seconds, GitHub
can squash the child against its stale stacked base before the auto-retarget
to main completes. The squash commit gets the right diff but is unreachable
from any branch, so the child's content silently never lands on main even
though the UI marks it merged.

```bash
forge pr-json <PR> | jq -r '.body' > /tmp/body.md
forge pr-edit-body <PR> "$(cat <<EOF
> [!CAUTION]
> PR <i> of <total> in an autonomous batch. **Stacked on #<parent>.**
>
> Before merging this PR, confirm GitHub has retargeted its base from the
> parent's branch to \`main\`:
>
> \`\`\`bash
> forge pr-json <PR> | jq -r '.base'   # expect: main
> \`\`\`
>
> If it still shows the parent's branch, GitHub has not finished the
> auto-retarget yet. Wait for it, or run \`forge pr-edit-base <PR> main\`
> manually. Merging before this is a known squash-merge race that drops
> this PR's content into an unreachable commit.
>
> This PR is **not** set to auto-merge. Review and merge manually.
> Merge in this order to avoid conflicts.
> 1. <#PR1>, <title1>
> 2. <#PR2>, <title2>
> ...

$(cat /tmp/body.md)
EOF
)"
```

Re-emit the block on every PR each time a new PR joins the batch, so the list
grows in lockstep. After the final issue's PR is opened, do one last pass and
update the merge-order block on every PR to the complete list.

### 2f. Disable auto-merge and move on

On GitHub, `github-issue` enables auto-merge automatically when both reviews
come back clean. **Override this.** Immediately disable auto-merge so the PR
sits in ready-for-review until the human merges it manually. Auto-merge is a
GitHub concept, so this whole step is host-gated:

```bash
if [ "$(forge host)" = github ]; then
  # Check current state
  auto_merge=$(gh pr view <PR> --json autoMergeRequest -q '.autoMergeRequest')

  # If anything is set, disable it
  if [ "$auto_merge" != "null" ] && [ -n "$auto_merge" ]; then
    gh pr merge <PR> --disable-auto
  fi

  # Verify it's off (expect: null)
  gh pr view <PR> --json autoMergeRequest -q '.autoMergeRequest'
fi
```

If `gh pr merge --disable-auto` fails (e.g., the repo's branch protection
prevents disabling), surface the failure in the final report so the human
knows to disable it manually before the merge condition is met. Do not
proceed silently.

On Forgejo the `github-issue` path never enables auto-merge, so there is
nothing to disable here; the PR is already open in ready-for-review.

Then:

- Set `prev_branch = <this issue's branch name>`
- Record `prs[N] = {number, url, title}`
- Advance `cursor` to the next issue and **persist the queue cursor to disk**
  so a reboot resumes here rather than re-prompting:

  ```bash
  github-issue queue-state set --json "$(jq -nc \
    --argjson queue "$QUEUE_JSON" \
    --argjson cursor "$CURSOR" \
    --arg prev_branch "$PREV_BRANCH" \
    --argjson prs "$PRS_JSON" \
    --argjson decisions "$DECISIONS_JSON" \
    '{queue: $queue, cursor: $cursor, prev_branch: $prev_branch, prs: $prs, decisions: $decisions}')"
  ```

  Write this after every issue leaves the queue, whether it completed or failed
  (the failure path in [Failure Handling](#failure-handling) persists too), so
  the on-disk cursor always points at the next unstarted issue.
- **Do not wait for review.** Start the next iteration immediately. The PR
  sits open for the human to review and merge whenever they choose.

## Step 3: Final Report

After the last issue's PR is open with both reviews clean, emit one summary.
The summary is shown to the user, not posted to GitHub, so the strict
text-polish rules don't apply, but keep the voice consistent:

```
Autonomous batch complete. <total> PRs open for review.

Auto-merge is OFF on every PR. Review and merge each one manually.

Merge in this order to avoid conflicts.
1. #<PR1>, <title1>, <url1>
2. #<PR2>, <title2>, <url2>
...

After you merge PR <i>, the next PR's base ref needs to retarget to main once
the forge detects the merge. Run `forge pr-edit-base <next> main` if it doesn't
happen automatically.

For stacked batches, after all PRs are merged on GitHub, verify each one
actually landed on main (catches the squash-merge race):

```
github-issue verify-landed <PR1>
github-issue verify-landed <PR2>
```

If any returns `status: "orphaned"`, run `github-issue verify-landed <PR>
--rescue` to cherry-pick the orphan commit onto main and push.

Decisions documented (please review before merging).
- #<PR1>. <count> autonomous decisions logged.
- #<PR2>. <count>
- ...

Findings fixed during review (please skim the diffs).
- #<PR1>. <C critical, I important, M minor>
- ...
```

If any PR's auto-merge could not be disabled (Step 2f), call that out
explicitly in the summary. The human needs to disable it themselves before
the merge condition is met.

Once the summary is emitted and every issue in the queue has a PR open, clear
the persisted cursor so a later invocation starts fresh instead of trying to
resume a finished run:

```bash
github-issue queue-state clear
```

## Failure Handling

Stop the queue (do not silently skip) when:

- An issue has an OPEN blocker not in the queue
- The same review finding survives two fix attempts (loop guard)
- Pre-push rebase produces a conflict that hits the hard-escalate signals in
  the `github-issue` skill (lockfiles, migrations, generated code, or test +
  source both conflicting)
- CI fails and the failure is not addressable from logs alone
- Any other situation where two attempts have not made progress

In each case, leave the in-flight worktree untouched (do not delete or reset
it), then persist the cursor so the deferred run is resumable from disk. Failure
happens mid-issue, before step 2f's advance runs, so persist `cursor` at the
**current** (un-advanced) index, the position of the issue that just stopped.
Use the same `github-issue queue-state set` command as step 2f, but do NOT
advance `cursor` first. Advancing here would move the saved cursor past the
failed issue and silently drop it from the batch on resume. After persisting,
report:

- Which issue stopped the queue.
- What blocker was hit.
- What was tried, with command and output references.
- Two or three concrete pivots the user can choose between.
- The state of every prior PR in the queue (links, merge state).

The remaining issues in the queue are deferred. They are not started until
the user resumes. A fresh session resumes them by reading the persisted cursor
(the resume step under Step 1), so the deferred queue survives a reboot. Do not
clear the cursor on this path; clearing is only for a fully completed batch.

## Why this skill exists

It is reasonable to want to ship three or five small, related issues without
sitting at the keyboard for each one. The underlying `github-issue` skill is
already capable of driving a single issue to merge. What's missing is the
glue that runs it for several issues in the right order, makes the small
judgment calls a human would otherwise be paged for, and produces the
merge-order annotation that turns a stack of PRs into a clean handoff.

This skill is that glue. It deliberately does not reimplement assess, plan,
implement, or review. Those live in `github-issue`, `/review-dev`, and
`/review-security`, and improvements there benefit this skill automatically.
