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
- Stage only the paths this change touched (see step 6). In a shared worktree another agent may have edits present at once, so never blanket-stage.

## Intent Log

Before composing commit messages, check for this session's intent log. The intent-log hook names each file after the Claude Code session id, so resolve the current session's log deterministically as `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/intent-logs/${CLAUDE_CODE_SESSION_ID}.jsonl`. Do not pick the newest `.jsonl` by modification time: in a shared or concurrent setup that can resolve to a different session's log. Each line is `{"timestamp": "...", "prompt": "..."}`.

Use the intent log to understand **why** the changes were made — the user's original request, clarifications, and decisions. Combine this with the diff to write commit messages that capture intent, not just the mechanical "what".

If the log doesn't exist or is empty, fall back to inferring intent from the diff alone.

## Process:

1. Parse $ARGUMENTS flags.
2. Read this session's intent log, keyed by session id (not newest-by-mtime):
   ```bash
   log="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/intent-logs/${CLAUDE_CODE_SESSION_ID}.jsonl"
   case "$CLAUDE_CODE_SESSION_ID" in ''|*/*|*..*) log="" ;; esac
   [ -n "$log" ] && [ -f "$log" ] && cat "$log"
   ```
   The `case` guard skips the log if the session id is unset or contains `/` or `..`, so the path cannot be steered outside the intent-log directory. If the log is skipped or missing, infer intent from the diff alone. Do not fall back to the newest file, which may belong to another session.
3. Inspect the change you are about to attribute: `git status && git diff` (unstaged working-tree changes; nothing is staged yet at this step).
4. Check branch: detect default branch with `default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'); default_branch="${default_branch:-main}"`. If on default branch, note: "Committing to $default_branch. If this should be on a feature branch, abort and create one first."
5. Check for sensitive files: scan staged and unstaged files for secrets (`.env`, `credentials.*`, `*secret*`, `*.pem`, `*.key`, token/API key patterns). If found, **stop and warn the user** — list the suspect files and ask how to proceed before staging anything.
6. Stage only the paths this change touched, by explicit pathspec, after the secrets check passes:
   ```bash
   git add -- <path> [<path> ...]
   ```
   List individual file paths, the exact files you created or modified in this task. Never `git add -A` or `git add .`, and never a directory or glob (`git add -- modules/`); in a shared worktree all of those sweep in a concurrent agent's in-flight edits. `git add -- <path>` stages an add, a modification, or a deletion of that path; for a rename, list both the old and the new path. Then reconcile the staged set against your own work with `git status --short`, in both directions:
   - Nothing you did not touch is staged. Unstage a stray path with `git reset HEAD -- <path>`.
   - Every file you created or changed in this task is accounted for. An untracked file (`??`) you meant to include but did not list is silently dropped from the commit, the one case `git add -A` used to catch. Add it, or leave it out on purpose, but decide rather than forget.
7. Split into atomic commits (use `git reset HEAD -- <path>` + `git add -- <path>`) if needed.
8. For each: `git commit -S -m "<type>(<scope>): <description>"`
9. If --tag: `git tag -s v<version> -m "Release v<version>"`
10. Always push: `git push && git push --tags` (if tagged).
11. If --release: `forge release-create v<version> --notes-from-tag` (dispatches to a GitHub or Forgejo release based on the repo's remote).
