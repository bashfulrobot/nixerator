#!/usr/bin/env bash
set -euo pipefail

# Create a Case record in SFDC via REST API.
# Reads field values from environment variables.
#
# Required env vars:
#   CASE_SUBJECT       - Case subject line
#   CASE_DESCRIPTION   - Full description body
#   CASE_PRIORITY      - Priority picklist value
#   CASE_ACCOUNT_ID    - Account Id (18-char SFDC Id)
#   CASE_CONTACT_ID    - Contact Id (18-char SFDC Id)
#   CASE_PRODUCT_TYPE  - Product_Type__c picklist value
#
# Optional env vars:
#   CASE_SLACK_THREAD  - Slack thread URL
#
# Output: JSON with {id, caseNumber, url}

: "${CASE_SUBJECT:?CASE_SUBJECT is required}"
: "${CASE_DESCRIPTION:?CASE_DESCRIPTION is required}"
: "${CASE_PRIORITY:?CASE_PRIORITY is required}"
: "${CASE_ACCOUNT_ID:?CASE_ACCOUNT_ID is required}"
: "${CASE_CONTACT_ID:?CASE_CONTACT_ID is required}"
: "${CASE_PRODUCT_TYPE:?CASE_PRODUCT_TYPE is required}"

SFDC_INSTANCE="https://kong.lightning.force.com"
API_VERSION="v62.0"
DESC_MAX_LENGTH=32000

# --- Pre-flight checks ---

# 1. Description length check
desc_length=${#CASE_DESCRIPTION}
if ((desc_length > DESC_MAX_LENGTH)); then
  jq -n --arg len "$desc_length" --arg max "$DESC_MAX_LENGTH" \
    '{error: ("Description is " + $len + " characters, exceeding the " + $max + " character SFDC limit. Shorten the description and retry.")}' >&2
  exit 1
fi

# 2. Validate Account ID exists
account_check=$(sf data query \
  --query "SELECT Id, Name FROM Account WHERE Id = '${CASE_ACCOUNT_ID}' LIMIT 1" \
  --json 2>/dev/null) || {
  jq -n --arg id "$CASE_ACCOUNT_ID" '{error: ("Failed to validate Account ID: " + $id)}' >&2
  exit 1
}
account_count=$(echo "$account_check" | jq -r '.result.totalSize // 0')
if [[ "$account_count" -eq 0 ]]; then
  jq -n --arg id "$CASE_ACCOUNT_ID" '{error: ("Account not found: " + $id)}' >&2
  exit 1
fi

# 3. Validate Contact ID exists and belongs to the Account
contact_check=$(sf data query \
  --query "SELECT Id, Name FROM Contact WHERE Id = '${CASE_CONTACT_ID}' AND AccountId = '${CASE_ACCOUNT_ID}' LIMIT 1" \
  --json 2>/dev/null) || {
  jq -n --arg id "$CASE_CONTACT_ID" '{error: ("Failed to validate Contact ID: " + $id)}' >&2
  exit 1
}
contact_count=$(echo "$contact_check" | jq -r '.result.totalSize // 0')
if [[ "$contact_count" -eq 0 ]]; then
  jq -n --arg cid "$CASE_CONTACT_ID" --arg aid "$CASE_ACCOUNT_ID" \
    '{error: ("Contact " + $cid + " not found or does not belong to Account " + $aid)}' >&2
  exit 1
fi

# 4. Duplicate detection — abort if a case with the same Subject + Account was created in the last hour
escaped_subject=$(echo "$CASE_SUBJECT" | sed "s/'/''/g")
dupe_check=$(sf data query \
  --query "SELECT Id, CaseNumber, CreatedDate FROM Case WHERE AccountId = '${CASE_ACCOUNT_ID}' AND Subject = '${escaped_subject}' AND CreatedDate = LAST_N_HOURS:1 LIMIT 1" \
  --json 2>/dev/null) || true
dupe_count=$(echo "$dupe_check" | jq -r '.result.totalSize // 0' 2>/dev/null)
if [[ "$dupe_count" -gt 0 ]]; then
  dupe_id=$(echo "$dupe_check" | jq -r '.result.records[0].Id')
  dupe_number=$(echo "$dupe_check" | jq -r '.result.records[0].CaseNumber')
  jq -n \
    --arg id "$dupe_id" \
    --arg num "$dupe_number" \
    --arg url "${SFDC_INSTANCE}/lightning/r/Case/${dupe_id}/view" \
    '{error: "Duplicate case detected", existing: {id: $id, caseNumber: $num, url: $url}}' >&2
  exit 1
fi

# --- Create the Case ---

# Build JSON body with jq (handles all escaping)
BODY_FILE=$(mktemp /tmp/sf_case_body_XXXXXX.json)
trap 'rm -f "$BODY_FILE"' EXIT

jq -n \
  --arg subject "$CASE_SUBJECT" \
  --arg desc "$CASE_DESCRIPTION" \
  --arg priority "$CASE_PRIORITY" \
  --arg accountId "$CASE_ACCOUNT_ID" \
  --arg contactId "$CASE_CONTACT_ID" \
  --arg productType "$CASE_PRODUCT_TYPE" \
  --arg slackThread "${CASE_SLACK_THREAD:-}" \
  '{
    Subject: $subject,
    Description: $desc,
    Priority: $priority,
    AccountId: $accountId,
    ContactId: $contactId,
    Product_Type__c: $productType,
    Status: "New",
    Origin: "Web"
  } + (if $slackThread != "" then {Slack_Thread__c: $slackThread} else {} end)' \
  >"$BODY_FILE"

# Create the Case (stderr kept separate so CLI warnings don't corrupt JSON)
create_result=$(sf api request rest "/services/data/${API_VERSION}/sobjects/Case" \
  -X POST \
  -b "@${BODY_FILE}" \
  -H "Content-Type:application/json" 2>/dev/null) || {
  jq -n '{error: "Failed to create Case"}' >&2
  exit 1
}

# Check for API errors
errors=$(echo "$create_result" | jq -r 'if type == "array" then .[0].message // empty elif .errors then .errors[0].message // empty else empty end' 2>/dev/null)
if [[ -n "$errors" ]]; then
  jq -n --arg msg "$errors" '{error: $msg}' >&2
  exit 1
fi

CASE_ID=$(echo "$create_result" | jq -r '.id')
if [[ -z "$CASE_ID" || "$CASE_ID" == "null" ]]; then
  jq -n '{error: "No Case Id returned from creation"}' >&2
  exit 1
fi

# Query back the CaseNumber (not returned by the POST)
number_result=$(sf data query \
  --query "SELECT CaseNumber FROM Case WHERE Id = '${CASE_ID}'" \
  --json 2>/dev/null) || {
  # Case was created but we couldn't get the number -- still report success
  echo "{\"id\":\"${CASE_ID}\",\"caseNumber\":\"unknown\",\"url\":\"${SFDC_INSTANCE}/lightning/r/Case/${CASE_ID}/view\"}"
  exit 0
}

CASE_NUMBER=$(echo "$number_result" | jq -r '.result.records[0].CaseNumber // "unknown"')

jq -n \
  --arg id "$CASE_ID" \
  --arg num "$CASE_NUMBER" \
  --arg url "${SFDC_INSTANCE}/lightning/r/Case/${CASE_ID}/view" \
  '{id: $id, caseNumber: $num, url: $url}'
