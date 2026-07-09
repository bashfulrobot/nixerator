#!/usr/bin/env bash
# Write a customer's Aha! feature requests into their internal FRs Google
# Sheet, creating the Sheet the first time and overwriting the data range on
# every subsequent run.
#
# Usage:
#   write-customer-sheet.sh "HealthEquity" <frs_folder_id> [--org ID ...]
#
# CUSTOMER_NAME is used for the Sheet title and (unless --org overrides it)
# as the Aha! search term. Pass one or more --org ID when the Drive folder
# name and the Aha idea-organization name/id diverge, or when a plain name
# search would be ambiguous (see customer-ideas.sh --org). Repeatable.
#
# Prints "sheet_id<TAB>sheet_url" on stdout when done.
#
# Requires: gws (authenticated), the aha skill's customer-ideas.sh,
# AHA_API_TOKEN, jq.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AHA_CUSTOMER_IDEAS="$here/../vendor/customer-ideas.sh"
source "$here/drive-lib.sh"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

customer_name="${1:?usage: write-customer-sheet.sh CUSTOMER_NAME FRS_FOLDER_ID [--org ID ...]}"
frs_folder_id="${2:?usage: write-customer-sheet.sh CUSTOMER_NAME FRS_FOLDER_ID [--org ID ...]}"
shift 2

[[ -x "$AHA_CUSTOMER_IDEAS" ]] || die "customer-ideas.sh not found/executable at $AHA_CUSTOMER_IDEAS"
command -v jq >/dev/null 2>&1 || die "'jq' is required but not on PATH"

sheet_name="${customer_name} - Feature Requests"

# --- Step 1: find or create the Sheet, reusing it across runs -------------
sheet_id="$(find_file_in_folder "$frs_folder_id" "$sheet_name" "application/vnd.google-apps.spreadsheet")"
if [[ -z "$sheet_id" ]]; then
  echo "Creating new sheet '${sheet_name}'..." >&2
  sheet_id="$(gws drive files create \
    --json "{\"name\":\"${sheet_name}\",\"mimeType\":\"application/vnd.google-apps.spreadsheet\",\"parents\":[\"${frs_folder_id}\"]}" \
    --params '{"supportsAllDrives":true,"fields":"id"}' 2>/dev/null | jq -r '.id')"
  [[ -n "$sheet_id" && "$sheet_id" != "null" ]] || die "failed to create sheet"
else
  echo "Reusing existing sheet ${sheet_id}" >&2
fi

# --- Step 2: pull the customer's ideas from Aha! ---------------------------
echo "Pulling ideas for ${customer_name} from Aha!..." >&2
# customer-ideas.sh ignores $customer_name for search purposes once any
# --org is present (see its own arg parsing), so it's safe to always pass
# both -- --org just takes precedence.
ideas_json="$("$AHA_CUSTOMER_IDEAS" "$customer_name" --json "$@")"
n="$(echo "$ideas_json" | jq 'length')"
echo "Got ${n} idea(s)." >&2

# --- Step 3: build the 2D values array (header + rows) --------------------
header='["State","Ref","Idea","Status","Customer Votes","Customer Weight","Total Endorsements","Aha Link"]'
rows="$(echo "$ideas_json" | jq --argjson header "$header" '
  [$header] + (
    map([
      (if .state == "open" then "Open" else "Closed" end),
      .ref,
      .name,
      .status,
      .cust_votes,
      .cust_weight,
      .total_endorsements,
      (.url // "")
    ])
  )
')"

# --- Step 4: clear the old range, then write the new one -------------------
echo "Writing to sheet..." >&2
gws sheets spreadsheets values clear \
  --params "{\"spreadsheetId\":\"${sheet_id}\",\"range\":\"A1:Z1000\"}" \
  --json '{}' >/dev/null 2>&1 || true

update_body="$(jq -n --argjson values "$rows" '{valueInputOption:"RAW", data:[{range:"A1", majorDimension:"ROWS", values:$values}]}')"
gws sheets spreadsheets values batchUpdate \
  --params "{\"spreadsheetId\":\"${sheet_id}\"}" \
  --json "$update_body" >/dev/null

sheet_url="https://docs.google.com/spreadsheets/d/${sheet_id}/edit"
printf '%s\t%s\n' "$sheet_id" "$sheet_url"
echo "Done: ${sheet_url}" >&2
