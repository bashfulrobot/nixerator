#!/usr/bin/env bash
# create_needs_action.sh — one-shot: add a "Needs Action" section to every Kong*
# board project + the `template`, idempotently. Defaults to --dry-run; pass
# --apply to actually create. After creation, position it with `td section reorder`
# (or drag it in the UI) — this script only creates.
# Usage: create_needs_action.sh [--apply]
set -euo pipefail
command -v td >/dev/null || { echo "td not found (todoist-cli skill)" >&2; exit 127; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 127; }

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1
COL="Needs Action"

# All board projects whose name starts with Kong, plus template.
mapfile -t projects < <(td project list --json --all | jq -r '.results[].name' | grep -E '^(Kong|template)')

for p in "${projects[@]}"; do
  # Skip Kong-cs (internal CS subset — no customer-facing waiting columns; Needs
  # Action still applies there, so include it, but leave the skip hook here in
  # case policy changes).
  existing=$(td section list "$p" --json 2>/dev/null | jq -r '[.results[]?.name] | index("'"$COL"'")')
  if [ "$existing" != "null" ] && [ -n "$existing" ]; then
    echo "skip: $p already has '$COL'"
    continue
  fi
  if [ "$APPLY" -eq 1 ]; then
    td section create --project "$p" --name "$COL" >/dev/null && echo "created: $p → $COL"
  else
    echo "DRY-RUN would create '$COL' in: $p"
  fi
done

[ "$APPLY" -eq 1 ] || echo "(dry-run; re-run with --apply to create)"
