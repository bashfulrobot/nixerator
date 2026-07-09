#!/usr/bin/env bash
# Run customer-fr-report.sh for every customer listed in customers.txt,
# continuing past per-customer failures so one bad org name or a transient
# Aha!/Drive error doesn't kill the whole scheduled run.
#
# Usage:
#   run-all.sh                     # uses ../customers.txt
#   run-all.sh /path/to/list.txt   # explicit list file

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
list_file="${1:-$here/../customers.txt}"

[[ -r "$list_file" ]] || {
  echo "ERROR: customer list not found/readable at $list_file" >&2
  exit 2
}

ok=0
failed=()

while IFS= read -r customer; do
  # Strip comments and blank lines.
  customer="${customer%%#*}"
  customer="$(echo "$customer" | xargs || true)"
  [[ -n "$customer" ]] || continue

  echo "=============================================="
  echo "Processing: ${customer}"
  echo "=============================================="
  if bash "$here/customer-fr-report.sh" "$customer"; then
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
