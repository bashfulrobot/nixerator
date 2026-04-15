#!/usr/bin/env bash
set -euo pipefail

# Upload a file and link it to a Case as a ContentVersion.
# Usage: sfdc-attach-file.sh <case_id> <file_path>
# Output: JSON with {contentVersionId, success}

CASE_ID="${1:?Usage: sfdc-attach-file.sh <case_id> <file_path>}"
FILE_PATH="${2:?Usage: sfdc-attach-file.sh <case_id> <file_path>}"

API_VERSION="v62.0"

if [[ ! -f "$FILE_PATH" ]]; then
  jq -n --arg path "$FILE_PATH" '{error: ("File not found: " + $path)}' >&2
  exit 1
fi

# Check file size (base64 inflates ~33%, SFDC limit is 37.5MB)
FILE_SIZE=$(stat -c %s "$FILE_PATH")
MAX_SIZE=$((28 * 1024 * 1024)) # ~28MB raw -> ~37MB base64
if (( FILE_SIZE > MAX_SIZE )); then
  jq -n --arg size "$(( FILE_SIZE / 1024 / 1024 ))MB" '{error: ("File too large (" + $size + "). Max ~28MB for SFDC upload.")}' >&2
  exit 1
fi

FILENAME=$(basename "$FILE_PATH")
B64_CONTENT=$(base64 -w0 "$FILE_PATH")

BODY_FILE=$(mktemp /tmp/sf_attach_body_XXXXXX.json)
trap 'rm -f "$BODY_FILE"' EXIT

jq -n \
  --arg title "$FILENAME" \
  --arg path "$FILENAME" \
  --arg data "$B64_CONTENT" \
  --arg caseId "$CASE_ID" \
  '{
    Title: $title,
    PathOnClient: $path,
    VersionData: $data,
    FirstPublishLocationId: $caseId
  }' > "$BODY_FILE"

result=$(sf api request rest "/services/data/${API_VERSION}/sobjects/ContentVersion" \
  -X POST \
  -b "@${BODY_FILE}" \
  -H "Content-Type:application/json" 2>&1) || {
  jq -n '{error: "Failed to upload file"}' >&2
  exit 1
}

# Check for API errors
errors=$(echo "$result" | jq -r 'if type == "array" then .[0].message // empty elif .errors then .errors[0].message // empty else empty end' 2>/dev/null)
if [[ -n "$errors" ]]; then
  jq -n --arg msg "$errors" '{error: $msg}' >&2
  exit 1
fi

CV_ID=$(echo "$result" | jq -r '.id // "unknown"')

jq -n --arg id "$CV_ID" '{contentVersionId: $id, success: true}'
