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

_q_escape() {
  # Escape a value for embedding in a Drive API `q` string literal.
  printf '%s' "$1" | sed "s/'/\\\\'/g"
}

# find_customer_folder NAME
# Searches the whole Customers shared drive (any region subfolder) for a
# top-level-ish folder with this exact name. Prints the folder id on stdout.
# Exits 3 if none found, 4 if more than one found (ambiguous).
find_customer_folder() {
  local name esc results count
  name="$1"
  esc="$(_q_escape "$name")"
  results="$(gws drive files list \
    --params "{\"q\":\"name = '${esc}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false\",\"fields\":\"files(id,name,parents)\",\"corpora\":\"drive\",\"driveId\":\"${CUSTOMERS_DRIVE_ID}\",\"supportsAllDrives\":true,\"includeItemsFromAllDrives\":true,\"pageSize\":10}" 2>/dev/null)"
  count="$(echo "$results" | jq '.files | length')"
  if [[ "$count" -eq 0 ]]; then
    echo "ERROR: no folder named '${name}' found in the Customers shared drive." >&2
    return 3
  fi
  if [[ "$count" -gt 1 ]]; then
    echo "ERROR: ${count} folders named '${name}' found in the Customers shared drive, ambiguous:" >&2
    echo "$results" | jq -r '.files[] | "  - \(.id)"' >&2
    return 4
  fi
  echo "$results" | jq -r '.files[0].id'
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
# Prints "customer_folder_id<TAB>frs_folder_id<TAB>exports_folder_id".
resolve_customer_frs_folder() {
  local customer_name cust_id cs_id frs_id exports_id
  customer_name="$1"
  cust_id="$(find_customer_folder "$customer_name")" || return $?
  cs_id="$(find_or_create_subfolder "$cust_id" "CS")" || return 1
  frs_id="$(find_or_create_subfolder "$cs_id" "FRs")" || return 1
  exports_id="$(find_or_create_subfolder "$frs_id" "exports")" || return 1
  printf '%s\t%s\t%s\n' "$cust_id" "$frs_id" "$exports_id"
}
