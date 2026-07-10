#!/usr/bin/env bash
# Shared idea-fetch step for write-customer-sheet.sh and
# export-customer-pdf.sh: pulls a customer's assessed Aha! ideas, then
# annotates each with its upsight-go tracking data (if any), so the Sheet
# and the PDF are always built from the identical merged data set.
#
# Usage:
#   fetch-ideas.sh CUSTOMER_NAME [--org ID ...]
#
# Prints the merged ideas JSON array on stdout -- each element gains: rank,
# production_blocker, target_release, use_case, source_url, notes,
# internal_discussion_url, requester_name, requester_email. Every one of
# those is independently nullable -- an untracked idea, or a customer with
# no upsight-go data at all, just gets all-null fields, not an error.
#
# Row order (shared by both the Sheet and the PDF, since both consume this
# script's output directly): Open ideas first, Closed ideas last. Within
# each of those, ranked ideas come first sorted by Stack Rank ascending (1
# at the top), then unranked ideas after.
#
# Requires: the vendored customer-ideas.sh, AHA_API_TOKEN, jq, and (for the
# tracking fields) idea-tracking-lookup.sh -- see that script for its own
# graceful-miss behavior when upsight-go isn't installed, has no data for
# this customer, or predates the schema these fields depend on
# (bashfulrobot/upsight-go#60).

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AHA_CUSTOMER_IDEAS="$here/../vendor/customer-ideas.sh"
IDEA_TRACKING_LOOKUP="$here/idea-tracking-lookup.sh"

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
# customer-ideas.sh) so the tracking lookup targets the same org(s) the
# ideas actually came from, without re-resolving anything.
declare -a org_ids=()
prev=""
for arg in "$@"; do
  [[ "$prev" == "--org" ]] && org_ids+=("$arg")
  prev="$arg"
done

tracking_json='{}'
if [[ ${#org_ids[@]} -gt 0 ]]; then
  tracking_json="$(bash "$IDEA_TRACKING_LOOKUP" "${org_ids[@]}")"
fi

echo "$ideas_json" | jq --argjson tracking "$tracking_json" '
  ($tracking | map_values(. + {
     rank: (.rank // null), production_blocker: (.production_blocker // null),
     target_release: (.target_release // null), use_case: (.use_case // null),
     source_url: (.source_url // null), notes: (.notes // null),
     internal_discussion_url: (.internal_discussion_url // null),
     requester_name: (.requester_name // null), requester_email: (.requester_email // null)
   })) as $tracking
  | map(. + ($tracking[.ref] // {
      rank: null, production_blocker: null, target_release: null, use_case: null,
      source_url: null, notes: null, internal_discussion_url: null,
      requester_name: null, requester_email: null
    }))
  | sort_by([
      (if .state == "open" then 0 else 1 end),
      (if .rank == null then 1 else 0 end),
      (.rank // 0)
    ])
'
