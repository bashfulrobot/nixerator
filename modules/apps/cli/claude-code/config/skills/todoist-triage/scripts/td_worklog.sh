#!/usr/bin/env bash
# td_worklog.sh — idempotent work-log append for todoist-triage (Phase 2).
#
# The task's comments ARE Dustin's work log. Every triage action records itself
# here, with links, so the next person to open the task sees current state
# without re-deriving it. This script is the ONLY sanctioned way to write that
# entry: it fixes the format, folds links into Markdown, and is idempotent, so
# the rule "log every action" stops depending on anyone remembering it.
#
# Idempotency: one "Triage log <date>" comment per task per day. A second call
# on the same day APPENDS a bullet to that comment (via `td comment update`)
# instead of posting a duplicate note.
#
# SAFETY: this script only ever touches comments. It never reschedules,
# completes, or edits a task's due date, priority, or status. Callers that need
# those pair a `td task ...` call with a separate call to this script (see
# td_defer.sh and references/macros.md).
#
# Also appends to the local run log (see RUN LOG below), so a later run can tell
# what was already touched without re-researching it.
#
# Usage:
#   td_worklog.sh <task-ref> --entry "<text>" [--verb <name>] [--link "label=url"]...
#                            [--next "<text>"] [--dry-run]
#   echo "<text>" | td_worklog.sh <task-ref> [--link ...] [--next ...] [--dry-run]
#
# Examples:
#   td_worklog.sh id:8Jx4 --verb send --entry "Sent nudge to Priya on the cert bundle." \
#     --link "nudge=https://kong.slack.com/archives/C1/p123" \
#     --next "Check for a reply by 2026-07-18."
#
# RUN LOG: every call appends one JSON line to
#   ${XDG_STATE_HOME:-~/.local/state}/todoist-triage/runs.jsonl
# recording {ts, task_id, verb, entry}. This is a record of what WE did, not a
# cached copy of Todoist state, so it never goes stale in a misleading way and
# does not violate the "never cache live state" rule in source-resolution.md.
# td_scope.sh reads it to ANNOTATE tasks with when they were last touched. It
# never excludes a task on its own: hiding work is what loses track of it. The
# due date remains the "when should I see this again" field, set via `defer`.
#
# Report faithfully: say "Drafted ..." when nothing was sent, "Sent ..." only
# when it was. Never launder a draft into a send.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib_td.sh"

command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}
command -v jq >/dev/null || {
  echo "jq not found" >&2
  exit 127
}

ref="${1:-}"
[ -n "$ref" ] || {
  echo "usage: td_worklog.sh <task-ref> --entry \"<text>\" [--link \"label=url\"]... [--next \"<text>\"] [--dry-run]" >&2
  exit 2
}
shift

entry=""
next=""
verb=""
dry_run=0
links=()

while [ $# -gt 0 ]; do
  case "$1" in
    --entry)
      entry="${2:-}"
      shift 2
      ;;
    --next)
      next="${2:-}"
      shift 2
      ;;
    --verb)
      verb="${2:-}"
      shift 2
      ;;
    --link)
      links+=("${2:-}")
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

# Entry text: --entry wins, else stdin (so callers can pipe multi-line notes).
if [ -z "$entry" ] && [ ! -t 0 ]; then
  entry="$(cat)"
fi
[ -n "$entry" ] || {
  echo "no entry text (pass --entry or pipe it on stdin)" >&2
  exit 2
}

# Render each --link "label=url" as a Markdown link. Todoist renders these; a
# bare URL or "see Slack" does not meet the work-log bar.
rendered_links=""
for l in ${links[@]+"${links[@]}"}; do
  label="${l%%=*}"
  url="${l#*=}"
  if [ -z "$label" ] || [ -z "$url" ] || [ "$label" = "$l" ]; then
    echo "bad --link '$l' (expected \"label=url\")" >&2
    exit 2
  fi
  rendered_links+=" [${label}](${url})"
done

# Record what WE did, so a later run assesses the delta instead of re-deriving
# the whole picture. Annotation only: nothing here ever hides a task.
runlog_append() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/todoist-triage"
  local task_id="${ref#id:}"
  task_id="${task_id##*/}" # a task URL collapses to its trailing id
  mkdir -p "$state_dir"
  jq -n -c \
    --arg ts "$(date -Iseconds)" \
    --arg task_id "$task_id" \
    --arg verb "${verb:-note}" \
    --arg entry "$entry" \
    '{ts: $ts, task_id: $task_id, verb: $verb, entry: $entry}' \
    >>"$state_dir/runs.jsonl"
}

today="$(date +%F)"
header="**Triage log ${today}**"

bullet="- ${entry}${rendered_links}"
[ -n "$next" ] && bullet+=$'\n'"- Next: ${next}"

# Find today's existing log comment, if any (newest wins).
existing_id=""
if comments=$(td_retry comment list "$ref" --json --all --full 2>/dev/null); then
  existing_id=$(printf '%s' "$comments" |
    jq -r --arg h "$header" '[.results[]? | select((.content // "") | startswith($h)) | .id] | last // empty')
fi

if [ -n "$existing_id" ]; then
  # Append to today's entry rather than posting a duplicate note.
  old=$(printf '%s' "$comments" | jq -r --arg id "$existing_id" '.results[] | select(.id == $id) | .content')
  new_content="${old}"$'\n'"${bullet}"
  if [ "$dry_run" -eq 1 ]; then
    printf 'DRY-RUN update comment id:%s on %s:\n%s\n' "$existing_id" "$ref" "$new_content"
    exit 0
  fi
  td_retry comment update "id:${existing_id}" --content "$new_content" >/dev/null
  runlog_append
  printf 'updated work log (id:%s) on %s\n' "$existing_id" "$ref"
else
  new_content="${header}"$'\n\n'"${bullet}"
  if [ "$dry_run" -eq 1 ]; then
    printf 'DRY-RUN add comment on %s:\n%s\n' "$ref" "$new_content"
    exit 0
  fi
  # --content (not --stdin) so td_retry can safely re-issue the call: a piped
  # stdin drains on the first attempt and would be empty on a retry.
  td_retry comment add "$ref" --content "$new_content" >/dev/null
  runlog_append
  printf 'added work log on %s\n' "$ref"
fi
