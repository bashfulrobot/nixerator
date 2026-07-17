#!/usr/bin/env bash
# td_reprioritize.sh — change a task's priority (up OR down) AND log why, as one
# atomic move (Phase 2).
#
# The "reprioritize" macro. Supersedes the old downgrade-only treatment: triage
# legitimately needs to RAISE urgency (a wait that turned into a blocker) as well
# as lower it. Fusing the priority change with its work-log entry keeps the
# reason on the task, same as defer/move.
#
# Priority is the friendly p1..p4 label (p1 = highest). Never pass the raw
# Todoist API value — the API inverts it (4 = highest); `td` takes p1..p4.
#
# Usage:
#   td_reprioritize.sh <task-ref> <p1|p2|p3|p4> [--reason "<text>"] [--next "<text>"] [--dry-run]
#
# Examples:
#   td_reprioritize.sh id:8Jx4 p1 --reason "Customer now blocked in prod; escalating."
#   td_reprioritize.sh id:8Jx4 p4 --reason "De-risked; no longer time-sensitive."
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}

ref="${1:-}"
prio="${2:-}"
if [ -z "$ref" ] || [ -z "$prio" ]; then
  echo "usage: td_reprioritize.sh <task-ref> <p1|p2|p3|p4> [--reason \"<text>\"] [--next \"<text>\"] [--dry-run]" >&2
  exit 2
fi
case "$prio" in
  p1 | p2 | p3 | p4) ;;
  *)
    echo "priority must be one of p1 p2 p3 p4 (p1 = highest), got: $prio" >&2
    exit 2
    ;;
esac
shift 2

reason=""
next=""
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --reason)
      reason="${2:-}"
      shift 2
      ;;
    --next)
      next="${2:-}"
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

dry_flag=()
[ "$dry_run" -eq 1 ] && dry_flag=(--dry-run)

# 1. Change the priority (up or down).
td task update "$ref" --priority "$prio" ${dry_flag[@]+"${dry_flag[@]}"} >/dev/null

# 2. Log it. Not optional — this is why the macro exists.
entry="Reprioritized to ${prio}."
[ -n "$reason" ] && entry+=" ${reason}"

worklog_args=("$ref" --verb reprioritize --entry "$entry")
[ -n "$next" ] && worklog_args+=(--next "$next")
[ "$dry_run" -eq 1 ] && worklog_args+=(--dry-run)

bash "$SCRIPT_DIR/td_worklog.sh" "${worklog_args[@]}"

[ "$dry_run" -eq 1 ] || printf 'reprioritized %s to %s\n' "$ref" "$prio"
