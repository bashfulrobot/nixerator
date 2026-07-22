#!/usr/bin/env bash
# Run customer-fr-report.sh for every customer listed in customers.txt,
# continuing past per-customer failures so one bad org name or a transient
# Aha!/Drive error doesn't kill the whole scheduled run.
#
# Usage:
#   run-all.sh                     # uses ../customers.txt
#   run-all.sh /path/to/list.txt   # explicit list file
#
# customers.txt line format:
#   Drive folder name[|aha_org_id[,aha_org_id2,...]][|Display Name][|pdf_folder_id]
#
# Field 1 must be the EXACT name of the customer's own folder at
# <region>/<customer> (also used as the Aha! search term when no org id is
# given). Field 2 is one or more Aha idea-organization ids, forwarded as
# repeated --org flags -- see customer-fr-report.sh's own usage comment for
# when that's needed (Drive/Aha names diverge, or a plain search is
# ambiguous). Field 3 overrides the customer-facing display name when the
# Drive folder isn't the customer's full name; it defaults to field 1. Field 4
# pins the customer-facing PDF to an explicit destination folder id (forwarded
# as --pdf-folder); the folder must already exist and the internal Sheet stays
# in its original FRs folder. All trailing fields are optional -- see
# customers.txt's own header. To leave an earlier field empty while setting a
# later one, use consecutive pipes (e.g. name|org||pdf_folder_id).

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
list_file="${1:-$here/../customers.txt}"

[[ -r "$list_file" ]] || {
  echo "ERROR: customer list not found/readable at $list_file" >&2
  exit 2
}

ok=0
failed=()

# Strip leading/trailing whitespace. Done with parameter expansion rather than
# `xargs`, which also does quote processing: a name with an apostrophe in it
# ("Moody's") is an unmatched quote to xargs, which errors out and leaves the
# field empty -- silently skipping that customer instead of failing loudly.
_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

while IFS= read -r line; do
  # Strip comments and blank lines.
  line="${line%%#*}"
  [[ -n "$(_trim "$line")" ]] || continue

  IFS='|' read -r customer org_ids display_name pdf_folder <<<"$line"
  customer="$(_trim "$customer")"
  org_ids="$(_trim "${org_ids:-}")"
  display_name="$(_trim "${display_name:-}")"
  pdf_folder="$(_trim "${pdf_folder:-}")"
  [[ -n "$customer" ]] || continue

  declare -a org_args=()
  if [[ -n "$org_ids" ]]; then
    IFS=',' read -ra _ids <<<"$org_ids"
    for id in "${_ids[@]}"; do
      id="$(_trim "$id")"
      [[ -n "$id" ]] && org_args+=("--org" "$id")
    done
  fi

  declare -a display_args=()
  if [[ -n "$display_name" ]]; then
    display_args=(--display-name "$display_name")
  fi

  declare -a pdf_args=()
  if [[ -n "$pdf_folder" ]]; then
    pdf_args=(--pdf-folder "$pdf_folder")
  fi

  echo "=============================================="
  echo "Processing: ${customer}"
  echo "=============================================="
  if bash "$here/customer-fr-report.sh" "$customer" \
    ${display_args[@]+"${display_args[@]}"} ${pdf_args[@]+"${pdf_args[@]}"} ${org_args[@]+"${org_args[@]}"}; then
    ok=$((ok + 1))
  else
    echo "FAILED: ${customer}" >&2
    failed+=("$customer")
  fi
  echo
done <"$list_file"

echo "=============================================="
echo "Done: ${ok} succeeded, ${#failed[@]} failed."
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi
