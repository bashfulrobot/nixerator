# GitHub Issue Workflow - Conventions

## Commit Format

Format: `<type>(<scope>): <emoji> <description>`

Rules:
- Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
- Scope (REQUIRED): lowercase, kebab-case module name
- Emoji: single emoji after colon+space
- Description: imperative mood, lowercase start, no period
- Sign commits: always use `-S` flag
- Do NOT add Co-Authored-By lines

Examples:
- `feat(auth): :sparkles: add JWT refresh rotation`
- `fix(api): :bug: handle null response from upstream`

## PR Body Format

When creating a PR, use this body structure:

```
## Summary
<1-3 bullet points describing what changed and why>
```
