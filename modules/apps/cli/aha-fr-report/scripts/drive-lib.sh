#!/usr/bin/env bash
# Shared Drive helpers for the per-customer FR report pipeline.
#
# Every file this pipeline touches lives inside Kong's "Customers" shared
# drive, which has a domainUsersOnly restriction (verified live: setting an
# "anyone with link" permission on a file inside it fails with
# teamDriveDomainUsersOnlyRestriction). That's why the pipeline is split into
# an internal Sheet (stays in this drive) and an external PDF export (also
# stored here for now, but meant to be pulled out and sent via email/Slack,
# not shared as a Drive link).
#
# Source this file; it defines functions, does not run anything itself.

CUSTOMERS_DRIVE_ID="0AICIzErH5ToSUk9PVA"

# Subfolder of <Customer>/CS/FRs that customer-facing PDF snapshots land in.
# The Sheet lives at the FRs root, alongside this folder.
PDF_REPORTS_FOLDER_NAME="Customer-PDF-Reports"

_q_escape() {
  # Escape a value for embedding in a Drive API `q` string literal.
  printf '%s' "$1" | sed "s/'/\\\\'/g"
}

# _folder_parent ID
# Prints the id of ID's first parent. A folder sitting directly at the root of
# the shared drive reports the drive id itself as its parent.
_folder_parent() {
  gws drive files get \
    --params "{\"fileId\":\"$1\",\"fields\":\"parents\",\"supportsAllDrives\":true}" 2>/dev/null |
    jq -r '.parents[0] // empty'
}

# find_customer_folder NAME
# Finds the customer folder with this exact name. Prints the folder id.
# Exits 3 if none found, 4 if more than one found (ambiguous).
#
# The drive is laid out as <drive root>/<region>/<customer>, so a real customer
# folder is always a grandchild of the drive root. The name search itself is
# drive-wide and would happily match a folder nested at any depth, so
# candidates are filtered to that depth before deciding. Without this guard a
# stray subfolder that happens to share a customer's name wins silently and the
# whole CS/FRs tree gets built inside it -- exactly what happened to Sony, whose
# real folder is "Sony Interactive" but which also contained a nested folder
# named "Sony Interactive Entertainment". Failing loudly here beats writing
# reports somewhere nobody looks.
find_customer_folder() {
  local name esc results candidates count id parent grandparent
  name="$1"
  esc="$(_q_escape "$name")"
  results="$(gws drive files list \
    --params "{\"q\":\"name = '${esc}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false\",\"fields\":\"files(id,name,parents)\",\"corpora\":\"drive\",\"driveId\":\"${CUSTOMERS_DRIVE_ID}\",\"supportsAllDrives\":true,\"includeItemsFromAllDrives\":true,\"pageSize\":10}" 2>/dev/null)"

  candidates=""
  while read -r id parent; do
    [[ -n "$id" ]] || continue
    grandparent="$(_folder_parent "$parent")"
    if [[ "$grandparent" == "$CUSTOMERS_DRIVE_ID" ]]; then
      candidates+="${id}"$'\n'
    fi
  done < <(echo "$results" | jq -r '.files[]? | "\(.id) \(.parents[0])"')

  count="$(echo -n "$candidates" | grep -c . || true)"
  if [[ "$count" -eq 0 ]]; then
    echo "ERROR: no folder named '${name}' found at <region>/<customer> level in the Customers shared drive." >&2
    if [[ "$(echo "$results" | jq '.files | length')" -gt 0 ]]; then
      echo "       A folder with that name exists but is nested deeper; the name in" >&2
      echo "       customers.txt must match the real customer folder, not a subfolder:" >&2
      echo "$results" | jq -r '.files[] | "  - \(.id) (parent \(.parents[0]))"' >&2
    fi
    return 3
  fi
  if [[ "$count" -gt 1 ]]; then
    echo "ERROR: ${count} customer folders named '${name}' found, ambiguous:" >&2
    echo "$candidates" | sed '/^$/d; s/^/  - /' >&2
    return 4
  fi
  echo -n "$candidates" | head -1
}

# find_or_create_subfolder PARENT_ID NAME
# Prints the subfolder id on stdout, creating it under PARENT_ID if missing.
find_or_create_subfolder() {
  local parent_id name esc results id
  parent_id="$1"
  name="$2"
  esc="$(_q_escape "$name")"
  results="$(gws drive files list \
    --params "{\"q\":\"name = '${esc}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false and '${parent_id}' in parents\",\"fields\":\"files(id,name)\",\"supportsAllDrives\":true,\"includeItemsFromAllDrives\":true,\"pageSize\":10}" 2>/dev/null)"
  id="$(echo "$results" | jq -r '.files[0].id // empty')"
  if [[ -n "$id" ]]; then
    echo "$id"
    return 0
  fi
  gws drive files create \
    --json "{\"name\":\"${name}\",\"mimeType\":\"application/vnd.google-apps.folder\",\"parents\":[\"${parent_id}\"]}" \
    --params '{"supportsAllDrives":true,"fields":"id"}' 2>/dev/null | jq -r '.id'
}

# find_file_in_folder PARENT_ID NAME MIME_TYPE
# Prints the file id on stdout if a file with this exact name+mimeType
# already exists directly under PARENT_ID, else prints nothing (empty).
find_file_in_folder() {
  local parent_id name mime esc results
  parent_id="$1"
  name="$2"
  mime="$3"
  esc="$(_q_escape "$name")"
  results="$(gws drive files list \
    --params "{\"q\":\"name = '${esc}' and mimeType = '${mime}' and trashed = false and '${parent_id}' in parents\",\"fields\":\"files(id,name)\",\"supportsAllDrives\":true,\"includeItemsFromAllDrives\":true,\"pageSize\":10}" 2>/dev/null)"
  echo "$results" | jq -r '.files[0].id // empty'
}

# resolve_customer_frs_folder CUSTOMER_NAME
# Resolves <Customer>/CS/FRs, plus the Customer-PDF-Reports subfolder inside it,
# creating any level that doesn't exist yet.
# Prints "customer_folder_id<TAB>frs_folder_id<TAB>pdf_reports_folder_id".
resolve_customer_frs_folder() {
  local customer_name cust_id cs_id frs_id pdf_id
  customer_name="$1"
  cust_id="$(find_customer_folder "$customer_name")" || return $?
  cs_id="$(find_or_create_subfolder "$cust_id" "CS")" || return 1
  frs_id="$(find_or_create_subfolder "$cs_id" "FRs")" || return 1
  pdf_id="$(find_or_create_subfolder "$frs_id" "$PDF_REPORTS_FOLDER_NAME")" || return 1
  printf '%s\t%s\t%s\n' "$cust_id" "$frs_id" "$pdf_id"
}

# resolve_customer_frs_only CUSTOMER_NAME
# Resolves <Customer>/CS/FRs but stops there -- it never touches the
# Customer-PDF-Reports subfolder. Used when the PDF destination is pinned to an
# explicit folder id (customers.txt field 4), so the run neither depends on nor
# recreates the in-drive PDF subfolder: the Sheet still lands in its original
# FRs folder (links preserved) while the PDF goes wherever field 4 points.
# Prints "customer_folder_id<TAB>frs_folder_id".
resolve_customer_frs_only() {
  local customer_name cust_id cs_id frs_id
  customer_name="$1"
  cust_id="$(find_customer_folder "$customer_name")" || return $?
  cs_id="$(find_or_create_subfolder "$cust_id" "CS")" || return 1
  frs_id="$(find_or_create_subfolder "$cs_id" "FRs")" || return 1
  printf '%s\t%s\n' "$cust_id" "$frs_id"
}

# resolve_pinned_pdf_siblings PDF_REPORTS_FOLDER_ID
# Given a pinned pdf-reports folder id (customers.txt field 4), derive the two
# sibling destinations in the same My Drive tree without needing any extra ids:
#   - its parent FRs folder, where the customer-facing Sheet copy lands, and
#   - a "csv-exports" subfolder of that FRs folder (created if missing), where
#     the customer-facing CSV lands.
# The tree is Customer/<Name>/FRs/{pdf-reports,csv-exports} with the Sheet copy
# at the FRs root (verified live). Unlike resolve_customer_frs_* this touches
# My Drive, not the Customers shared drive -- these are a separate, deliberately
# customer-facing bundle that leaves the internal shared-drive Sheet untouched.
# Prints "frs_id<TAB>csv_exports_id".
resolve_pinned_pdf_siblings() {
  local pdf_id frs_id csv_id
  pdf_id="$1"
  frs_id="$(_folder_parent "$pdf_id")"
  [[ -n "$frs_id" ]] || {
    echo "ERROR: could not resolve the parent FRs folder of pinned pdf-reports folder '${pdf_id}'." >&2
    return 1
  }
  csv_id="$(find_or_create_subfolder "$frs_id" "csv-exports")" || return 1
  printf '%s\t%s\n' "$frs_id" "$csv_id"
}
