#!/usr/bin/env bash
# td_defer.sh — reschedule a task AND log why, as one atomic move (Phase 2).
#
# The "defer" macro. Fusing the reschedule with its work-log entry is the whole
# point: Step 5 requires every action to be logged, and a fused action cannot
# skip the log. Pushing a date without recording why is what makes a backlog go
# stale in the first place.
#
# Recurrence: this uses `td task reschedule`, which preserves recurrence and
# time-of-day. Never use `td task update --due` to move a date — it overwrites
# the due string and destroys the recurrence pattern on a recurring task.
#
# Usage:
#   td_defer.sh <task-ref> <date> [--reason "<text>"] [--next "<text>"]
#                                 [--remind-at "<datetime>" | --remind-before <dur>]
#                                 [--dry-run]
#
# Examples:
#   td_defer.sh id:8Jx4 2026-07-20 --reason "Waiting on Priya for the cert bundle (12d silent)."
#   td_defer.sh id:8Jx4 2026-07-20 --reason "Blocked until the CAB window." --remind-before 1h
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}

ref="${1:-}"
date_arg="${2:-}"
if [ -z "$ref" ] || [ -z "$date_arg" ]; then
  echo "usage: td_defer.sh <task-ref> <date> [--reason \"<text>\"] [--next \"<text>\"] [--remind-at \"<dt>\" | --remind-before <dur>] [--dry-run]" >&2
  exit 2
fi
shift 2

reason=""
next=""
remind_at=""
remind_before=""
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
    --remind-at)
      remind_at="${2:-}"
      shift 2
      ;;
    --remind-before)
      remind_before="${2:-}"
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

if [ -n "$remind_at" ] && [ -n "$remind_before" ]; then
  echo "--remind-at and --remind-before are mutually exclusive" >&2
  exit 2
fi

dry_flag=()
[ "$dry_run" -eq 1 ] && dry_flag=(--dry-run)

# 1. Move the date (recurrence-safe).
td task reschedule "$ref" "$date_arg" ${dry_flag[@]+"${dry_flag[@]}"} >/dev/null

# 2. Optional reminder.
if [ -n "$remind_at" ]; then
  td reminder add --task "$ref" --at "$remind_at" ${dry_flag[@]+"${dry_flag[@]}"} >/dev/null
elif [ -n "$remind_before" ]; then
  td reminder add --task "$ref" --before "$remind_before" ${dry_flag[@]+"${dry_flag[@]}"} >/dev/null
fi

# 3. Log it. Not optional — this is why the macro exists.
entry="Deferred to ${date_arg}."
[ -n "$reason" ] && entry+=" ${reason}"

worklog_args=("$ref" --verb defer --entry "$entry")
[ -n "$next" ] && worklog_args+=(--next "$next")
[ "$dry_run" -eq 1 ] && worklog_args+=(--dry-run)

bash "$SCRIPT_DIR/td_worklog.sh" "${worklog_args[@]}"

[ "$dry_run" -eq 1 ] || printf 'deferred %s to %s\n' "$ref" "$date_arg"
