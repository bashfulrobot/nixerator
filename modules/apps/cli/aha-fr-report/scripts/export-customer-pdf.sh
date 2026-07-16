#!/usr/bin/env bash
# Render a customer's Aha! feature requests into a Kong-branded PDF and
# upload it into their FRs/Customer-PDF-Reports Drive folder.
#
# Usage:
#   export-customer-pdf.sh "HealthEquity" <pdf_reports_folder_id> \
#     [--display-name "Full Name"] [--org ID ...]
#
# CUSTOMER_NAME is the Drive folder name and (unless --org overrides it) the
# Aha! search term. Pass one or more --org ID when the Drive folder name and
# the Aha idea-organization name/id diverge, or when a plain name search would
# be ambiguous (see customer-ideas.sh --org).
#
# --display-name overrides the name shown on the PDF and used in its filename,
# for customers whose Drive folder isn't their full name (e.g. folder "Sony
# Interactive" -> "Sony Interactive Entertainment" on the page). This PDF goes
# to the customer, so it should carry their real name. Defaults to
# CUSTOMER_NAME.
#
# Prints "pdf_file_id<TAB>pdf_webViewLink" on stdout when done.
#
# This PDF is customer-facing (see customer-fr-report.sh), so render_report.py
# deliberately omits the Aha Link / Proxy Vote Link columns that the internal
# Sheet carries -- Stack Rank and everything else still shows.
#
# Requires: wkhtmltopdf, python3, gws (authenticated), fetch-ideas.sh (and in
# turn customer-ideas.sh, AHA_API_TOKEN).

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH_IDEAS="$here/fetch-ideas.sh"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

customer_name="${1:?usage: export-customer-pdf.sh CUSTOMER_NAME PDF_REPORTS_FOLDER_ID [--display-name NAME] [--org ID ...]}"
pdf_reports_folder_id="${2:?usage: export-customer-pdf.sh CUSTOMER_NAME PDF_REPORTS_FOLDER_ID [--display-name NAME] [--org ID ...]}"
shift 2

# Pull --display-name out; everything left over is forwarded to fetch-ideas.sh
# untouched (it only understands --org).
display_name=""
_fetch_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --display-name)
      display_name="${2:?--display-name requires a value}"
      shift 2
      ;;
    *)
      _fetch_args+=("$1")
      shift
      ;;
  esac
done
set -- ${_fetch_args[@]+"${_fetch_args[@]}"}
display_name="${display_name:-$customer_name}"

command -v wkhtmltopdf >/dev/null 2>&1 || die "'wkhtmltopdf' is required but not on PATH"
[[ -x "$FETCH_IDEAS" ]] || die "fetch-ideas.sh not found/executable at $FETCH_IDEAS"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

echo "Pulling ideas for ${customer_name} from Aha!..." >&2
# customer-ideas.sh (called inside fetch-ideas.sh) ignores $customer_name for
# search purposes once any --org is present (see its own arg parsing), so
# it's safe to always pass both -- --org just takes precedence.
"$FETCH_IDEAS" "$customer_name" "$@" >"$workdir/ideas.json"

echo "Rendering Kong-branded HTML..." >&2
python3 "$here/render_report.py" "$display_name" <"$workdir/ideas.json" >"$workdir/report.html"

echo "Converting to PDF..." >&2
today="$(date +%Y-%m-%d)"
safe_name="$(printf '%s' "$display_name" | tr -c 'A-Za-z0-9_.-' '_')"
pdf_name="${safe_name}-FRs-${today}.pdf"
wkhtmltopdf --enable-local-file-access --page-size Letter --margin-top 10mm \
  --margin-bottom 10mm --margin-left 10mm --margin-right 10mm \
  "$workdir/report.html" "$workdir/$pdf_name" >/dev/null 2>&1

[[ -s "$workdir/$pdf_name" ]] || die "wkhtmltopdf did not produce a PDF"

echo "Uploading ${pdf_name} to Drive..." >&2
# gws restricts --upload to a path inside the current directory, and $here
# may be a read-only Nix store path once this script is packaged -- upload
# from $workdir (a real mktemp -d) instead of copying back into $here.
cd "$workdir"
result="$(gws drive files create \
  --json "{\"name\":\"${pdf_name}\",\"parents\":[\"${pdf_reports_folder_id}\"]}" \
  --upload "./$pdf_name" \
  --upload-content-type "application/pdf" \
  --params '{"supportsAllDrives":true,"fields":"id,webViewLink"}' 2>/dev/null)"

pdf_id="$(echo "$result" | jq -r '.id // empty')"
pdf_link="$(echo "$result" | jq -r '.webViewLink // empty')"
[[ -n "$pdf_id" ]] || die "upload failed: $result"

printf '%s\t%s\n' "$pdf_id" "$pdf_link"
echo "Done: ${pdf_link}" >&2
