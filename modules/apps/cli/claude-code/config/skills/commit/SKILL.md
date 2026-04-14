---
name: commit
description: Create conventional commits, push, tagging, or GitHub releases.
disable-model-invocation: true
argument-hint: "[--tag <major|minor|patch>] [--release]"
allowed-tools: ["Bash", "Grep", "Read"]
---

Format: `<type>(<scope>): <description>`

## Rules:

- No branding/secrets.
- **NEVER** add Co-Authored-By, Signed-off-by, or any AI attribution trailer. No mentions of Claude, Anthropic, AI, or "generated" in commit messages. The user's git identity is the sole author.
- Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
- Scope (REQUIRED for git-cliff): lowercase, kebab-case module name.
- Subject: imperative, <72 chars.
- Sign with `git commit -S`. Split unrelated changes atomically.

## Examples:

✅ feat(auth): add OAuth2 login flow
✅ fix(api): resolve race condition in token refresh
❌ feat: add OAuth2 (missing scope)

## Inputs

- Optional flags via $ARGUMENTS:
  - `--tag <level>`: Tag version (major|minor|patch).
  - `--release`: Create GitHub release (requires --tag).

## Outputs

- One or more signed commits.
- Optional signed tag and GitHub release.

## Preflight

- Ensure you are in the repo root before running git commands.
- Inspect working tree and staged changes; avoid committing unrelated changes.
- Stage all changes for this commit.

## Process:

1. Parse $ARGUMENTS flags.
2. Inspect changes: `git status && git diff --cached`.
3. Check branch: detect default branch with `default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'); default_branch="${default_branch:-main}"`. If on default branch, note: "Committing to $default_branch. If this should be on a feature branch, abort and create one first."
4. Check for sensitive files: scan staged and unstaged files for secrets (`.env`, `credentials.*`, `*secret*`, `*.pem`, `*.key`, token/API key patterns). If found, **stop and warn the user** — list the suspect files and ask how to proceed before staging anything.
5. Stage changes: `git add -A` (only after secrets check passes).
6. Split into atomic commits (use `git reset HEAD <files>` + `git add`) if needed.
7. For each: `git commit -S -m "<type>(<scope>): <description>"`
8. If --tag: `git tag -s v<version> -m "Release v<version>"`
9. Always push: `git push && git push --tags` (if tagged).
10. If --release: `gh release create v<version> --notes-from-tag`.
