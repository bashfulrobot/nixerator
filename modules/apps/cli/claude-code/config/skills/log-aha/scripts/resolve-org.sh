#!/usr/bin/env bash
# Resolve a customer/account name to its Aha idea_organization, disambiguating
# by Salesforce account Id when there is more than one match.
#
# Usage:
#   resolve-org.sh "<customer name>"            # list candidates as JSON
#   resolve-org.sh "<customer name>" <sfdc_id>  # filter to the SFDC-id match
#
# Output: a JSON array of {id, ref, name, sfdc_id, endorsements_count}.
# When <sfdc_id> is given and matches, the array holds exactly that one org.
#
# Why Salesforce id and not name: idea_organizations are synced from Salesforce
# accounts, and a parent brand routinely has a dozen near-identical names (think
# "Sony", "Sony LLC", "Sony Inc.", "Sony Europe ..."). The Salesforce account Id
# is the only stable, unambiguous selector. It lives in the org's
# integration_fields where name=="Id" and service_name=="salesforce". The ref
# (ACCOUNT-O-NNNNN) is parsed from the org url for human-readable display; the
# numeric id is what the endorsement endpoint wants.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name="${1:?usage: resolve-org.sh \"<customer name>\" [sfdc_id]}"
want_sfdc="${2:-}"

raw="$(bash "$here/aha.sh" get idea_organizations -q "q=$name" \
        -q 'fields=id,name' --raw)"
ids="$(printf '%s' "$raw" | jq -r '.idea_organizations[]?.id // empty')"
[[ -n "$ids" ]] || { echo "[]"; exit 0; }

out="$(
  for id in $ids; do
    bash "$here/aha.sh" get "idea_organizations/$id" --raw | jq -c '
      .idea_organization | {
        id,
        name,
        ref: (.url | capture("idea_organizations/(?<r>[^/?]+)").r? // null),
        endorsements_count,
        sfdc_id: ([.integration_fields[]?
                   | select(.name=="Id" and .service_name=="salesforce")
                   | .value] | first // null)
      }'
  done | jq -s '.'
)"

if [[ -n "$want_sfdc" ]]; then
  printf '%s\n' "$out" | jq --arg s "$want_sfdc" '[ .[] | select(.sfdc_id==$s) ]'
else
  printf '%s\n' "$out"
fi
