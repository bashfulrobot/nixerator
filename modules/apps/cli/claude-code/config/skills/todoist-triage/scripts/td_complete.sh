#!/usr/bin/env bash
# td_complete.sh — log why a task is done, THEN complete it (log first so the
# reason survives on the task). The "done" macro.
# Usage: td_complete.sh <ref> --reason "<why done>" [--forever] [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}
ref="${1:-}"
[ -n "$ref" ] || {
  echo "usage: td_complete.sh <ref> --reason \"<why>\" [--forever] [--dry-run]" >&2
  exit 2
}
shift
reason=""
forever=0
dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --reason)
      reason="${2:-}"
      shift 2
      ;;
    --forever)
      forever=1
      shift
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
  echo "--reason is required (record why it's done)" >&2
  exit 2
}

wl=("$ref" --verb complete --entry "Completed. ${reason}")
[ "$dry_run" -eq 1 ] && wl+=(--dry-run)
bash "$SCRIPT_DIR/td_worklog.sh" "${wl[@]}"

cflags=()
[ "$forever" -eq 1 ] && cflags+=(--forever)
[ "$dry_run" -eq 1 ] && cflags+=(--dry-run)
td task complete "$ref" ${cflags[@]+"${cflags[@]}"} >/dev/null
[ "$dry_run" -eq 1 ] || printf 'completed %s\n' "$ref"
