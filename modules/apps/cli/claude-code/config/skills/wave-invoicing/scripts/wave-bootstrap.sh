#!/usr/bin/env bash
# wave-bootstrap.sh [CONFIG] — print businesses, customers, and products as JSON
# to help populate config.json. Read-only. One-time setup helper.
# The access token is used internally and never printed (see lib.sh secrets note).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-${HERE}/../config.json}"
# shellcheck source=/dev/null
source "${HERE}/lib.sh" "${CONFIG}"

GQL_URL="$(cfg '.wave.graphql_url')"
TOKEN="$(wave_access_token)"

read -r -d '' QUERY <<'GQL' || true
query {
  businesses(page: 1, pageSize: 50) {
    edges { node {
      id name
      customers(page: 1, pageSize: 200) { edges { node { id name email } } }
      products(page: 1, pageSize: 200) { edges { node { id name } } }
    } }
  }
}
GQL

body="$(jq -nc --arg q "${QUERY}" '{query:$q}')"
curl -fsS -X POST "${GQL_URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${body}" | jq '.data.businesses.edges[].node
        | {id, name,
           customers: [.customers.edges[].node],
           products: [.products.edges[].node]}'
