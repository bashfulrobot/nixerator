#!/usr/bin/env bash
# td_drop.sh — log why a task stopped mattering, THEN close it. The "drop" macro.
# Usage: td_drop.sh <ref> --reason "<why it stopped mattering>" [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}
ref="${1:-}"
[ -n "$ref" ] || {
  echo "usage: td_drop.sh <ref> --reason \"<why>\" [--dry-run]" >&2
  exit 2
}
shift
reason=""
dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --reason)
      reason="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done
[ -n "$reason" ] || {
  echo "--reason is required (why it's no longer relevant)" >&2
  exit 2
}

wl=("$ref" --verb drop --entry "Dropped: no longer relevant. ${reason}")
[ "$dry_run" -eq 1 ] && wl+=(--dry-run)
bash "$SCRIPT_DIR/td_worklog.sh" "${wl[@]}"

cflags=()
[ "$dry_run" -eq 1 ] && cflags+=(--dry-run)
td task complete "$ref" ${cflags[@]+"${cflags[@]}"} >/dev/null
[ "$dry_run" -eq 1 ] || printf 'dropped %s\n' "$ref"
