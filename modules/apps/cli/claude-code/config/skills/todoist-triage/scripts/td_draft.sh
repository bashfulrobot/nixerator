#!/usr/bin/env bash
# td_draft.sh — record a prepared-but-UNSENT outward message on the task's work
# log. NEVER sends. Closes the "ready to send / actually sent" limbo: the entry is
# explicitly "Drafted"; only a real send (send/teams/email pipeline) logs "Sent".
# Usage:
#   td_draft.sh <ref> --channel <slack|email|teams> --to "<who>" --text "<msg>" [--link "label=url"] [--dry-run]
#   echo "<msg>" | td_draft.sh <ref> --channel slack --to "Priya" [--link ...]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v td >/dev/null || { echo "td not found (todoist-cli skill)" >&2; exit 127; }
ref="${1:-}"; [ -n "$ref" ] || { echo "usage: td_draft.sh <ref> --channel <slack|email|teams> --to \"<who>\" --text \"<msg>\" [--link ...] [--dry-run]" >&2; exit 2; }
shift
channel=""; to=""; text=""; link=""; dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --channel) channel="${2:-}"; shift 2 ;;
    --to) to="${2:-}"; shift 2 ;;
    --text) text="${2:-}"; shift 2 ;;
    --link) link="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$text" ] && [ ! -t 0 ] && text="$(cat)"
[ -n "$channel" ] && [ -n "$text" ] || { echo "need --channel and --text (or piped text)" >&2; exit 2; }

entry="Drafted ${channel} message${to:+ to ${to}}, NOT sent: ${text}"
wl=("$ref" --verb draft --entry "$entry")
[ -n "$link" ] && wl+=(--link "$link")
[ "$dry_run" -eq 1 ] && wl+=(--dry-run)
bash "$SCRIPT_DIR/td_worklog.sh" "${wl[@]}"
[ "$dry_run" -eq 1 ] || printf 'drafted (not sent) on %s\n' "$ref"
