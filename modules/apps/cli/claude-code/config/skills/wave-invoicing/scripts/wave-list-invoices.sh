#!/usr/bin/env bash
# wave-list-invoices.sh [CONFIG] [STATUS] — list invoices for the configured
# business as NORMALIZED JSON (one object per invoice), for fast freeform status
# queries ("any outstanding invoices?", "what's overdue?", "did Camino pay?").
#
# Read-only. Optional STATUS filters server-side (e.g. SAVED, UNVERIFIED, PAID,
# OVERDUE, DRAFT) so we don't fetch everything to answer a narrow question.
# The access token is used internally and never printed (see lib.sh secrets note).
#
# Output: a JSON array of
#   { id, invoiceNumber, status, invoiceDate, dueDate, customer, customerId,
#     total, amountDue, amountPaid,        # real numbers, commas stripped
#     outstanding,                         # amountDue>0 && status!=DRAFT
#     overdue,                             # outstanding && dueDate<today
#     viewUrl, pdfUrl }
# so a caller can answer most questions with a single jq select, e.g.
#   wave-list-invoices.sh | jq 'map(select(.outstanding))'
#   wave-list-invoices.sh | jq 'map(select(.overdue)) | length'
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-${HERE}/../config.json}"
STATUS="${2:-}"
# shellcheck source=/dev/null
source "${HERE}/lib.sh" "${CONFIG}"

GQL_URL="$(cfg '.wave.graphql_url')"
BIZ="$(cfg '.wave.business_id')"
TOKEN="$(wave_access_token)"
TODAY="$(date +%F)"

# Schema verified against the live Wave API 2026-06-10: the invoices() arg
# `status` (type `InvoiceStatus`) and the `.value` money fields all resolve.
# Observed status values include SENT (outstanding) and PAID. The jq
# normalization below stays tolerant of string/number money regardless.
read -r -d '' QUERY <<'GQL' || true
query($businessId: ID!, $page: Int!, $pageSize: Int!, $status: InvoiceStatus) {
  business(id: $businessId) {
    invoices(page: $page, pageSize: $pageSize, status: $status) {
      pageInfo { currentPage totalPages totalCount }
      edges { node {
        id invoiceNumber status invoiceDate dueDate
        total { value }
        amountDue { value }
        amountPaid { value }
        customer { id name }
        viewUrl pdfUrl
      } }
    }
  }
}
GQL

# Omit the status filter (null) when STATUS is empty → server returns all.
if [ -n "${STATUS}" ]; then
  vars="$(jq -nc --arg b "${BIZ}" --arg s "${STATUS}" '{businessId:$b,page:1,pageSize:200,status:$s}')"
else
  vars="$(jq -nc --arg b "${BIZ}" '{businessId:$b,page:1,pageSize:200,status:null}')"
fi
body="$(jq -nc --arg q "${QUERY}" --argjson v "${vars}" '{query:$q,variables:$v}')"

curl -fsS -X POST "${GQL_URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${body}" \
| jq --arg today "${TODAY}" '
    # money may arrive as "1,234.56" (string) or a number; coerce either way.
    def num: (. // 0) | tostring | gsub(",";"") | tonumber;
    [ .data.business.invoices.edges[].node
      | { id, invoiceNumber, status,
          invoiceDate, dueDate,
          customer:   .customer.name,
          customerId: .customer.id,
          total:      (.total.value      | num),
          amountDue:  (.amountDue.value  | num),
          amountPaid: (.amountPaid.value | num),
          viewUrl, pdfUrl }
      | .outstanding = (.amountDue > 0 and .status != "DRAFT")
      | .overdue     = (.outstanding and (.dueDate != null) and (.dueDate < $today))
    ]'
