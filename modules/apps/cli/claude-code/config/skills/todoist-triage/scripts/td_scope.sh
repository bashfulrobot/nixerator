#!/usr/bin/env bash
# td_scope.sh — deterministic Todoist scope resolution for todoist-triage.
#
# Turns a scope selector into a stable JSON array of tasks
# ([{task_id,title,project,due,recurring,priority,url}, ...]) so every run and
# every subagent starts from identical structured `td` output instead of
# re-improvising `td` invocations.
#
# Usage:
#   td_scope.sh list                     # audit: presets + your Todoist saved filters
#   td_scope.sh preset <name>            # a named preset from scopes.json
#   td_scope.sh saved  <filter-name>     # one of your Todoist saved filters, by name
#   td_scope.sh filter "<query>"         # a raw Todoist filter query
#   td_scope.sh project "<name>"         # everything in a project
#   td_scope.sh single <task-ref>        # one task (id: or URL) — single-task mode
#   td_scope.sh default                  # == preset default  (overdue | today)
#   td_scope.sh <name>                   # bare name: try preset, then saved filter
#
# Presets: scopes.json in the skill dir, overridable/extendable from
#   ${XDG_CONFIG_HOME:-$HOME/.config}/todoist-triage/scopes.json
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_SCOPES="$SKILL_DIR/scopes.json"
USER_SCOPES="${XDG_CONFIG_HOME:-$HOME/.config}/todoist-triage/scopes.json"
RUNLOG="${XDG_STATE_HOME:-$HOME/.local/state}/todoist-triage/runs.jsonl"

command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}
command -v jq >/dev/null || {
  echo "jq not found" >&2
  exit 127
}

# Merged presets object: user file wins per-preset.
presets() {
  if [ -f "$USER_SCOPES" ]; then
    jq -s '(.[0].presets // {}) * (.[1].presets // {})' "$REPO_SCOPES" "$USER_SCOPES"
  else
    jq '.presets // {}' "$REPO_SCOPES"
  fi
}

# Resolve a saved Todoist filter name -> its query (case-insensitive).
saved_query() {
  local name="$1"
  td filter list --json 2>/dev/null |
    jq -r --arg n "$name" '.results[] | select((.name|ascii_downcase)==($n|ascii_downcase)) | .query' |
    head -n1
}

# Last-touched index from the local run log: {task_id: {last_touched, last_verb}}.
# ANNOTATION ONLY. This never filters a task out. Hiding work is how work gets
# lost; the due date (set via `defer`) is the "show me later" control. Phase 1
# uses this to assess the delta since the last touch instead of re-deriving the
# whole picture.
touch_index() {
  if [ -f "$RUNLOG" ]; then
    jq -s -c 'map(select(.task_id != null))
      | group_by(.task_id)
      | map({key: .[0].task_id,
             value: (sort_by(.ts) | last | {last_touched: (.ts[0:10]), last_verb: .verb})})
      | from_entries' "$RUNLOG" 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

# Run a filter query and emit the normalized task array.
emit_filter() {
  local query="$1"
  local tasks projects touched
  tasks=$(td task list --filter "$query" --json --all)
  projects=$(td project list --json --all)
  touched=$(touch_index)
  jq -n --argjson t "$tasks" --argjson p "$projects" --argjson tx "$touched" '
    (($p.results // []) | map({(.id): .name}) | add // {}) as $pm
    | ($t.results // []) | map({
        task_id: .id,
        title:   .content,
        project: ($pm[.projectId] // .projectId),
        due:     (.due.date // .due.string // null),
        recurring: (.due.isRecurring // false),
        priority: ("p" + ((5 - .priority) | tostring)),
        url:     .url,
        last_touched: ($tx[.id].last_touched // null),
        last_verb:    ($tx[.id].last_verb // null)
      })
    | sort_by((.priority[1:] | tonumber), (.due // "9999-12-31"))'
}

emit_single() {
  local ref="$1" task projects touched
  task=$(td task view "$ref" --json)
  projects=$(td project list --json --all)
  touched=$(touch_index)
  jq -n --argjson x "$task" --argjson p "$projects" --argjson tx "$touched" '
    (($p.results // []) | map({(.id): .name}) | add // {}) as $pm
    | [ {
        task_id: $x.id,
        title:   $x.content,
        project: ($pm[$x.projectId] // $x.projectId),
        due:     ($x.due.date // $x.due.string // null),
        recurring: ($x.due.isRecurring // false),
        priority: ("p" + ((5 - $x.priority) | tostring)),
        url:     $x.url,
        last_touched: ($tx[$x.id].last_touched // null),
        last_verb:    ($tx[$x.id].last_verb // null)
      } ]'
}

cmd_list() {
  echo "== Presets (scopes.json) =="
  presets | jq -r 'to_entries[] | "  \(.key)\t\(.value.desc // "")\t[\(.value.filter // ("saved:" + .value.saved))]"' |
    column -t -s $'\t' 2>/dev/null || presets | jq -r 'to_entries[] | "  \(.key): \(.value.desc // "")"'
  [ -f "$USER_SCOPES" ] && echo "  (merged with $USER_SCOPES)"
  echo
  echo "== Your Todoist saved filters (td filter list) =="
  td filter list --json 2>/dev/null |
    jq -r '.results[] | "  \(.name)\t[\(.query)]"' | column -t -s $'\t' 2>/dev/null ||
    td filter list 2>/dev/null
  echo
  echo "Also selectable: 'project <name>', 'filter \"<query>\"', 'single <ref>'."
}

main() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    list) cmd_list ;;
    default) emit_filter "$(presets | jq -r '.default.filter')" ;;
    filter)
      [ $# -ge 1 ] || {
        echo "filter needs a query" >&2
        exit 2
      }
      emit_filter "$1"
      ;;
    project)
      [ $# -ge 1 ] || {
        echo "project needs a name" >&2
        exit 2
      }
      emit_filter "##$1"
      ;;
    single)
      [ $# -ge 1 ] || {
        echo "single needs a task ref" >&2
        exit 2
      }
      emit_single "$1"
      ;;
    saved)
      [ $# -ge 1 ] || {
        echo "saved needs a filter name" >&2
        exit 2
      }
      q=$(saved_query "$1")
      [ -n "$q" ] || {
        echo "no saved filter named '$1'. Try: td_scope.sh list" >&2
        exit 3
      }
      emit_filter "$q"
      ;;
    preset)
      [ $# -ge 1 ] || {
        echo "preset needs a name" >&2
        exit 2
      }
      p=$(presets | jq -c --arg n "$1" '.[$n] // empty')
      [ -n "$p" ] || {
        echo "no preset '$1'. Try: td_scope.sh list" >&2
        exit 3
      }
      f=$(printf '%s' "$p" | jq -r '.filter // empty')
      s=$(printf '%s' "$p" | jq -r '.saved  // empty')
      if [ -n "$f" ]; then
        emit_filter "$f"
      else
        q=$(saved_query "$s")
        [ -n "$q" ] || {
          echo "preset '$1' points at missing saved filter '$s'" >&2
          exit 3
        }
        emit_filter "$q"
      fi
      ;;
    *)
      # Bare name: try preset, then saved filter.
      p=$(presets | jq -c --arg n "$sub" '.[$n] // empty')
      if [ -n "$p" ]; then
        main preset "$sub"
        return
      fi
      q=$(saved_query "$sub")
      if [ -n "$q" ]; then
        emit_filter "$q"
        return
      fi
      echo "unknown scope '$sub'. Run: td_scope.sh list" >&2
      exit 3
      ;;
  esac
}

main "$@"
