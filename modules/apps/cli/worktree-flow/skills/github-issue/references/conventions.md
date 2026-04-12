# Conventions

## Commit Format

Format: `<type>(<scope>): <emoji> <description>`

| Type | Emoji | When |
|------|-------|------|
| feat | :sparkles: | New functionality |
| fix | :bug: | Bug fix |
| docs | :memo: | Documentation only |
| style | :art: | Formatting, whitespace |
| refactor | :recycle: | Neither fix nor feature |
| perf | :zap: | Performance improvement |
| test | :white_check_mark: | Adding or fixing tests |
| build | :construction_worker: | Build system or deps |
| ci | :green_heart: | CI configuration |
| chore | :wrench: | Maintenance tasks |
| revert | :rewind: | Reverting a commit |
| security | :lock: | Security fix |
| deps | :arrow_up: | Dependency update |

Rules:
- Scope is REQUIRED: lowercase, kebab-case module name
- Emoji goes after the colon+space, before description
- Description: imperative mood, lowercase start, no period
- Sign commits: always use `-S` flag
- Do NOT add Co-Authored-By lines

Examples:
- `feat(auth): :sparkles: add JWT refresh rotation`
- `fix(api): :bug: handle null response from upstream`
- `refactor(db): :recycle: extract connection pooling`

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
