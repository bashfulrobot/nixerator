#!/usr/bin/env bash
# End-to-end per-customer feature-request report: resolves the customer's
# Drive folder, writes/overwrites the internal Sheet, and generates a fresh
# Kong-branded PDF snapshot into FRs/Customer-PDF-Reports.
#
# Usage:
#   customer-fr-report.sh "HealthEquity" [--display-name "Full Name"] [--org ID ...]
#
# CUSTOMER_NAME must be the EXACT name of the customer's own folder, which
# sits at <region>/<customer> in the Customers shared drive (lookup is
# exact-match, not fuzzy, and rejects same-named folders nested deeper -- see
# find_customer_folder in drive-lib.sh). It also doubles as the Aha! search
# term unless overridden.
#
# --display-name overrides the name shown on the customer-facing PDF and used
# for the Sheet title, for customers whose Drive folder name isn't their full
# name (e.g. folder "Sony Interactive" -> "Sony Interactive Entertainment").
# Defaults to CUSTOMER_NAME.
#
# Pass one or more --org ID (Aha idea-organization id) when the Drive folder
# name and the right Aha organization diverge, or a plain name search would
# be ambiguous/too broad (e.g. "X Corporation" fuzzy-matches dozens of
# unrelated "*Corporation" orgs in Aha with no exact-match guard by default
# -- see vendor/customer-ideas.sh's --org flag, which this forwards to).
# Repeatable for a customer with more than one Aha org (rare; most single-org
# customers don't need this at all -- a specific enough name already
# narrows correctly, as it does for HealthEquity's two legitimate orgs).
#
# All files live inside Kong's "Customers" shared drive, which enforces
# domainUsersOnly (verified: external "anyone with link" sharing is rejected
# by the API for anything stored there). The Sheet is the internal working
# copy; the PDF is what you actually hand to the customer (email attachment,
# Slack upload), not a Drive link.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/drive-lib.sh"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

customer_name="${1:?usage: customer-fr-report.sh \"Customer Name\" [--display-name NAME] [--org ID ...]}"
shift

# Peek at --display-name so it can be logged and forwarded explicitly; the
# leaf scripts parse it out of their own args the same way.
display_name=""
_rest=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --display-name)
      display_name="${2:?--display-name requires a value}"
      shift 2
      ;;
    *)
      _rest+=("$1")
      shift
      ;;
  esac
done
set -- ${_rest[@]+"${_rest[@]}"}

declare -a display_args=()
if [[ -n "$display_name" ]]; then
  display_args=(--display-name "$display_name")
fi

echo "== Resolving Drive folders for '${customer_name}' ==" >&2
if [[ -n "$display_name" ]]; then
  echo "  display name:        $display_name" >&2
fi
resolved="$(resolve_customer_frs_folder "$customer_name")" || die "folder resolution failed"
customer_id="$(echo "$resolved" | cut -f1)"
frs_id="$(echo "$resolved" | cut -f2)"
pdf_reports_id="$(echo "$resolved" | cut -f3)"
echo "  customer folder:     $customer_id" >&2
echo "  FRs folder:          $frs_id" >&2
echo "  PDF reports folder:  $pdf_reports_id" >&2

echo >&2
echo "== Writing internal Sheet ==" >&2
sheet_result="$(bash "$here/write-customer-sheet.sh" "$customer_name" "$frs_id" ${display_args[@]+"${display_args[@]}"} "$@")"
sheet_url="$(echo "$sheet_result" | cut -f2)"

echo >&2
echo "== Generating Kong-branded PDF ==" >&2
pdf_result="$(bash "$here/export-customer-pdf.sh" "$customer_name" "$pdf_reports_id" ${display_args[@]+"${display_args[@]}"} "$@")"
pdf_link="$(echo "$pdf_result" | cut -f2)"

echo >&2
echo "== Done ==" >&2
echo "Sheet (internal, live-updating): $sheet_url"
echo "PDF (customer-facing snapshot):  $pdf_link"
