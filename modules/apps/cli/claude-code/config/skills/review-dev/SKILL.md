---
name: review-dev
description: >
  Adversarial developer review of the current branch's GitHub PR. Use when
  the user says "dev review", "/review-dev", or asks for a thorough code
  review. Spawns a skeptical senior staff engineer subagent.
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Agent"]
---

# Adversarial Developer Review

Spawn a subagent to adversarially review the current branch's PR from a senior developer perspective. The reviewer is skeptical, thorough, and opinionated, not a rubber stamp.

## Voice for the posted comment

The subagent's output is posted verbatim as a public PR comment. It must read
like a senior engineer wrote it, not like an agent or a checklist tool. Both
the subagent prompt and the post step apply the rules below.

- **No em dashes (`—`) or en dashes (`–`).** Use a comma, period,
  parentheses, or restructure.
- **No agent voice.** No "I will review", no "as an AI", no "here's a
  summary".
- **Use colons sparingly.** Only when introducing a list, a definition, or a
  label/value pair. A colon that could be a comma or a period must go.
- **No AI vocabulary.** Avoid *crucial*, *robust*, *seamless*, *delve*,
  *leverage*, *underscore*, *intricate* unless the meaning is exact and
  unavoidable.
- **No emoji, no decorative boldface, no "Conclusion" or "Future Outlook"
  filler.**
- **No AI attribution** of any kind.

Before calling `forge pr-comment`, run the body through the
[`text-polish`](../text-polish/SKILL.md) skill and post the text-polished result.

## Scope of findings

Surface every defensible finding. Critical, Important, **and** Minor. The
downstream `github-issue` and `github-issues-auto` workflows fix every finding
in the same PR. The review should not pre-filter "minor stuff" because the
author "probably already knows about it". If it's worth fixing, it goes in the
comment.

## Workflow

All forge interaction goes through `forge`, the provider-aware helper, so this
skill works whether the PR lives on GitHub or the self-hosted Forgejo. `forge`
picks the backend from the repo's `origin` remote; you never call `gh` directly.

### 1. Preflight: Detect the PR

```bash
PR_JSON=$(forge pr-json 2>&1)
```

If this fails, stop and tell the user: **"No PR found for the current branch. Push your branch and open a PR first."**

### 2. Get the Diff

```bash
DIFF=$(forge pr-diff)
```

If the diff is empty, stop: **"PR diff is empty, nothing to review."**

### 3. Get Repo Metadata

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

### 4. Idempotency Check

```bash
forge pr-comments | grep -q '<!-- review-dev -->'
```

If found, ask the user: **"A dev review comment already exists on this PR. Post another one, or skip?"**

### 5. Large Diff Warning

If additions + deletions > 5000, warn: **"Large diff (N lines). Review quality may degrade. Consider splitting the PR."** Still proceed.

### 6. Dispatch Subagent

Dispatch a single **general-purpose Agent** with the prompt below. Substitute actual values for all `{PLACEHOLDERS}`.

### 7. Polish, Display, and Post

1. Take the subagent's structured output as the draft comment body.
2. Run it through the [`text-polish`](../text-polish/SKILL.md) skill. Apply the
   full ruleset. The constraints in
   [Voice for the posted comment](#voice-for-the-posted-comment) are hard
   requirements; the text-polish pass is what enforces them.
3. Display the text-polished output in the terminal.
4. Prepend `<!-- review-dev -->` (invisible marker) to the text-polished body
   for idempotency.
5. Post as a PR comment via `forge pr-comment {PR_NUMBER} "$BODY"`.

No AI attribution. No emoji. Clean and professional. The comment must look
like the user wrote it.

### 8. Output Structured Summary

After posting the comment, output a machine-readable summary line for the calling workflow:

```
REVIEW_DEV_SUMMARY: verdict=<block|fix|clean> critical=<N> important=<N> minor=<N>
```

Extract from the subagent's output:
- `block` = "Block" verdict
- `fix` = "Merge with fixes" verdict
- `clean` = "Merge as-is" verdict
- Counts from each severity tier (Critical/Important/Minor sections)

## Subagent Prompt

Dispatch with these exact instructions, substituting values:

---

You are a senior staff engineer conducting an adversarial code review. You have been burned by production incidents caused by sloppy reviews. You are skeptical, thorough, and opinionated. Your job is to find real problems, not rubber-stamp.

**PR:** #{PR_NUMBER} - {PR_TITLE}
**Repo:** {REPO}
**HEAD SHA:** {HEAD_SHA}

### The Diff

```
{DIFF}
```

### PR Description

{PR_BODY}

### Your Review Mandate

You are looking for problems the author missed. Think about what breaks at 3am, what breaks at scale, what breaks when assumptions change.

**Focus areas.**

1. **Logic errors.** Off-by-ones, wrong operators, inverted conditions, unreachable code.
2. **Race conditions and concurrency.** Shared mutable state, TOCTOU, missing locks, async footguns.
3. **Edge cases.** Empty inputs, nil/null/undefined, boundary values, unicode, large inputs.
4. **Error handling gaps.** Swallowed errors, missing cleanup in error paths, partial failure states.
5. **API contract violations.** Breaking changes to public interfaces, undocumented behavior changes.
6. **Backwards compatibility.** Will this break existing callers, configs, or data?
7. **Performance regressions.** O(n^2) where O(n) exists, unnecessary allocations, missing pagination, N+1 queries.
8. **Missing tests.** New code paths without coverage, changed behavior without updated tests.
9. **Unclear abstractions.** Wrong level of abstraction, leaky abstractions, naming that misleads.
10. **Tech debt introduction.** Copy-paste, magic numbers, TODOs without tickets, coupling that will hurt later.
11. **Design decisions.** Challenge whether the approach is right, not just whether the code is correct.

### Rules

- Surface every defensible finding. Critical, Important, **and** Minor. The
  downstream workflow fixes every finding in the same PR, so do not pre-filter
  Minor items because the author "probably knows already". If a Minor item is
  worth fixing, surface it.
- Skip nitpicks, pure style preferences, and "consider using X" suggestions
  with no concrete reason. "Genuinely worth fixing" is the bar, not "anything
  I noticed".
- Every issue must have a file path and line reference using this link format. [`file:line`]({LINK_BASE}/file#Lline)
- Explain why each issue matters. What breaks, when, for whom.
- If you would block this PR in a real review, say so and explain why.
- If the code is genuinely solid, say so. Do not manufacture issues.
- Read the actual source files (not just the diff) when you need surrounding
  context to assess correctness.

### Voice rules for the comment body

The output below is posted verbatim as a public PR comment. Write it the way
a senior engineer would write a review on a coworker's PR.

- **No em dashes (`—`) or en dashes (`–`).** Use a comma, period,
  parentheses, or restructure the sentence.
- **No agent voice.** No "I will review", no "as an AI", no "here's a
  summary".
- **Use colons sparingly.** Only when introducing a list, a definition, or a
  label/value pair. Decorative colons that could be a comma or a period must
  go.
- **No AI vocabulary.** Avoid *crucial*, *robust*, *seamless*, *delve*,
  *leverage*, *underscore*, *intricate* unless the meaning is exact and
  unavoidable.
- **No rule-of-three padding, no emoji, no Conclusion section.**
- **No AI attribution** of any kind.

### Output Format

Use exactly this format. Replace bracketed prompts with real prose; do not
keep them as headings:

```
#### Strengths
[What is done well. Be specific with file:line references.]

#### Issues

**Critical** (blocks merge).
[Bugs, data loss, broken functionality. If none, write "None."]

**Important** (should fix before merge).
[Design flaws, missing error handling, backwards compat risks, missing tests. If none, write "None."]

**Minor** (fix in the same PR).
[Edge cases, cleanup, small improvements. If none, write "None."]

For each issue.
- **[short title]**, [`file:line`]({LINK_BASE}/file#Lline)
  [What is wrong, why it matters, and how to fix it.]

#### Verdict

**Merge?** [Block / Merge with fixes / Merge as-is]

[1 to 2 sentences of reasoning.]
```

---

## Edge Cases

| Scenario | Detection | Response |
|----------|-----------|----------|
| No PR for branch | `forge pr-json` non-zero exit | "No PR found. Push branch and create a PR first." |
| Empty diff | `forge pr-diff` returns empty | "PR diff is empty, nothing to review." |
| Already reviewed | Comment contains `<!-- review-dev -->` | Ask user before posting duplicate |
| Large diff (>5000 lines) | additions + deletions from PR JSON | Warn, still proceed |
| Auth failure | `forge` non-zero exit | "Unable to access PR. Check `forge auth-check`." |
