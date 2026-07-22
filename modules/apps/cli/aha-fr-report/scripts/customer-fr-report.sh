#!/usr/bin/env bash
# End-to-end per-customer feature-request report. Fetches the customer's Aha!
# ideas exactly once and builds every artifact from that single data set, so
# they can never disagree:
#   - the internal Sheet, always written to the customer's shared-drive
#     <Customer>/CS/FRs folder (its link never moves), and
#   - a fresh Kong-branded PDF snapshot.
# When a PDF destination is pinned (--pdf-folder / customers.txt field 4) it
# additionally writes a customer-facing bundle into the My Drive tree that
# folder lives in -- Customer/<Name>/FRs/{<Sheet copy>,pdf-reports/<PDF>,
# csv-exports/<CSV>} -- deriving the FRs and csv-exports folders from the
# pinned pdf-reports id (see resolve_pinned_pdf_siblings in drive-lib.sh).
# Without a pinned folder the PDF falls back to the in-drive
# FRs/Customer-PDF-Reports subfolder and no CSV / Sheet copy is produced.
#
# Usage:
#   customer-fr-report.sh "HealthEquity" [--display-name "Full Name"] \
#     [--pdf-folder ID] [--org ID ...]
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
# --pdf-folder ID pins the customer-facing PDF to an explicit pdf-reports folder
# (which must already exist -- no folder is created) instead of the in-drive
# <Customer>/CS/FRs/Customer-PDF-Reports subfolder. When given, ID is treated as
# a My Drive Customer/<Name>/FRs/pdf-reports folder, and its FRs parent plus a
# sibling csv-exports folder (created if missing) receive a Sheet copy and the
# CSV respectively. The internal Sheet still lands in its original shared-drive
# FRs folder, so that link is preserved. This is how per-customer customer-facing
# bundles outside the Customers shared drive are wired (see customers.txt
# field 4 and resolve_pinned_pdf_siblings in drive-lib.sh).
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

# Peek at --display-name and --pdf-folder so they can be logged and forwarded
# explicitly; the leaf scripts parse --display-name out of their own args the
# same way, while --pdf-folder is consumed here (it never reaches them).
display_name=""
pdf_folder=""
_rest=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --display-name)
      display_name="${2:?--display-name requires a value}"
      shift 2
      ;;
    --pdf-folder)
      pdf_folder="${2:?--pdf-folder requires a value}"
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
new_frs_id=""
new_csv_id=""
if [[ -n "$pdf_folder" ]]; then
  # PDF destination is pinned: resolve the shared-drive FRs (for the internal
  # Sheet, link preserved), send the PDF straight to $pdf_folder, and derive the
  # My Drive FRs + csv-exports siblings for the customer-facing Sheet copy / CSV.
  resolved="$(resolve_customer_frs_only "$customer_name")" || die "folder resolution failed"
  customer_id="$(echo "$resolved" | cut -f1)"
  frs_id="$(echo "$resolved" | cut -f2)"
  pdf_reports_id="$pdf_folder"
  siblings="$(resolve_pinned_pdf_siblings "$pdf_folder")" || die "could not resolve FRs/csv-exports around pinned folder $pdf_folder"
  new_frs_id="$(echo "$siblings" | cut -f1)"
  new_csv_id="$(echo "$siblings" | cut -f2)"
else
  resolved="$(resolve_customer_frs_folder "$customer_name")" || die "folder resolution failed"
  customer_id="$(echo "$resolved" | cut -f1)"
  frs_id="$(echo "$resolved" | cut -f2)"
  pdf_reports_id="$(echo "$resolved" | cut -f3)"
fi
echo "  customer folder:     $customer_id" >&2
echo "  FRs folder:          $frs_id" >&2
echo "  PDF reports folder:  $pdf_reports_id${pdf_folder:+ (pinned)}" >&2
if [[ -n "$pdf_folder" ]]; then
  echo "  My Drive FRs folder: $new_frs_id" >&2
  echo "  CSV exports folder:  $new_csv_id" >&2
fi

# Fetch the merged ideas exactly once; every artifact below reads this file
# (via --ideas-file) instead of hitting Aha! again, so the Sheet, PDF, CSV and
# Sheet copy are guaranteed to reflect the same snapshot. "$@" here is just the
# leftover --org flags (--display-name / --pdf-folder already stripped).
echo >&2
echo "== Fetching Aha! ideas (once, shared by every artifact) ==" >&2
ideas_file="$(mktemp)"
trap 'rm -f "$ideas_file"' EXIT
bash "$here/fetch-ideas.sh" "$customer_name" "$@" >"$ideas_file" || die "idea fetch failed"

echo >&2
echo "== Writing internal Sheet (shared drive, link preserved) ==" >&2
sheet_result="$(bash "$here/write-customer-sheet.sh" "$customer_name" "$frs_id" ${display_args[@]+"${display_args[@]}"} --ideas-file "$ideas_file")"
sheet_url="$(echo "$sheet_result" | cut -f2)"

echo >&2
echo "== Generating Kong-branded PDF ==" >&2
pdf_result="$(bash "$here/export-customer-pdf.sh" "$customer_name" "$pdf_reports_id" ${display_args[@]+"${display_args[@]}"} --ideas-file "$ideas_file")"
pdf_link="$(echo "$pdf_result" | cut -f2)"

csv_link=""
new_sheet_url=""
if [[ -n "$pdf_folder" ]]; then
  echo >&2
  echo "== Generating customer-facing CSV ==" >&2
  csv_result="$(bash "$here/export-customer-csv.sh" "$customer_name" "$new_csv_id" ${display_args[@]+"${display_args[@]}"} --ideas-file "$ideas_file")"
  csv_link="$(echo "$csv_result" | cut -f2)"

  echo >&2
  echo "== Writing Sheet copy into the My Drive FRs folder ==" >&2
  new_sheet_result="$(bash "$here/write-customer-sheet.sh" "$customer_name" "$new_frs_id" ${display_args[@]+"${display_args[@]}"} --ideas-file "$ideas_file")"
  new_sheet_url="$(echo "$new_sheet_result" | cut -f2)"
fi

echo >&2
echo "== Done ==" >&2
echo "Sheet (internal, shared drive):  $sheet_url"
if [[ -n "$pdf_folder" ]]; then
  echo "Sheet (My Drive FRs copy):       $new_sheet_url"
fi
echo "PDF (customer-facing snapshot):  $pdf_link"
if [[ -n "$pdf_folder" ]]; then
  echo "CSV (customer-facing data):      $csv_link"
fi
