# Stale Overlay Cleanup

If `~/.claude/.auto-mode-active` exists at the start of a new `/auto` run,
a prior run crashed without teardown. Restore order:

1. Read the sentinel:
   ```bash
   cat ~/.claude/.auto-mode-active
   ```
2. Restore the backed-up settings:
   ```bash
   if [ -f ~/.claude/settings.local.json.auto-backup ]; then
     mv ~/.claude/settings.local.json.auto-backup ~/.claude/settings.local.json
   fi
   ```
3. Remove the sentinel:
   ```bash
   rm -f ~/.claude/.auto-mode-active
   ```
4. Log the cleanup to `~/.claude/autonomous-runs/cleanup-$(date -u +%Y%m%dT%H%M%SZ).md`
   noting which prior run was orphaned (from sentinel content).

This in-skill cleanup is the primary recovery mechanism. There is no
SessionStart hook for this — a crashed `/auto` run is recovered the
next time `/auto` is invoked (or you can run the steps above by hand
if you spot a leftover `.auto-mode-active` sentinel).
