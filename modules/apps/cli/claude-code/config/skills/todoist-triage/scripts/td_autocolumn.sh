#!/usr/bin/env bash
# td_autocolumn.sh — map an assessed ball-owner to its board column and move the
# task there, logged. The MODEL supplies the ball-owner judgement (parsed from the
# work log); this script owns the deterministic mapping + the move + the log.
#
# Usage:
#   td_autocolumn.sh <task-ref> <customer|internal|me|validation> [--who "<name>"] [--dry-run]
# Test guard:
#   TD_AUTOCOLUMN_LIB=1 source td_autocolumn.sh   # defines column_for_ballowner, runs nothing
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

column_for_ballowner() { # $1 = owner ; prints column name or empty
  case "$1" in
    customer) echo "Waiting Customer" ;;
    internal) echo "Waiting Internal" ;;
    me) echo "Needs Action" ;;
    validation) echo "Waiting Validation" ;;
    *) echo "" ;;
  esac
}

if [ "${TD_AUTOCOLUMN_LIB:-}" != "1" ]; then
  command -v td >/dev/null || {
    echo "td not found (todoist-cli skill)" >&2
    exit 127
  }
  ref="${1:-}"
  owner="${2:-}"
  if [ -z "$ref" ] || [ -z "$owner" ]; then
    echo "usage: td_autocolumn.sh <ref> <customer|internal|me|validation> [--who \"<name>\"] [--dry-run]" >&2
    exit 2
  fi
  shift 2
  who=""
  dry_run=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --who)
        who="${2:-}"
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
  col="$(column_for_ballowner "$owner")"
  [ -n "$col" ] || {
    echo "unknown ball-owner '$owner' (customer|internal|me|validation)" >&2
    exit 2
  }
  reason="Ball on ${owner}${who:+ ($who)}; auto-routed."
  move_args=("$ref" "$col" --reason "$reason")
  [ "$dry_run" -eq 1 ] && move_args+=(--dry-run)
  # The auto-move is non-destructive by design: a wrong or absent column is not a
  # fatal error. If the target column doesn't exist in this project yet (most
  # importantly "Needs Action" before create_needs_action.sh --apply has run
  # there), td_move fails on the section lookup and aborts BEFORE its worklog
  # write — so nothing is half-applied. Catch that here and skip the move rather
  # than let it abort the walk with no card. `if ! cmd` keeps set -e from firing.
  if ! bash "$SCRIPT_DIR/td_move.sh" "${move_args[@]}"; then
    echo "auto-move skipped: could not place $ref in '$col' (column may not exist in this project yet); left in place" >&2
    exit 0
  fi
fi
