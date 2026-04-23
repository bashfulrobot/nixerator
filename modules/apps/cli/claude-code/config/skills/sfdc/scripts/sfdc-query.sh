#!/usr/bin/env bash
# Run a SOQL query via `sf data query` with consistent output modes.
#
# Usage:
#   sfdc-query.sh [--json|--csv|--human] [--bulk] [--target-org ALIAS] "SOQL"
#
# Modes:
#   --human (default) -- formatted table, for interactive use
#   --json            -- raw JSON, for scripts/piping into jq
#   --csv             -- CSV, for reports/spreadsheets
#
# --bulk switches to the Bulk API (required for result sets >2000 rows).

set -euo pipefail

format="human"
bulk=""
target_org=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) format="json"; shift ;;
    --csv) format="csv"; shift ;;
    --human) format="human"; shift ;;
    --bulk) bulk="--bulk --wait 10"; shift ;;
    --target-org)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --target-org needs a value" >&2
        exit 2
      fi
      target_org=(--target-org "$2")
      shift 2
      ;;
    -h|--help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  echo "ERROR: missing SOQL query" >&2
  echo "Usage: $0 [--json|--csv|--human] [--bulk] [--target-org ALIAS] \"SOQL\"" >&2
  exit 2
fi

query="$1"

case "$format" in
  json)
    # shellcheck disable=SC2086
    sf data query --query "$query" --json $bulk "${target_org[@]}"
    ;;
  csv)
    # shellcheck disable=SC2086
    sf data query --query "$query" --result-format csv $bulk "${target_org[@]}"
    ;;
  human)
    # shellcheck disable=SC2086
    sf data query --query "$query" $bulk "${target_org[@]}"
    ;;
esac
