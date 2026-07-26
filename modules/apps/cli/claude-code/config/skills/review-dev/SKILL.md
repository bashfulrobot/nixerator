---
name: review-dev
description: >-
  Adversarial developer review of the current branch's PR, dispatched to the
  reviewer-dev subagent: correctness bugs, edge cases, error handling, and
  reuse/simplification findings against the diff.
when_to_use: >-
  Use when the user says "dev review", "review this PR", "/review-dev", "tear
  this branch apart", or asks for a thorough or adversarial code review of the
  current branch. Pair with review-security when the diff touches auth,
  secrets, network exposure, or input parsing.
effort: high
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Agent"]
---

# Adversarial Developer Review

Dispatch the `reviewer-dev` subagent to review the current branch's PR from a senior developer perspective. The reviewer is skeptical, thorough, and opinionated, not a rubber stamp.

The reviewer's persona, focus areas, rules, voice, and output format live in the
agent definition (`~/.claude/agents/reviewer-dev.md`), not here. This skill's job
is to gather the inputs, dispatch, and handle the result. Do not restate the
review mandate in the dispatch prompt; the agent already has it.

## Two modes

**`full`** is the first review of a PR. It reads the whole diff and produces the
complete finding set.

**`delta`** is every review after that. It reads only the changes since a given
base SHA, checks the previous findings against the fix, and flags what the fix
itself broke.

This split is what makes the loop terminate. A fresh reviewer handed the whole
mutated diff every round will keep finding new small things in code that was
already cleared, forever. Delta rounds shrink; full rounds do not.

Round 1 is always `full`. Use `delta` whenever the caller passes a base SHA and
a previous finding set.

## Model tiering

The agent definition pins `model: opus` and `effort: high`, which is what a
`full` round needs. For a `delta` round, dispatch the same agent with a
per-invocation `model: sonnet`. The scope is a handful of changed lines against a
known checklist, so the cheaper model at high effort is not a quality
compromise. `effort` cannot be overridden per invocation, so it stays `high`
either way, which is the half that matters here.

Never put `model:` in this skill's frontmatter. Skill-level `model` applies for
the rest of the *turn*, not just the review, so it would silently upgrade every
fix, verify, and push step the calling workflow runs afterward.

## Workflow

All forge interaction goes through `forge`, the provider-aware helper, so this
skill works whether the PR lives on GitHub or the self-hosted Forgejo. `forge`
picks the backend from the repo's `origin` remote; you never call `gh` directly.

### 1. Preflight: detect the PR

```bash
PR_JSON=$(forge pr-json 2>&1)
```

If this fails, stop and tell the user: **"No PR found for the current branch. Push your branch and open a PR first."**

### 2. Get the diff

For a `full` review, the whole PR:

```bash
DIFF=$(forge pr-diff)
```

For a `delta` review, only what changed since the base SHA the caller gave you:

```bash
DIFF=$(git diff "${DELTA_BASE_SHA}"...HEAD)
```

If the diff is empty in `full` mode, stop: **"PR diff is empty, nothing to review."**
If it is empty in `delta` mode, there is nothing to verify. Report
`verdict=clean` with no new findings and skip the dispatch entirely; that is a
free round.

### 3. Get repo metadata

`forge pr-json` already returned everything; pull the fields from `$PR_JSON`
(one API call, provider-neutral keys) rather than re-fetching:

```bash
REPO=$(forge repo)
HEAD_SHA=$(echo "$PR_JSON" | jq -r '.headSha')
PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
PR_BODY=$(echo "$PR_JSON" | jq -r '.body')
# Base for file links at this commit. forge picks the right host and path
# style per provider (GitHub /blob/<sha>, Forgejo /src/commit/<sha>), so
# source links resolve on whichever forge the PR lives on.
LINK_BASE=$(forge blob-base "$HEAD_SHA")
```

### 4. Idempotency check (`full` only)

```bash
forge pr-comments | grep -q '<!-- review-dev -->'
```

If found, ask the user: **"A dev review comment already exists on this PR. Post another one, or skip?"**

`delta` rounds do not post, so they skip this check.

### 5. Large diff warning

If additions + deletions > 5000, warn: **"Large diff (N lines). Review quality may degrade. Consider splitting the PR."** Still proceed.

### 6. Dispatch

Dispatch the **`reviewer-dev`** agent. For a `delta` round, add
`model: sonnet` to the dispatch.

The prompt is only the inputs. Substitute real values:

```
mode: full            (or: mode: delta)

PR: #{PR_NUMBER} - {PR_TITLE}
Repo: {REPO}
HEAD SHA: {HEAD_SHA}
LINK_BASE: {LINK_BASE}

### PR description

{PR_BODY}

### The diff

```
{DIFF}
```
```

For a `delta` round, append:

```
### Delta base

Everything above the diff is unchanged since {DELTA_BASE_SHA}. The diff shown is
only the fix delta.

### Previous findings (frozen ledger)

{PENDING_FINDINGS_JSON}
```

Where `{PENDING_FINDINGS_JSON}` is the `dev`-sourced entries from
`github-issue findings <n> get --pending`, or whatever equivalent list the
caller holds. Pass it verbatim; do not summarize it.

### 7. Handle the result

The agent returns prose followed by a fenced `json` block. Split them.

**Prose (`full` mode only).** This is the PR comment body.

1. Run it through the [`text-polish`](../text-polish/SKILL.md) skill. The voice
   rules in the agent definition are hard requirements and text-polish is what
   enforces them.
2. Display the text-polished output in the terminal.
3. Prepend `<!-- review-dev -->` (invisible marker) for idempotency.
4. Post via `forge pr-comment {PR_NUMBER} "$BODY"`.

No AI attribution. No emoji. The comment must look like the user wrote it.

**Prose (`delta` mode).** Do not post it. Delta rounds are internal
verification, and the round-1 comment plus the fix commits are already the
public record. Show the "Previous findings" section and the verdict in the
terminal so the user can see what happened, and stop there. This is also what
keeps the expensive text-polish round-trip at once per PR instead of once per
round.

**JSON block.** Write it to a temp file rather than carrying it in context:

```bash
FINDINGS_FILE=$(mktemp -t review-dev-findings.XXXXXX.json)
# ...write the agent's json block into $FINDINGS_FILE...
```

The calling workflow feeds that file straight into
`github-issue findings <n> set --json "$(cat "$FINDINGS_FILE")"` on the first
round, and `findings ... add` on every round after, so the finding list never has
to be re-read into anybody's context to be recorded.

### 8. Output structured summary

Output one machine-readable line for the calling workflow:

```
REVIEW_DEV_SUMMARY: verdict=<block|fix|clean> critical=<N> important=<N> minor=<N> resolved=<N> unresolved=<N> findings=<path>
```

- `verdict` comes from the JSON block: `block`, `fix`, or `clean`.
- The severity counts are new findings from this pass only.
- `resolved` and `unresolved` are 0 in `full` mode.
- `findings` is the path from step 7, or `-` when the agent produced nothing.

## Edge Cases

| Scenario | Detection | Response |
|----------|-----------|----------|
| No PR for branch | `forge pr-json` non-zero exit | "No PR found. Push branch and create a PR first." |
| Empty diff (`full`) | `forge pr-diff` returns empty | "PR diff is empty, nothing to review." |
| Empty diff (`delta`) | `git diff` since base is empty | Report `verdict=clean`, no dispatch |
| Already reviewed | Comment contains `<!-- review-dev -->` | Ask user before posting duplicate |
| Large diff (>5000 lines) | additions + deletions from PR JSON | Warn, still proceed |
| Auth failure | `forge` non-zero exit | "Unable to access PR. Check `forge auth-check`." |
| Agent returns no JSON block | No fenced `json` at end of output | Treat as a failed pass; re-dispatch once, then surface to the user |
