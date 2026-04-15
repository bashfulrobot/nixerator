#!/usr/bin/env bash
set -euo pipefail

# Query picklist values for a given field on the Case object.
# Usage: sfdc-query-picklist.sh <field_api_name>
# Output: JSON array of picklist value strings

FIELD="${1:?Usage: sfdc-query-picklist.sh <field_api_name>}"
CACHE="/tmp/sf_case_describe.json"
CACHE_TTL=300 # 5 minutes

# Use cached describe if fresh enough
if [[ -f "$CACHE" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$CACHE") ))
  if (( age > CACHE_TTL )); then
    rm -f "$CACHE"
  fi
fi

if [[ ! -f "$CACHE" ]]; then
  result=$(sf sobject describe --sobject Case --json 2>&1) || {
    jq -n '{error: "Failed to describe Case object"}' >&2
    exit 1
  }
  echo "$result" > "$CACHE"
fi

# Extract picklist values for the requested field
values=$(jq -r --arg field "$FIELD" '
  .result.fields[]
  | select(.name == $field)
  | [.picklistValues[] | select(.active == true) | .value]
' "$CACHE" 2>/dev/null)

if [[ -z "$values" || "$values" == "null" ]]; then
  jq -n --arg field "$FIELD" '{error: ("\($field) not found or is not a picklist")}' >&2
  exit 1
fi

echo "$values"
