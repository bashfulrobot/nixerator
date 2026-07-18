#!/usr/bin/env bash
# build_card.sh — render the deterministic sections of a triage wizard card from
# td_fetch.sh JSON. Pure: reads JSON on stdin, prints the card, makes NO td /
# network calls (the column name is passed in). The model injects the derived
# triad where the <!--TRIAD--> sentinel appears.
#
# Usage:
#   td_fetch.sh <ref> | build_card.sh --position "4/12" --column "Up Next" [--auto "Waiting Internal"]
# Test guard:
#   BUILD_CARD_LIB=1 source build_card.sh   # defines render_card, runs nothing
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
LIB_EXTRACT=1 source "$SCRIPT_DIR/lib_extract.sh"

render_card() { # position column auto ; json on stdin
  local position="$1" column="$2" auto="$3"
  local json
  json="$(cat)"
  # Validate stdin before rendering: without this, malformed/empty JSON yields a
  # card full of "null"/blank fields and exits 0, silently masking a broken
  # td_fetch upstream. Fail loudly instead.
  if ! jq -e . <<<"$json" >/dev/null 2>&1; then
    echo "build_card: invalid or empty JSON on stdin" >&2
    return 1
  fi
  local title project due prio
  title=$(jq -r '.task.title' <<<"$json")
  project=$(jq -r '.task.project' <<<"$json")
  due=$(jq -r '.task.due // ""' <<<"$json")
  prio=$(jq -r '.task.priority' <<<"$json")

  local due_str
  if [ -n "$due" ]; then
    local od
    od=$(days_since "$due")
    if [ -n "$od" ] && [ "$od" -gt 0 ]; then
      due_str="due ${due} (${od}d overdue)"
    elif [ -n "$od" ] && [ "$od" -eq 0 ]; then
      due_str="due today"
    else due_str="due ${due}"; fi
  else due_str="no due date"; fi

  local col_line=""
  if [ -n "$column" ]; then
    if [ -n "$auto" ] && [ "$auto" != "$column" ]; then
      col_line="  Column: ${column} → ${auto}   (auto)"
    else
      col_line="  Column: ${column}"
    fi
  fi

  local blob
  blob="$title"$'\n'"$(jq -r '.comments[].content' <<<"$json")"
  local crumbs
  crumbs=$(printf '%s' "$blob" | extract_breadcrumbs |
    awk -F'\t' '{printf "%s %s · ", $1, $2}' | sed 's/ · $//')

  local last2
  last2=$(jq -r '
    .comments | (sort_by(.posted_at) | reverse) | .[0:2][]
    | "\((.posted_at // "?")[0:10])  \((.content | gsub("\n";" "))[0:70])"' <<<"$json")

  local newest
  newest=$(jq -r '.comments | (sort_by(.posted_at)|reverse)|.[0].posted_at // ""' <<<"$json")
  local lastmv=""
  local mv
  mv=$(days_since "${newest:0:10}")
  [ -n "$mv" ] && lastmv="last movement ${newest:0:10} (${mv}d)"

  local hedges
  hedges=$(jq -r '.comments[].content' <<<"$json" | harvest_hedges | head -4 | sed 's/^/    · /')

  printf '┌ %s · task %s\n' "$project" "$position"
  printf '  %s        %s · %s\n' "$title" "$prio" "$due_str"
  [ -n "$col_line" ] && printf '%s\n' "$col_line"
  printf '<!--TRIAD-->\n'
  printf '\n  Work log (last 2)\n'
  [ -n "$last2" ] && printf '%s\n' "$last2" | sed 's/^/    /'
  [ -n "$lastmv" ] && printf '  %s\n' "$lastmv"
  [ -n "$crumbs" ] && printf '\n  Breadcrumbs   %s\n' "$crumbs"
  [ -n "$hedges" ] && {
    printf '  Unverified\n'
    printf '%s\n' "$hedges"
  }
  printf '└ done · defer · dig · log · link · col · prio · nudge · draft · escalate · more · skip · ?\n'
}

if [ "${BUILD_CARD_LIB:-}" != "1" ]; then
  position="?"
  column=""
  auto=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --position)
        position="${2:-}"
        shift 2
        ;;
      --column)
        column="${2:-}"
        shift 2
        ;;
      --auto)
        auto="${2:-}"
        shift 2
        ;;
      *)
        echo "unknown arg: $1" >&2
        exit 2
        ;;
    esac
  done
  render_card "$position" "$column" "$auto"
fi
