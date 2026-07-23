#!/usr/bin/env bash
# create_needs_action.sh — one-shot: add a "Needs Action" section to every Kong*
# board project + the `template`, idempotently. Defaults to --dry-run; pass
# --apply to actually create. After creation, position it with `td section reorder`
# (or drag it in the UI) — this script only creates.
# Usage: create_needs_action.sh [--apply]
set -euo pipefail
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_td.sh"
command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}
command -v jq >/dev/null || {
  echo "jq not found" >&2
  exit 127
}

APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    *)
      echo "unknown arg: $1 (usage: create_needs_action.sh [--apply])" >&2
      exit 2
      ;;
  esac
done
COL="Needs Action"

# Capture the project list on its own line so `set -e` catches an upstream `td`
# failure (auth/network). Inside `mapfile < <(...)` a failing `td project list`
# is masked: jq/grep just yield nothing and the run looks like "no Kong projects"
# instead of "the listing failed".
proj_json="$(td_retry project list --json --all)"
mapfile -t projects < <(printf '%s' "$proj_json" | jq -r '.results[].name' | grep -E '^(Kong|template)')

for p in "${projects[@]}"; do
  # Skip Kong-cs (internal CS subset — no customer-facing waiting columns; Needs
  # Action still applies there, so include it, but leave the skip hook here in
  # case policy changes).
  existing=$(td_retry section list "$p" --json 2>/dev/null | jq -r '[.results[]?.name] | index("'"$COL"'")')
  if [ "$existing" != "null" ] && [ -n "$existing" ]; then
    echo "skip: $p already has '$COL'"
    continue
  fi
  if [ "$APPLY" -eq 1 ]; then
    td_retry section create --project "$p" --name "$COL" >/dev/null && echo "created: $p → $COL"
  else
    echo "DRY-RUN would create '$COL' in: $p"
  fi
done

[ "$APPLY" -eq 1 ] || echo "(dry-run; re-run with --apply to create)"
