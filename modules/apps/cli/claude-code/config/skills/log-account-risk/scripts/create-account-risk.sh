#!/usr/bin/env bash
# Create one Account_Risk__c record via the Salesforce REST API, then read it
# back to verify. Used by the log-account-risk skill's Step 4 write.
#
# This is the execution mechanic that replaces `sf data create --values` in
# the sfdc writes-playbook -- everything else in that playbook (understand,
# confirm org, describe, plan, EXPLICIT user confirmation) still applies and
# must have happened before this script runs. The script echoes the target
# org so the plan and the execution agree on where the write lands.
#
# Usage:
#   create-account-risk.sh --payload payload.json \
#     [--target-org ALIAS] [--api-version v62.0]
#
#   --payload FILE    JSON body from build-risk-payload.sh.
#   --target-org      sf org alias/username. Defaults to the configured org.
#   --api-version     REST API version. Default v62.0. Bump if the org rejects
#                     it; list versions with:
#                       sf api request rest 'services/data' | jq
#
# On the CANNOT_EXECUTE_FLOW_TRIGGER error (a Closed Won opp was linked), the
# script surfaces it plainly -- fall back to an open renewal opp or a blank
# Opportunity__c and rebuild the payload (see references/account-risk-object.md).

set -euo pipefail

payload=""
api_version="v62.0"
target_org=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --payload)
      payload="${2:?--payload needs a file}"
      shift 2
      ;;
    --target-org)
      target_org=(--target-org "$2")
      shift 2
      ;;
    --api-version)
      api_version="${2:?--api-version needs a value}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$payload" ]] || {
  echo "ERROR: --payload file not found: $payload" >&2
  exit 2
}
jq -e 'type == "object" and has("Account__c") and has("Name")' "$payload" >/dev/null 2>&1 ||
  {
    echo "ERROR: payload must be a JSON object with at least Name and Account__c" >&2
    exit 2
  }

# Echo the target org (token filtered out) so the write target is unambiguous.
echo "== Target org ==" >&2
sf org display --json "${target_org[@]}" |
  jq -r '.result | "  \(.alias // "<no alias>") / \(.username) / \(.instanceUrl)"' >&2

echo "== Creating Account_Risk__c ==" >&2
resp="$(sf api request rest "services/data/${api_version}/sobjects/Account_Risk__c" \
  --method POST --body "@${payload}" "${target_org[@]}")"

# The REST create returns {"id":"a0X...","success":true,"errors":[]} on success,
# or an array of error objects on failure.
if ! echo "$resp" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "== CREATE FAILED ==" >&2
  echo "$resp" | jq . >&2 || echo "$resp" >&2
  if echo "$resp" | grep -q 'CANNOT_EXECUTE_FLOW_TRIGGER'; then
    echo >&2
    echo "  This is the Closed Won opp linkage block. Fall back to an open" >&2
    echo "  renewal opp or a blank Opportunity__c, then rebuild the payload." >&2
  fi
  exit 1
fi

new_id="$(echo "$resp" | jq -r '.id')"
echo "  Created: $new_id" >&2

echo "== Verify (read-back) ==" >&2
sf data query \
  --query "SELECT Id, Name, Type__c, Status__c, Source__c, Trend__c, Opportunity__c, Account__c FROM Account_Risk__c WHERE Id = '${new_id}'" \
  "${target_org[@]}"

# Emit the new Id on stdout for the caller to capture/cache.
echo "$new_id"
