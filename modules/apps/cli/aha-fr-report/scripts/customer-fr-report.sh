#!/usr/bin/env bash
# End-to-end per-customer feature-request report: resolves the customer's
# Drive folder, writes/overwrites the internal Sheet, and generates a fresh
# Kong-branded PDF snapshot into FRs/exports.
#
# Usage:
#   customer-fr-report.sh "HealthEquity"
#
# All files live inside Kong's "Customers" shared drive, which enforces
# domainUsersOnly (verified: external "anyone with link" sharing is rejected
# by the API for anything stored there). The Sheet is the internal working
# copy; the PDF is what you actually hand to the customer (email attachment,
# Slack upload), not a Drive link.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/drive-lib.sh"

die() { echo "ERROR: $*" >&2; exit 2; }

customer_name="${1:?usage: customer-fr-report.sh \"Customer Name\"}"

echo "== Resolving Drive folders for '${customer_name}' ==" >&2
resolved="$(resolve_customer_frs_folder "$customer_name")" || die "folder resolution failed"
customer_id="$(echo "$resolved" | cut -f1)"
frs_id="$(echo "$resolved" | cut -f2)"
exports_id="$(echo "$resolved" | cut -f3)"
echo "  customer folder: $customer_id" >&2
echo "  FRs folder:      $frs_id" >&2
echo "  exports folder:  $exports_id" >&2

echo >&2
echo "== Writing internal Sheet ==" >&2
sheet_result="$(bash "$here/write-customer-sheet.sh" "$customer_name" "$frs_id")"
sheet_url="$(echo "$sheet_result" | cut -f2)"

echo >&2
echo "== Generating Kong-branded PDF ==" >&2
pdf_result="$(bash "$here/export-customer-pdf.sh" "$customer_name" "$exports_id")"
pdf_link="$(echo "$pdf_result" | cut -f2)"

echo >&2
echo "== Done ==" >&2
echo "Sheet (internal, live-updating): $sheet_url"
echo "PDF (customer-facing snapshot):  $pdf_link"
