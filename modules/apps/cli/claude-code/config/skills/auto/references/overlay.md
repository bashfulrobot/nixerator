# Stale sentinel cleanup

If `~/.claude/.auto-mode-active` exists at the start of a new `/auto` run, a
prior run crashed without teardown. There is no settings file to restore (this
skill never edits settings -- see `permission-model.md`); the only artifact is
the sentinel, so cleanup is just removing it.

1. Read the sentinel to see which run was orphaned:
   ```bash
   cat ~/.claude/.auto-mode-active
   ```
2. Remove it:
   ```bash
   rm -f ~/.claude/.auto-mode-active
   ```
3. Log the cleanup to
   `~/.claude/autonomous-runs/cleanup-$(date -u +%Y%m%dT%H%M%SZ).md`, noting the
   orphaned run from the sentinel content.

Note: a stale sentinel is already inert in any *other* session, because the
`claude-auto-gate` hook only elevates when the sentinel's `session_id` matches
the running session. This cleanup keeps things tidy and covers the rare case of
a reused session id. This in-skill sweep is the recovery mechanism; there is no
SessionStart hook for it.
