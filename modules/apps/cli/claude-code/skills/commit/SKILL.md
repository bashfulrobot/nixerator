---
name: commit
description: Create conventional commits with emoji, push, tagging, or GitHub releases.
disable-model-invocation: true
argument-hint: "[--tag <major|minor|patch>] [--release]"
allowed-tools: ["Bash", "Grep", "Read"]
---

Format: `<type>(<scope>): <emoji> <description>`

## Rules:
- No branding/secrets.
- Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
- Scope (REQUIRED for git-cliff): lowercase, kebab-case module name.
- Emoji: AFTER colon (e.g., `feat(auth): ✨`). Subject: imperative, <72 chars.
- Sign with `git commit -S`. Split unrelated changes atomically.

## Type→Emoji:
feat:✨ fix:🐛 docs:📝 style:🎨 refactor:♻️ perf:⚡ test:✅ build:👷 ci:💚 chore:🔧 revert:⏪ security:🔒 deps:⬆️

## Examples:
✅ feat(auth): ✨ add OAuth2 login flow
✅ fix(api): 🐛 resolve race condition in token refresh
❌ ✨ feat(auth): add OAuth2 (emoji before type)
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
3. Stage all changes: `git add -A`.
4. Split into atomic commits (use `git reset HEAD <files>` + `git add`) if needed.
5. For each: `git commit -S -m "<type>(<scope>): <emoji> <description>"`
6. If --tag: `git tag -s v<version> -m "Release v<version>"`
7. Always push: `git push && git push --tags` (if tagged).
8. If --release: `gh release create v<version> --notes-from-tag`.
