# SessionStart maintenance reminders.
#
# Prints any date-gated reminder whose `due` date is on or before today, from
# the Nix-rendered registry at ~/.claude/reminders.json (source: cfg/reminders.nix).
# stdout from a SessionStart hook is shown to the session as additional context.
#
# Wired into settings.json SessionStart via cfg/activation.nix (Nix-owned, stripped
# from capture in cfg/fish.nix). jq/coreutils on PATH via runtimeInputs.

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
registry="$config_dir/reminders.json"
[[ -f "$registry" ]] || exit 0

today="$(date -u +%Y-%m-%d)"

# ISO YYYY-MM-DD dates compare correctly as strings, so `<= today` is the test.
due="$(jq -r --arg today "$today" \
  '.[] | select((.due // "9999-12-31") <= $today) | "[reminder] (due " + (.due // "?") + ") " + (.message // "")' \
  "$registry" 2>/dev/null || true)"

[[ -n "$due" ]] || exit 0
printf '%s\n' "$due"
exit 0
