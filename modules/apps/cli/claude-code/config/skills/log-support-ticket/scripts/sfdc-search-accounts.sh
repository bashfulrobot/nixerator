#!/usr/bin/env bash
set -euo pipefail

# Search SFDC accounts by name substring.
# Usage: sfdc-search-accounts.sh "<search_term>"
# Output: JSON array of {Id, Name} objects

SEARCH="${1:?Usage: sfdc-search-accounts.sh \"<search_term>\"}"

# Escape single quotes for SOQL
SEARCH_ESCAPED="${SEARCH//\'/\\\'}"

QUERY="SELECT Id, Name FROM Account WHERE Name LIKE '%${SEARCH_ESCAPED}%' ORDER BY Name LIMIT 20"

result=$(sf data query --query "$QUERY" --json 2>&1) || {
  jq -n '{error: "SOQL query failed"}' >&2
  exit 1
}

# Check for query errors
status=$(echo "$result" | jq -r '.status // 1')
if [[ "$status" != "0" ]]; then
  msg=$(echo "$result" | jq -r '.message // "Unknown error"')
  jq -n --arg msg "$msg" '{error: $msg}' >&2
  exit 1
fi

# Extract records
echo "$result" | jq '[.result.records[] | {Id: .Id, Name: .Name}]'
