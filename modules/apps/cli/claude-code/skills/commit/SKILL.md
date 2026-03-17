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
- Never add Co-Authored-By or any AI attribution to commits.
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

## Intent Log
Before composing commit messages, check for a session intent log at `~/.claude/intent-logs/`. Find the current session's log by checking which `.jsonl` file was most recently modified. Each line is `{"timestamp": "...", "prompt": "..."}`.

Use the intent log to understand **why** the changes were made — the user's original request, clarifications, and decisions. Combine this with the diff to write commit messages that capture intent, not just the mechanical "what".

If the log doesn't exist or is empty, fall back to inferring intent from the diff alone.

## Process:
1. Parse $ARGUMENTS flags.
2. Read the intent log: `ls -t ~/.claude/intent-logs/*.jsonl 2>/dev/null | head -1` then read that file to understand session context.
3. Inspect changes: `git status && git diff --cached`.
4. Check branch: detect default branch with `default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'); default_branch="${default_branch:-main}"`. If on default branch, note: "Committing to $default_branch. If this should be on a feature branch, abort and create one first."
5. Stage all changes: `git add -A`.
6. Split into atomic commits (use `git reset HEAD <files>` + `git add`) if needed.
7. For each: `git commit -S -m "<type>(<scope>): <emoji> <description>"`
8. If --tag: `git tag -s v<version> -m "Release v<version>"`
9. Always push: `git push && git push --tags` (if tagged).
10. If --release: `gh release create v<version> --notes-from-tag`.
