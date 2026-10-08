# Date-gated maintenance reminders, surfaced at SessionStart by reminders.sh.
#
# Each entry is { due = "YYYY-MM-DD"; message = "..."; }. The hook prints any
# entry whose `due` date is on or before today. Add entries here; they render to
# ~/.claude/reminders.json at activation (cfg/activation.nix). ISO dates compare
# lexicographically, which is exactly the "<= today" check the hook performs.
{ pkgs }:
pkgs.writeText "claude-reminders.json" (
  builtins.toJSON [
    {
      due = "2026-10-31";
      message = "claude-code module best-practices audit is due (colobu.com tips last run 2026-05-05; supplementary context-engineering review 2026-07-31). Offer to re-run the procedure at the bottom of modules/apps/cli/claude-code/README.md.";
    }
  ]
)
