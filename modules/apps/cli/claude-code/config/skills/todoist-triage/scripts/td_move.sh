#!/usr/bin/env bash
# td_move.sh — move a task to a board column AND log why, as one atomic move (Phase 2).
#
# The "move" macro. Fusing the section move with its work-log entry is the whole
# point: Step 5 requires every action to be logged, and a fused action cannot
# skip the log. A task in the wrong column is silent stale state; recording the
# move (and why) keeps the board honest.
#
# Columns are the stable Kanban vocabulary in references/kanban-board.md. Only
# Kong* board projects have columns. `td task move --section "<name>"` resolves
# the name within the task's own project, so the column name is all that's
# needed — no per-project section-id lookup. If the column doesn't exist in the
# task's project (e.g. a Kong-cs subset), td errors; fall back to a valid column.
#
# Usage:
#   td_move.sh <task-ref> "<Column>" [--reason "<text>"] [--next "<text>"] [--dry-run]
#
# Examples:
#   td_move.sh id:8Jx4 "Waiting Customer" --reason "Nudged Priya; ball back on lululemon (12d silent)."
#   td_move.sh id:8Jx4 "Capture Data" --reason "Next step: write the mTLS runbook into Confluence."
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}

ref="${1:-}"
column="${2:-}"
if [ -z "$ref" ] || [ -z "$column" ]; then
  echo "usage: td_move.sh <task-ref> \"<Column>\" [--reason \"<text>\"] [--next \"<text>\"] [--dry-run]" >&2
  exit 2
fi
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

# 1. Move the task to the target column.
td task move "$ref" --section "$column" ${dry_flag[@]+"${dry_flag[@]}"} >/dev/null

# 2. Log it. Not optional — this is why the macro exists.
entry="Moved to ${column}."
[ -n "$reason" ] && entry+=" ${reason}"

worklog_args=("$ref" --verb move --entry "$entry")
[ -n "$next" ] && worklog_args+=(--next "$next")
[ "$dry_run" -eq 1 ] && worklog_args+=(--dry-run)

bash "$SCRIPT_DIR/td_worklog.sh" "${worklog_args[@]}"

[ "$dry_run" -eq 1 ] || printf 'moved %s to %s\n' "$ref" "$column"
