# Conventions

Issue branches in this workflow are **squash-merged** by default, so the commit that ends up on `main` is one synthetic commit whose message is derived from the PR title + body. That changes how strict to be about history on the branch itself.

## Commits on issue branches

- **Freeform is fine.** WIP checkpoints, small fixes, batches of review-fix changes all go on the branch however is natural. These commits are collapsed at merge time.
- **No AI attribution.** Do NOT add `Co-Authored-By:`, `Signed-off-by:`, or any mention of Claude / Anthropic / AI / "generated" anywhere in commit messages, PR bodies, or issue comments. The user's git identity is the sole author.
- Signing with `-S` is fine if the user's setup requires it, but do not add it unconditionally.

## The squash-merge commit on main

The squash commit title and body follow Conventional Commits:

Format: `<type>(<scope>): <description>`

| Type | When |
|------|------|
| feat | New functionality |
| fix | Bug fix |
| docs | Documentation only |
| style | Formatting, whitespace |
| refactor | Neither fix nor feature |
| perf | Performance improvement |
| test | Adding or fixing tests |
| build | Build system or deps |
| ci | CI configuration |
| chore | Maintenance tasks |
| revert | Reverting a commit |
| security | Security fix |
| deps | Dependency update |

Rules for the squashed commit:
- Scope is REQUIRED: lowercase, kebab-case module name
- Description: imperative mood, lowercase start, no period
- No AI attribution (as above)

Examples:
- `feat(auth): add JWT refresh rotation`
- `fix(api): handle null response from upstream`
- `refactor(db): extract connection pooling`

## Branch naming

Format: `{type}/{issue-number}-{slug}`

- Type matches the Conventional Commit type (feat, fix, docs, refactor, …)
- Slug is kebab-case from the issue title, truncated to fit ~50 chars total
- Examples: `feat/42-add-jwt-auth`, `fix/17-null-response-upstream`

The CLI derives this from issue labels and title automatically.

## PR body

Use `Closes #{issue-number}` so the issue auto-closes on merge.

Structure:
```
## Summary
Closes #<number>: <issue title>

- <commit log entries>
```

The CLI builds this from the commit log at push time.

## Direct-to-main work (outside this skill)

When working directly on `main` (no PR), **atomic commits** matter — each commit lives on its own forever. Split changes that span unrelated concerns into separate commits. That rule does NOT apply on issue branches because of squash-merge.
