---
name: review-dev
description: >
  Adversarial developer review of the current branch's GitHub PR. Use when
  the user says "dev review", "/review-dev", or asks for a thorough code
  review. Spawns a skeptical senior staff engineer subagent.
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Agent"]
---

# Adversarial Developer Review

Spawn a subagent to adversarially review the current branch's PR from a senior developer perspective. The reviewer is skeptical, thorough, and opinionated — not a rubber stamp.

## Workflow

### 1. Preflight: Detect the PR

```bash
PR_JSON=$(gh pr view --json number,title,url,baseRefName,headRefName,headRefOid,body,additions,deletions,changedFiles 2>&1)
```

If this fails, stop and tell the user: **"No PR found for the current branch. Push your branch and open a PR first."**

### 2. Get the Diff

```bash
DIFF=$(gh pr diff)
```

If the diff is empty, stop: **"PR diff is empty — nothing to review."**

### 3. Get Repo Metadata

```bash
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
HEAD_SHA=$(gh pr view --json headRefOid -q '.headRefOid')
PR_NUMBER=$(gh pr view --json number -q '.number')
PR_TITLE=$(gh pr view --json title -q '.title')
PR_BODY=$(gh pr view --json body -q '.body')
```

### 4. Idempotency Check

```bash
gh pr view --json comments -q '.comments[].body' | grep -q '<!-- review-dev -->'
```

If found, ask the user: **"A dev review comment already exists on this PR. Post another one, or skip?"**

### 5. Large Diff Warning

If additions + deletions > 5000, warn: **"Large diff (N lines). Review quality may degrade. Consider splitting the PR."** Still proceed.

### 6. Dispatch Subagent

Dispatch a single **general-purpose Agent** with the prompt below. Substitute actual values for all `{PLACEHOLDERS}`.

### 7. Display and Post

- Display the subagent's structured output in the terminal.
- Post as a PR comment via `gh pr comment {PR_NUMBER} --body "$BODY"`.
- Prepend `<!-- review-dev -->` (invisible marker) to the comment body for idempotency.
- **No AI attribution.** No emoji. Clean and professional — it should look like the user wrote it.

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

**Focus areas:**

1. **Logic errors** — off-by-ones, wrong operators, inverted conditions, unreachable code
2. **Race conditions and concurrency** — shared mutable state, TOCTOU, missing locks, async footguns
3. **Edge cases** — empty inputs, nil/null/undefined, boundary values, unicode, large inputs
4. **Error handling gaps** — swallowed errors, missing cleanup in error paths, partial failure states
5. **API contract violations** — breaking changes to public interfaces, undocumented behavior changes
6. **Backwards compatibility** — will this break existing callers/configs/data?
7. **Performance regressions** — O(n^2) where O(n) exists, unnecessary allocations, missing pagination, N+1 queries
8. **Missing tests** — new code paths without coverage, changed behavior without updated tests
9. **Unclear abstractions** — wrong level of abstraction, leaky abstractions, naming that misleads
10. **Tech debt introduction** — copy-paste, magic numbers, TODOs without tickets, coupling that will hurt later
11. **Design decisions** — challenge whether the approach is right, not just whether the code is correct

### Rules

- Only report issues you are confident about. No nitpicks, no style preferences, no "consider using X."
- Every issue must have a file path and line reference using this link format: [`file:line`](https://github.com/{REPO}/blob/{HEAD_SHA}/file#Lline)
- Explain WHY each issue matters (what breaks, when, for whom)
- If you would block this PR in a real review, say so and explain why
- If the code is genuinely solid, say that — do not manufacture issues
- Read the actual source files (not just the diff) when you need surrounding context to assess correctness

### Output Format

Use exactly this format:

```
#### Strengths
[What is done well — be specific with file:line references]

#### Issues

**Critical** (blocks merge):
[Bugs, data loss, broken functionality. If none, write "None."]

**Important** (should fix before merge):
[Design flaws, missing error handling, backwards compat risks, missing tests. If none, write "None."]

**Minor** (fix at your discretion):
[Edge cases, cleanup, minor improvements. If none, write "None."]

For each issue:
- **[short title]** — [`file:line`](https://github.com/{REPO}/blob/{HEAD_SHA}/file#Lline)
  [What is wrong, why it matters, and how to fix it]

#### Verdict

**Merge?** [Block / Merge with fixes / Merge as-is]

[1-2 sentence reasoning]
```

---

## Edge Cases

| Scenario | Detection | Response |
|----------|-----------|----------|
| No PR for branch | `gh pr view` non-zero exit | "No PR found. Push branch and create a PR first." |
| Empty diff | `gh pr diff` returns empty | "PR diff is empty — nothing to review." |
| Already reviewed | Comment contains `<!-- review-dev -->` | Ask user before posting duplicate |
| Large diff (>5000 lines) | additions + deletions from PR JSON | Warn, still proceed |
| Auth failure | `gh` returns 403/404 | "Unable to access PR. Check `gh auth status`." |
