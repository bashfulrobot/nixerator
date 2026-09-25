#!/usr/bin/env bash
# wave-invoice-mark-sent.sh INVOICE_ID [CONFIG] [SEND_METHOD]
#   INVOICE_ID: the Wave invoice id to mark as sent in Wave's records only --
#   this mutation never emails anyone. SEND_METHOD is a Wave InvoiceSendMethod
#   enum value; defaults to MARKED_SENT, the correct value when the invoice
#   was actually delivered some other way (e.g. by hand via Gmail). Do NOT
#   use this to trigger delivery -- that is invoiceSend, deliberately not
#   wrapped here (see SKILL.md).
# Prints JSON: {id, invoiceNumber, status}. Exits non-zero on Wave inputErrors
# or didSucceed=false. The access token is used internally and never printed
# (see lib.sh secrets note).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVOICE_ID="${1:?INVOICE_ID required}"
CONFIG="${2:-${HERE}/../config.json}"
SEND_METHOD="${3:-MARKED_SENT}"
# shellcheck source=/dev/null
source "${HERE}/lib.sh" "${CONFIG}"

GQL_URL="$(cfg '.wave.graphql_url')"
TOKEN="$(wave_access_token)"

read -r -d '' MUTATION <<'GQL' || true
mutation ($input: InvoiceMarkSentInput!) {
  invoiceMarkSent(input: $input) {
    didSucceed
    inputErrors { message code path }
    invoice { id invoiceNumber status }
  }
}
GQL

sent_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
variables="$(jq -nc \
  --arg id "${INVOICE_ID}" \
  --arg method "${SEND_METHOD}" \
  --arg sentAt "${sent_at}" \
  '{input:{invoiceId:$id, sendMethod:$method, sentAt:$sentAt}}')"
body="$(jq -nc --arg q "${MUTATION}" --argjson v "${variables}" '{query:$q, variables:$v}')"
resp="$(curl -fsS -X POST "${GQL_URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${body}")"

ok="$(echo "${resp}" | jq -r '.data.invoiceMarkSent.didSucceed // false')"
if [ "${ok}" != "true" ]; then
  echo "wave-invoice-mark-sent: failed" >&2
  echo "${resp}" | jq '.errors, .data.invoiceMarkSent.inputErrors' >&2
  exit 1
fi
echo "${resp}" | jq -c '.data.invoiceMarkSent.invoice'
