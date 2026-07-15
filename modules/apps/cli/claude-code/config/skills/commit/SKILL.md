---
name: commit
description: Create conventional commits, push, tagging, or GitHub/Forgejo releases.
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
  - `--release`: Create a release — GitHub or Forgejo, per the repo's remote (requires --tag).

## Outputs

- One or more signed commits.
- Optional signed tag and release (GitHub or Forgejo).

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
5. Check for sensitive files: scan staged and unstaged files for secrets (`.env`, `credentials.*`, `*secret*`, `*.pem`, `*.key`, token/API key patterns). If found, **stop and warn the user** — list the suspect files and ask how to proceed before staging anything.
6. Stage changes: `git add -A` (only after secrets check passes).
7. Split into atomic commits (use `git reset HEAD <files>` + `git add`) if needed.
8. For each: `git commit -S -m "<type>(<scope>): <description>"`
9. If --tag: `git tag -s v<version> -m "Release v<version>"`
10. Always push: `git push && git push --tags` (if tagged).
11. If --release: `forge release-create v<version> --notes-from-tag` (dispatches to a GitHub or Forgejo release based on the repo's remote).
