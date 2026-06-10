#!/usr/bin/env bash
# wave-create-invoice.sh PAYLOAD_JSON_FILE [CONFIG]
#   PAYLOAD_JSON_FILE: the {input:{...}} variables from build_invoice_payload.
# Prints JSON: {id, pdfUrl, viewUrl, invoiceNumber, status}. Exits non-zero on
# Wave inputErrors or didSucceed=false. The access token is used internally and
# never printed (see lib.sh secrets note).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_FILE="${1:?PAYLOAD_JSON_FILE required}"
CONFIG="${2:-${HERE}/../config.json}"
# shellcheck source=/dev/null
source "${HERE}/lib.sh" "${CONFIG}"

GQL_URL="$(cfg '.wave.graphql_url')"
TOKEN="$(wave_access_token)"

read -r -d '' MUTATION <<'GQL' || true
mutation ($input: InvoiceCreateInput!) {
  invoiceCreate(input: $input) {
    didSucceed
    inputErrors { message code path }
    invoice { id pdfUrl viewUrl invoiceNumber status }
  }
}
GQL

variables="$(cat "${PAYLOAD_FILE}")"
body="$(jq -nc --arg q "${MUTATION}" --argjson v "${variables}" '{query:$q, variables:$v}')"
resp="$(curl -fsS -X POST "${GQL_URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${body}")"

ok="$(echo "${resp}" | jq -r '.data.invoiceCreate.didSucceed // false')"
if [ "${ok}" != "true" ]; then
  echo "wave-create-invoice: failed" >&2
  echo "${resp}" | jq '.errors, .data.invoiceCreate.inputErrors' >&2
  exit 1
fi
echo "${resp}" | jq -c '.data.invoiceCreate.invoice'
