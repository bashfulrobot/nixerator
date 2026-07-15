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
# Columns written: State, Ref, Idea, Status, Stack Rank, Use Case,
# Requester, Team (the requester's configured team, derived from
# upsight's contacts.team_id -> teams.id -> teams.team_name -- not a
# free-text field, blank if the requester has no team set or there is no
# requester), Production Blocker, Target Release, Notes (all from
# upsight, blank if untracked -- see fetch-ideas.sh and
# idea-tracking-lookup.sh), Aha Link (the idea's own public link, shown as
# "View idea"), Proxy Vote Link (this customer's own org page in Aha, shown
# as "View proxy"), Source Link (where the request was first gathered, e.g.
# a customer Slack thread, shown as "Customer thread"), and Internal
# Discussion Link (the separate Kong-internal Slack thread about the
# request, shown as "Internal thread"). All four link columns are
# HYPERLINK() formulas (values written with USER_ENTERED, not RAW, so
# Sheets evaluates them) rather than bare URLs. The header row is bolded,
# shaded, and frozen, and columns are auto-width (recomputed from the
# actual column count every run) -- reapplied on every run (idempotent),
# not just on first creation. Row order (Open first, ranked-then-unranked
# within each state) comes from fetch-ideas.sh -- see that script for
# details; Closed rows land as one contiguous block at the bottom, which
# the row-group collapse below relies on.
#
# Row 1 is a "Last updated" timestamp banner (UTC, set when the script
# runs), merged across all columns, above the frozen header row -- so
# anyone opening the Sheet can tell at a glance how fresh the data is
# without checking Drive's file-revision metadata.
#
# Requires: gws (authenticated), fetch-ideas.sh (and in turn
# customer-ideas.sh, AHA_API_TOKEN), jq.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH_IDEAS="$here/fetch-ideas.sh"
source "$here/drive-lib.sh"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

customer_name="${1:?usage: write-customer-sheet.sh CUSTOMER_NAME FRS_FOLDER_ID [--org ID ...]}"
frs_folder_id="${2:?usage: write-customer-sheet.sh CUSTOMER_NAME FRS_FOLDER_ID [--org ID ...]}"
shift 2

[[ -x "$FETCH_IDEAS" ]] || die "fetch-ideas.sh not found/executable at $FETCH_IDEAS"
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

# --- Step 2: pull the customer's ideas from Aha!, with Stack Rank ----------
echo "Pulling ideas for ${customer_name} from Aha!..." >&2
# customer-ideas.sh (called inside fetch-ideas.sh) ignores $customer_name for
# search purposes once any --org is present (see its own arg parsing), so
# it's safe to always pass both -- --org just takes precedence.
ideas_json="$("$FETCH_IDEAS" "$customer_name" "$@")"
n="$(echo "$ideas_json" | jq 'length')"
echo "Got ${n} idea(s)." >&2

# --- Step 3: build the 2D values array (timestamp banner + header + rows) --
# fetch-ideas.sh already returns ideas sorted open-first/closed-last, ranked
# ascending within each state -- Closed rows land as one contiguous block
# at the bottom, which Step 5 relies on to group/collapse them.
timestamp="$(date -u +'%Y-%m-%d %H:%M UTC')"
timestamp_row="$(jq -n --arg t "Last updated: ${timestamp}" '[$t]')"
header='["State","Ref","Idea","Status","Stack Rank","Use Case","Requester","Team","Production Blocker","Target Release","Notes","Aha Link","Proxy Vote Link","Source Link","Internal Discussion Link"]'
open_count="$(echo "$ideas_json" | jq '[.[] | select(.state == "open")] | length')"
closed_count="$(echo "$ideas_json" | jq '[.[] | select(.state != "open")] | length')"
rows="$(echo "$ideas_json" | jq --argjson header "$header" --argjson timestamp_row "$timestamp_row" '
  [$timestamp_row, $header] + (
    map([
      (if .state == "open" then "Open" else "Closed" end),
      .ref,
      .name,
      .status,
      (.rank // ""),
      (.use_case // ""),
      (.requester_name // ""),
      (.team_name // ""),
      (if .production_blocker == 1 then "Yes" elif .production_blocker == 0 then "No" else "" end),
      (.target_release // ""),
      (.notes // ""),
      (if (.url // "") != "" then "=HYPERLINK(\"\(.url)\",\"View idea\")" else "" end),
      (if (.org_url // "") != "" then "=HYPERLINK(\"\(.org_url)\",\"View proxy\")" else "" end),
      (if (.source_url // "") != "" then "=HYPERLINK(\"\(.source_url)\",\"Customer thread\")" else "" end),
      (if (.internal_discussion_url // "") != "" then "=HYPERLINK(\"\(.internal_discussion_url)\",\"Internal thread\")" else "" end)
    ])
  )
')"

# --- Step 4: clear the old range, then write the new one -------------------
echo "Writing to sheet..." >&2
gws sheets spreadsheets values clear \
  --params "{\"spreadsheetId\":\"${sheet_id}\",\"range\":\"A1:Z1000\"}" \
  --json '{}' >/dev/null 2>&1 || true

update_body="$(jq -n --argjson values "$rows" '{valueInputOption:"USER_ENTERED", data:[{range:"A1", majorDimension:"ROWS", values:$values}]}')"
gws sheets spreadsheets values batchUpdate \
  --params "{\"spreadsheetId\":\"${sheet_id}\"}" \
  --json "$update_body" >/dev/null

# --- Step 5: formatting -- timestamp banner, bold+frozen header, banded
# (zebra) rows, auto-width columns, Closed rows collapsed into a
# hidden-by-default group, Kong-lime tab color. Idempotent, so it's cheap to
# just reapply on every run rather than only on sheet creation. Existing
# merges/bandings/row-groups are deleted and recreated each time rather than
# reused, since the exact row/column range shifts as the idea count or
# column count changes run to run.
#
# header_offset accounts for the two banner+header rows above the data
# (row 0 = timestamp banner, row 1 = column header) -- every row index
# below that used to reference open/closed data is shifted by it.
echo "Applying formatting..." >&2
n_cols="$(echo "$header" | jq 'length')"
header_offset=2
sheet_state="$(gws sheets spreadsheets get \
  --params "{\"spreadsheetId\":\"${sheet_id}\",\"fields\":\"sheets.properties,sheets.bandedRanges,sheets.rowGroups,sheets.merges\"}" 2>/dev/null |
  jq '.sheets[0]')"
grid_sheet_id="$(echo "$sheet_state" | jq '.properties.sheetId')"

format_body="$(jq -n \
  --argjson gsid "$grid_sheet_id" \
  --argjson n_cols "$n_cols" \
  --argjson open_count "$open_count" \
  --argjson closed_count "$closed_count" \
  --argjson header_offset "$header_offset" \
  --argjson state "$sheet_state" \
  '
  ($state.bandedRanges // [] | map({deleteBanding: {bandedRangeId: .bandedRangeId}})) as $delete_bandings
  | ($state.rowGroups // [] | map({deleteDimensionGroup: {range: (.range + {dimension: "ROWS"})}})) as $delete_groups
  | ($state.merges // [] | map({unmergeCells: {range: .}})) as $delete_merges
  | [
      {
        mergeCells: {
          range: {sheetId: $gsid, startRowIndex: 0, endRowIndex: 1, startColumnIndex: 0, endColumnIndex: $n_cols},
          mergeType: "MERGE_ALL"
        }
      },
      {
        repeatCell: {
          range: {sheetId: $gsid, startRowIndex: 0, endRowIndex: 1},
          cell: {userEnteredFormat: {textFormat: {italic: true, foregroundColor: {red: 0.522, green: 0.537, blue: 0.514}}}},
          fields: "userEnteredFormat(textFormat)"
        }
      },
      {
        repeatCell: {
          range: {sheetId: $gsid, startRowIndex: 1, endRowIndex: 2},
          cell: {userEnteredFormat: {textFormat: {bold: true}}},
          fields: "userEnteredFormat(textFormat)"
        }
      },
      {
        updateSheetProperties: {
          properties: {sheetId: $gsid, gridProperties: {frozenRowCount: $header_offset}, tabColor: {red: 0.8, green: 1.0, blue: 0.0}},
          fields: "gridProperties.frozenRowCount,tabColor"
        }
      },
      {
        autoResizeDimensions: {
          dimensions: {sheetId: $gsid, dimension: "COLUMNS", startIndex: 0, endIndex: $n_cols}
        }
      },
      {
        addBanding: {
          bandedRange: {
            range: {sheetId: $gsid, startRowIndex: 1, endRowIndex: ($header_offset + $open_count + $closed_count), startColumnIndex: 0, endColumnIndex: $n_cols},
            rowProperties: {
              headerColor: {red: 0.843, green: 0.871, blue: 0.831},
              firstBandColor: {red: 1, green: 1, blue: 1},
              secondBandColor: {red: 0.906, green: 0.929, blue: 0.898}
            }
          }
        }
      }
    ] as $format_requests
  | (if $closed_count > 0 then [
        {
          addDimensionGroup: {
            range: {sheetId: $gsid, dimension: "ROWS", startIndex: ($header_offset + $open_count), endIndex: ($header_offset + $open_count + $closed_count)}
          }
        },
        {
          updateDimensionGroup: {
            dimensionGroup: {
              range: {sheetId: $gsid, dimension: "ROWS", startIndex: ($header_offset + $open_count), endIndex: ($header_offset + $open_count + $closed_count)},
              depth: 1,
              collapsed: true
            },
            fields: "collapsed"
          }
        }
      ] else [] end) as $group_requests
  | {requests: ($delete_merges + $delete_bandings + $delete_groups + $format_requests + $group_requests)}
  ')"

# The jq above intentionally reorders so every delete*/unmerge* request runs
# before any add*/repeatCell/etc -- deleting a stale merge/banding/group
# after re-adding a new one at an overlapping range is what triggers
# "already grouped" (or overlapping-merge) errors from the Sheets API.
gws sheets spreadsheets batchUpdate \
  --params "{\"spreadsheetId\":\"${sheet_id}\"}" \
  --json "$format_body" >/dev/null 2>&1 || echo "  (formatting failed, non-fatal -- data is still written)" >&2

sheet_url="https://docs.google.com/spreadsheets/d/${sheet_id}/edit"
printf '%s\t%s\n' "$sheet_id" "$sheet_url"
echo "Done: ${sheet_url}" >&2
