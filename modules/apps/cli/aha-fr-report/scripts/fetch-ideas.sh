#!/usr/bin/env bash
# Shared idea-fetch step for write-customer-sheet.sh and
# export-customer-pdf.sh: pulls a customer's assessed Aha! ideas, then
# annotates each with its upsight-go Stack Rank (if any), so the Sheet and
# the PDF are always built from the identical merged data set.
#
# Usage:
#   fetch-ideas.sh CUSTOMER_NAME [--org ID ...]
#
# Prints the merged ideas JSON array on stdout -- each element gains a
# "rank" field (an integer, or null if unranked / no upsight-go data).
#
# Requires: the vendored customer-ideas.sh, AHA_API_TOKEN, jq, and (for rank
# data) stack-rank-lookup.sh -- see that script for its own graceful-miss
# behavior when upsight-go isn't installed or has no data for this customer.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AHA_CUSTOMER_IDEAS="$here/../vendor/customer-ideas.sh"
STACK_RANK_LOOKUP="$here/stack-rank-lookup.sh"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

customer_name="${1:?usage: fetch-ideas.sh CUSTOMER_NAME [--org ID ...]}"
shift

[[ -x "$AHA_CUSTOMER_IDEAS" ]] || die "customer-ideas.sh not found/executable at $AHA_CUSTOMER_IDEAS"
command -v jq >/dev/null 2>&1 || die "'jq' is required but not on PATH"

ideas_json="$("$AHA_CUSTOMER_IDEAS" "$customer_name" --json "$@")"

# Pull the org id(s) back out of "$@" (whatever was forwarded to
# customer-ideas.sh) so the rank lookup targets the same org(s) the ideas
# actually came from, without re-resolving anything.
declare -a org_ids=()
prev=""
for arg in "$@"; do
  [[ "$prev" == "--org" ]] && org_ids+=("$arg")
  prev="$arg"
done

ranks_json='{}'
if [[ ${#org_ids[@]} -gt 0 ]]; then
  ranks_json="$(bash "$STACK_RANK_LOOKUP" "${org_ids[@]}")"
fi

echo "$ideas_json" | jq --argjson ranks "$ranks_json" '
  map(. + {rank: ($ranks[.ref] // null)})
'
