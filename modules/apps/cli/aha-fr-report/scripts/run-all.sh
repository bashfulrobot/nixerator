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
#   Drive folder name[|aha_org_id[,aha_org_id2,...]]
#
# The part before "|" must be the EXACT existing Drive folder name (also
# used as the Aha! search term when no org id is given). The optional part
# after "|" is one or more Aha idea-organization ids, forwarded as repeated
# --org flags -- see customer-fr-report.sh's own usage comment for when
# that's needed (Drive/Aha names diverge, or a plain search is ambiguous).

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
list_file="${1:-$here/../customers.txt}"

[[ -r "$list_file" ]] || {
  echo "ERROR: customer list not found/readable at $list_file" >&2
  exit 2
}

ok=0
failed=()

while IFS= read -r line; do
  # Strip comments and blank lines.
  line="${line%%#*}"
  line="$(echo "$line" | xargs || true)"
  [[ -n "$line" ]] || continue

  customer="${line%%|*}"
  org_ids="${line#"$customer"}"
  org_ids="${org_ids#|}"
  declare -a org_args=()
  if [[ -n "$org_ids" ]]; then
    IFS=',' read -ra _ids <<<"$org_ids"
    for id in "${_ids[@]}"; do
      [[ -n "$id" ]] && org_args+=("--org" "$id")
    done
  fi

  echo "=============================================="
  echo "Processing: ${customer}"
  echo "=============================================="
  if bash "$here/customer-fr-report.sh" "$customer" "${org_args[@]}"; then
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
