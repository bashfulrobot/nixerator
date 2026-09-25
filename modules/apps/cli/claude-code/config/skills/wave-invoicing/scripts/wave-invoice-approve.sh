#!/usr/bin/env bash
# wave-invoice-approve.sh INVOICE_ID [CONFIG]
#   INVOICE_ID: the Wave invoice id (from wave-create-invoice.sh's `id`, or
#   wave-list-invoices.sh) to move it from DRAFT to Approved. Does not notify
#   the customer -- Wave never emails anyone for this mutation.
# Prints JSON: {id, invoiceNumber, status}. Exits non-zero on Wave inputErrors
# or didSucceed=false. The access token is used internally and never printed
# (see lib.sh secrets note).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVOICE_ID="${1:?INVOICE_ID required}"
CONFIG="${2:-${HERE}/../config.json}"
# shellcheck source=/dev/null
source "${HERE}/lib.sh" "${CONFIG}"

GQL_URL="$(cfg '.wave.graphql_url')"
TOKEN="$(wave_access_token)"

read -r -d '' MUTATION <<'GQL' || true
mutation ($input: InvoiceApproveInput!) {
  invoiceApprove(input: $input) {
    didSucceed
    inputErrors { message code path }
    invoice { id invoiceNumber status }
  }
}
GQL

variables="$(jq -nc --arg id "${INVOICE_ID}" '{input:{invoiceId:$id}}')"
body="$(jq -nc --arg q "${MUTATION}" --argjson v "${variables}" '{query:$q, variables:$v}')"
resp="$(curl -fsS -X POST "${GQL_URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${body}")"

ok="$(echo "${resp}" | jq -r '.data.invoiceApprove.didSucceed // false')"
if [ "${ok}" != "true" ]; then
  echo "wave-invoice-approve: failed" >&2
  echo "${resp}" | jq '.errors, .data.invoiceApprove.inputErrors' >&2
  exit 1
fi
echo "${resp}" | jq -c '.data.invoiceApprove.invoice'
