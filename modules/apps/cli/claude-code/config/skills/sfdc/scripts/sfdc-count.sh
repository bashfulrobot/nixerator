#!/usr/bin/env bash
# Count records matching a SOQL filter. Used as a sanity check before any
# destructive bulk operation.
#
# Usage:
#   sfdc-count.sh [--target-org ALIAS] "SOQL"
#
# Accepts either a full COUNT query or just the FROM clause onward:
#   "SELECT COUNT() FROM Account WHERE Industry='Technology'"
#   "FROM Account WHERE Industry='Technology'"

set -euo pipefail

target_org=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --target-org needs a value" >&2
        exit 2
      fi
      target_org=(--target-org "$2")
      shift 2
      ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  echo "ERROR: missing query" >&2
  echo "Usage: $0 [--target-org ALIAS] \"[SELECT COUNT() ]FROM SObject WHERE ...\"" >&2
  exit 2
fi

query="$1"

# Strip leading whitespace for the regex check
trimmed="${query#"${query%%[![:space:]]*}"}"

# If the query doesn't start with SELECT, prepend "SELECT COUNT() "
if ! [[ "$trimmed" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]] ]]; then
  query="SELECT COUNT() $query"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

sf data query --query "$query" --json "${target_org[@]}" | jq -r '.result.totalSize'
