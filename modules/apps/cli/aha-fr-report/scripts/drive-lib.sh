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
  #
  # Drive's query grammar honours backslash escapes inside a single-quoted
  # literal, so the backslash has to be doubled before the quote is escaped.
  # Skip that and a value ending in a backslash emits `name = 'foo\'`, where
  # the trailing backslash escapes the closing quote and the rest of the query
  # is swallowed into the string.
  #
  # What comes back is the `q` *value*, not JSON. Callers must hand it to
  # `jq --arg` so the backslashes and quotes are JSON-escaped on the way into
  # the request body. A `\'` pasted straight into a JSON string is not valid
  # JSON (there is no such escape), which is why every body below is built by
  # jq rather than by interpolating into a here-string.
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"
}

# _drive_list PARAMS_JSON DESCRIPTION
# Runs `gws drive files list` and prints the raw response. Returns 1 when the
# lookup itself failed, which is deliberately distinct from a lookup that
# succeeded and matched nothing.
#
# Keeping those two apart is the whole point. gws writes its backend banner to
# stderr, so stderr has to be dropped, and every caller here used to drop the
# exit status along with it and read a rate limit or a token hiccup as "no such
# file". For upload_or_replace_file that turns a transient error into a second
# copy of a customer-facing report, since the create branch is what runs when
# nothing is found. Verified live: a query matching nothing returns
# {"files": []} and exits 0, while a malformed one returns an {"error": ...}
# body and exits 1.
_drive_list() {
  local params desc results
  params="$1"
  desc="$2"
  results="$(gws drive files list --params "$params" 2>/dev/null)" || {
    echo "ERROR: Drive lookup failed (${desc}); treating as an error rather than as 'not found'." >&2
    return 1
  }
  jq -e 'type == "object" and has("files")' <<<"$results" >/dev/null 2>&1 || {
    echo "ERROR: Drive lookup returned an unexpected response (${desc}): ${results}" >&2
    return 1
  }
  printf '%s\n' "$results"
}

# _folder_parent ID
# Prints the id of ID's first parent. A folder sitting directly at the root of
# the shared drive reports the drive id itself as its parent.
# Returns 1 if the lookup failed, so a caller cannot read an API error as
# "this folder has no parent".
_folder_parent() {
  local response
  response="$(gws drive files get \
    --params "$(jq -n --arg id "$1" '{fileId: $id, fields: "parents", supportsAllDrives: true}')" 2>/dev/null)" || {
    echo "ERROR: could not read the parents of '$1'." >&2
    return 1
  }
  jq -r '.parents[0] // empty' <<<"$response"
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
  local name params results candidates count id parent grandparent
  name="$1"
  params="$(jq -n \
    --arg q "name = '$(_q_escape "$name")' and mimeType = 'application/vnd.google-apps.folder' and trashed = false" \
    --arg drive "$CUSTOMERS_DRIVE_ID" \
    '{q: $q, fields: "files(id,name,parents)", corpora: "drive", driveId: $drive, supportsAllDrives: true, includeItemsFromAllDrives: true, pageSize: 10}')"
  results="$(_drive_list "$params" "customer folder '${name}'")" || return 1

  candidates=""
  while read -r id parent; do
    [[ -n "$id" ]] || continue
    grandparent="$(_folder_parent "$parent")" || return 1
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
  local parent_id name params results id created
  parent_id="$1"
  name="$2"
  params="$(jq -n \
    --arg q "name = '$(_q_escape "$name")' and mimeType = 'application/vnd.google-apps.folder' and trashed = false and '$(_q_escape "$parent_id")' in parents" \
    '{q: $q, fields: "files(id,name)", supportsAllDrives: true, includeItemsFromAllDrives: true, pageSize: 10}')"
  results="$(_drive_list "$params" "subfolder '${name}' under '${parent_id}'")" || return 1
  id="$(jq -r '.files[0].id // empty' <<<"$results")"
  if [[ -n "$id" ]]; then
    printf '%s\n' "$id"
    return 0
  fi
  # The create used to pipe straight into `jq -r '.id'`, which exits 0 and
  # prints "null" when the API returns an error body, so a failed create handed
  # the string "null" back as a folder id and every write underneath it went
  # somewhere that does not exist. Check the status and the id separately.
  created="$(gws drive files create \
    --json "$(jq -n --arg name "$name" --arg parent "$parent_id" \
      '{name: $name, mimeType: "application/vnd.google-apps.folder", parents: [$parent]}')" \
    --params '{"supportsAllDrives":true,"fields":"id"}' 2>/dev/null)" || {
    echo "ERROR: could not create subfolder '${name}' under '${parent_id}'." >&2
    return 1
  }
  id="$(jq -r '.id // empty' <<<"$created" 2>/dev/null)"
  [[ -n "$id" ]] || {
    echo "ERROR: creating subfolder '${name}' under '${parent_id}' returned no id: ${created}" >&2
    return 1
  }
  printf '%s\n' "$id"
}

# find_file_in_folder PARENT_ID NAME MIME_TYPE
# Prints the file id on stdout if a file with this exact name+mimeType
# already exists directly under PARENT_ID, else prints nothing (empty).
# Returns 1 if the lookup failed, so an empty result always means "not there"
# rather than "could not tell".
find_file_in_folder() {
  local parent_id name mime params results
  parent_id="$1"
  name="$2"
  mime="$3"
  params="$(jq -n \
    --arg q "name = '$(_q_escape "$name")' and mimeType = '$(_q_escape "$mime")' and trashed = false and '$(_q_escape "$parent_id")' in parents" \
    '{q: $q, fields: "files(id,name)", supportsAllDrives: true, includeItemsFromAllDrives: true, pageSize: 10}')"
  results="$(_drive_list "$params" "file '${name}' in folder '${parent_id}'")" || return 1
  jq -r '.files[0].id // empty' <<<"$results"
}

# upload_or_replace_file PARENT_ID NAME MIME_TYPE LOCAL_PATH
# Uploads LOCAL_PATH into PARENT_ID under NAME, replacing the contents of an
# existing file of the same name+mimeType rather than adding a second copy.
# Prints "file_id<TAB>webViewLink".
#
# Drive permits duplicate names within a folder, so a bare `files create` is not
# idempotent: a second run on the same day leaves two files carrying the same
# dated name. That matters because the scheduled unit retries on failure and
# these folders are customer-facing, so a create-only upload turns one transient
# error into a stack of identical reports someone else has to clean up.
# Replacing in place also keeps the file id stable, so a link already handed to
# a customer keeps resolving to the current report.
upload_or_replace_file() {
  local parent_id name mime path params results existing matched result id
  parent_id="$1"
  name="$2"
  mime="$3"
  path="$4"

  # This does its own lookup rather than calling find_file_in_folder, because
  # deciding *which* file to overwrite is a trust decision and an id alone is
  # not enough to make it. Matching on name and mimeType only means anyone who
  # can write into one of these folders can pre-create an empty file under the
  # dated name this run is about to use; the run would then push the report
  # into their file. They keep ownership, so they control its sharing, and the
  # webViewLink printed below and handed onward points at their object. The
  # pinned destinations in customers.txt field 4 live in My Drive rather than
  # in the domainUsersOnly-restricted Customers shared drive, so that is not a
  # hypothetical.
  #
  # Overwrite only a file this account owns, or one held by a shared drive.
  # Drive does not populate ownedByMe for shared-drive items (access there is
  # governed by drive membership, not by a file owner), so driveId is what
  # stands in for ownership on that side.
  params="$(jq -n \
    --arg q "name = '$(_q_escape "$name")' and mimeType = '$(_q_escape "$mime")' and trashed = false and '$(_q_escape "$parent_id")' in parents" \
    '{q: $q, fields: "files(id,ownedByMe,driveId)", supportsAllDrives: true, includeItemsFromAllDrives: true, pageSize: 10}')"
  results="$(_drive_list "$params" "existing '${name}' in folder '${parent_id}'")" || return 1

  existing="$(jq -r '[.files[]? | select(.ownedByMe == true or (.driveId // "") != "") | .id][0] // empty' <<<"$results")"
  matched="$(jq '[.files[]?] | length' <<<"$results")"
  if [[ -z "$existing" && "$matched" -gt 0 ]]; then
    echo "ERROR: '${name}' already exists in folder '${parent_id}' but is owned by someone else." >&2
    echo "       Refusing to overwrite it, since that would leave the report inside a file" >&2
    echo "       this account does not control. Remove or rename the foreign copy, then rerun." >&2
    return 1
  fi

  if [[ -n "$existing" ]]; then
    result="$(gws drive files update \
      --params "$(jq -n --arg id "$existing" \
        '{fileId: $id, supportsAllDrives: true, fields: "id,webViewLink"}')" \
      --upload "$path" \
      --upload-content-type "$mime" 2>/dev/null)" || result=""
  else
    result="$(gws drive files create \
      --json "$(jq -n --arg name "$name" --arg parent "$parent_id" \
        '{name: $name, parents: [$parent]}')" \
      --upload "$path" \
      --upload-content-type "$mime" \
      --params '{"supportsAllDrives":true,"fields":"id,webViewLink"}' 2>/dev/null)" || result=""
  fi

  id="$(jq -r '.id // empty' <<<"$result" 2>/dev/null)"
  [[ -n "$id" ]] || {
    echo "ERROR: upload of '${name}' failed: ${result}" >&2
    return 1
  }
  printf '%s\t%s\n' "$id" "$(jq -r '.webViewLink // empty' <<<"$result")"
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
