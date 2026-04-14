# Conventions

## Commit Format

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

Rules:
- Scope is REQUIRED: lowercase, kebab-case module name
- Description: imperative mood, lowercase start, no period
- Sign commits: always use `-S` flag
- **NEVER** add Co-Authored-By, Signed-off-by, or any AI attribution trailer
- No mentions of Claude, Anthropic, AI, or "generated" anywhere in commit messages, PR bodies, or issue comments
- The user's git identity is the sole author — do not inject any co-author or tool attribution

Examples:
- `feat(auth): add JWT refresh rotation`
- `fix(api): handle null response from upstream`
- `refactor(db): extract connection pooling`

## Branch Naming

Format: `{type}/{issue-number}-{slug}`

- Type matches commit type (feat, fix, docs, refactor, etc.)
- Slug is kebab-case from issue title, truncated to fit ~50 chars total
- Examples: `feat/42-add-jwt-auth`, `fix/17-null-response-upstream`

The bash worktree-flow derives this automatically from issue labels and title. In standalone mode, follow the same pattern manually.

## PR Body

Use `Closes #{issue-number}` to auto-close the issue on merge.

Structure:
```
## Summary
Closes #<number>: <issue title>

- <commit log entries>
```

The bash worktree-flow builds this automatically from the commit log. In standalone mode, use `gh pr create` with this format.

## Atomic Commits

Make each commit a logical unit of work. If changes span unrelated concerns, split into separate commits. The commit skill handles staging and security scanning.
