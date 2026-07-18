#!/usr/bin/env bash
# td_escalate.sh — flag a task as escalated: move to a blocker/eng column AND log
# why, fused. Default column "! Customer Blocker". Distinct from send/nudge:
# escalation is an internal status change, not an outward message.
# Usage: td_escalate.sh <ref> [--to "! Customer Blocker"|"Engineering"] --reason "<why>" [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}
ref="${1:-}"
[ -n "$ref" ] || {
  echo "usage: td_escalate.sh <ref> [--to <col>] --reason \"<why>\" [--dry-run]" >&2
  exit 2
}
shift
to="! Customer Blocker"
reason=""
dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --to)
      to="${2:-}"
      shift 2
      ;;
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
  echo "--reason is required" >&2
  exit 2
}
dry_flag=()
[ "$dry_run" -eq 1 ] && dry_flag=(--dry-run)

td task move "$ref" --section "$to" ${dry_flag[@]+"${dry_flag[@]}"} >/dev/null

wl=("$ref" --verb escalate --entry "Escalated → ${to}. ${reason}")
[ "$dry_run" -eq 1 ] && wl+=(--dry-run)
bash "$SCRIPT_DIR/td_worklog.sh" "${wl[@]}"
[ "$dry_run" -eq 1 ] || printf 'escalated %s → %s\n' "$ref" "$to"
