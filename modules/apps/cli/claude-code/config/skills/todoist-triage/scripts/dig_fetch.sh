#!/usr/bin/env bash
# dig_fetch.sh — deterministic breadcrumb harvest for a `dig`. Fetches the task +
# comments and emits the extracted references (URLs + bare IDs) as a JSON array,
# so the model starts research from a structured list instead of re-scraping
# prose. Read-only.
# Usage: dig_fetch.sh <task-ref>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
LIB_EXTRACT=1 source "$SCRIPT_DIR/lib_extract.sh"

ref="${1:-}"
[ -n "$ref" ] || {
  echo "usage: dig_fetch.sh <task-ref>" >&2
  exit 2
}
json="$(bash "$SCRIPT_DIR/td_fetch.sh" "$ref")"
blob="$(jq -r '.task.title' <<<"$json")"$'\n'"$(jq -r '.comments[].content' <<<"$json")"
printf '%s' "$blob" | extract_breadcrumbs | jq -R -s -c '
  split("\n") | map(select(length>0) | split("\t") | {kind: .[0], ref: .[1]})'
