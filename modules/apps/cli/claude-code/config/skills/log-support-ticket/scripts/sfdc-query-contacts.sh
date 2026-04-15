#!/usr/bin/env bash
set -euo pipefail

# Query contacts for a given Account.
# Usage: sfdc-query-contacts.sh <account_id>
# Output: JSON array of {Id, Name, Email, Title} objects

ACCOUNT_ID="${1:?Usage: sfdc-query-contacts.sh <account_id>}"

# Validate SFDC ID format (15 or 18 alphanumeric characters)
if [[ ! "$ACCOUNT_ID" =~ ^[a-zA-Z0-9]{15,18}$ ]]; then
  jq -n --arg msg "Invalid Account ID format: ${ACCOUNT_ID}" '{error: $msg}' >&2
  exit 1
fi

QUERY="SELECT Id, Name, Email, Title FROM Contact WHERE AccountId = '${ACCOUNT_ID}' ORDER BY Name LIMIT 50"

result=$(sf data query --query "$QUERY" --json 2>&1) || {
  jq -n '{error: "SOQL query failed"}' >&2
  exit 1
}

status=$(echo "$result" | jq -r '.status // 1')
if [[ "$status" != "0" ]]; then
  msg=$(echo "$result" | jq -r '.message // "Unknown error"')
  jq -n --arg msg "$msg" '{error: $msg}' >&2
  exit 1
fi

echo "$result" | jq '[.result.records[] | {Id: .Id, Name: .Name, Email: (.Email // ""), Title: (.Title // "")}]'
