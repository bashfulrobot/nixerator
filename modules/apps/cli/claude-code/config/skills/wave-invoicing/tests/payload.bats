#!/usr/bin/env bats
load helper

# Two line items: one consulting (qty=hours, unitPrice=rate), one pass-through (qty=1).
# Field is unitPrice, not price -- that's what Wave's InvoiceCreateItemInput
# actually accepts (verified via introspection 2026-09-24); build_invoice_payload
# itself is pass-through and doesn't care about item field names, but the fixture
# should still model the real payload shape.
items='[
  {"productId":"PROD_CONS","description":"Consulting — June","quantity":10,"unitPrice":150},
  {"productId":"PROD_PASS","description":"DigitalOcean (pass-through)","quantity":1,"unitPrice":42.50}
]'

@test "build_invoice_payload nests input with business, customer, number, dates, items" {
  run bash -c "source '${SCRIPTS}/lib.sh' '${SKILL_DIR}/config.json'; build_invoice_payload BIZ1 CUST1 2026-06-001 2026-06-30 2026-07-30 '${items}'"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.input.businessId')" = "BIZ1" ]
  [ "$(echo "$output" | jq -r '.input.customerId')" = "CUST1" ]
  [ "$(echo "$output" | jq -r '.input.invoiceNumber')" = "2026-06-001" ]
  [ "$(echo "$output" | jq -r '.input.invoiceDate')" = "2026-06-30" ]
  [ "$(echo "$output" | jq -r '.input.dueDate')" = "2026-07-30" ]
  [ "$(echo "$output" | jq -r '.input.status')" = "DRAFT" ]
  [ "$(echo "$output" | jq -r '.input.items | length')" = "2" ]
  # Representation-agnostic: jq may preserve the literal 42.50, so compare numerically.
  [ "$(echo "$output" | jq -r '.input.items[1].unitPrice == 42.5')" = "true" ]
}
