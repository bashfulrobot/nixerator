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
    --json)
      format="json"
      shift
      ;;
    --csv)
      format="csv"
      shift
      ;;
    --human)
      format="human"
      shift
      ;;
    --bulk)
      bulk=1
      shift
      ;;
    --target-org)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --target-org needs a value" >&2
        exit 2
      fi
      target_org=(--target-org "$2")
      shift 2
      ;;
    -h | --help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  echo "ERROR: missing SOQL query" >&2
  echo "Usage: $0 [--json|--csv|--human] [--bulk] [--target-org ALIAS] \"SOQL\"" >&2
  exit 2
fi

query="$1"

# Bulk path: `sf data query` dropped its `--bulk`/`--wait` flags. Async
# large-result exports now live in the dedicated `sf data export bulk` command
# (Bulk API 2.0), which *requires* --output-file and supports only csv/json
# (no human table). We run it into a temp file, forward its job-status chatter
# to stderr, and cat the records to stdout so the script's stdout contract
# (query results) is preserved. A human-format request downgrades to csv,
# since a table of a bulk-sized result set is unusable anyway.
if [[ -n "$bulk" ]]; then
  fmt="$format"
  [[ "$fmt" == "human" ]] && fmt="csv"
  tmp="$(mktemp)"
  rc=0
  sf data export bulk --query "$query" --output-file "$tmp" \
    --result-format "$fmt" --wait 10 "${target_org[@]}" >&2 || rc=$?
  [[ "$rc" -eq 0 ]] && cat "$tmp"
  rm -f "$tmp"
  exit "$rc"
fi

case "$format" in
  json)
    sf data query --query "$query" --json "${target_org[@]}"
    ;;
  csv)
    sf data query --query "$query" --result-format csv "${target_org[@]}"
    ;;
  human)
    sf data query --query "$query" "${target_org[@]}"
    ;;
esac
