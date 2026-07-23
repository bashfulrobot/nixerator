#!/usr/bin/env bash
# Render a customer's Aha! feature requests into a customer-facing CSV and
# upload it into their csv-exports Drive folder, next to (a sibling of) the
# pdf-reports folder the PDF goes to.
#
# Usage:
#   export-customer-csv.sh "HealthEquity" <csv_exports_folder_id> \
#     [--display-name "Full Name"] [--ideas-file PATH] [--org ID ...]
#
# Columns match the customer-facing PDF's data (render_report.py --format csv):
# State, Ref, Idea, Status, Stack Rank, Use Case, Requester, Team, Production
# Blocker, Target Release, Notes, Source Link, Internal Discussion Link. The
# internal-only Aha Link / Proxy Vote Link columns the Sheet carries are
# deliberately omitted -- this file goes to the customer, like the PDF.
#
# --display-name overrides the name used in the CSV filename (not its
# contents), matching export-customer-pdf.sh. Defaults to CUSTOMER_NAME.
#
# --ideas-file PATH reads the already-merged ideas JSON from PATH instead of
# calling fetch-ideas.sh. customer-fr-report.sh fetches once and passes this so
# every artifact (Sheet, PDF, CSV) is built from one identical data set; run
# standalone (no --ideas-file) it fetches for itself, forwarding --org.
#
# Prints "csv_file_id<TAB>csv_webViewLink" on stdout when done.
#
# Requires: python3, gws (authenticated), jq, and -- unless --ideas-file is
# given -- fetch-ideas.sh (and in turn customer-ideas.sh, AHA_API_TOKEN).

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH_IDEAS="$here/fetch-ideas.sh"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

customer_name="${1:?usage: export-customer-csv.sh CUSTOMER_NAME CSV_EXPORTS_FOLDER_ID [--display-name NAME] [--ideas-file PATH] [--org ID ...]}"
csv_exports_folder_id="${2:?usage: export-customer-csv.sh CUSTOMER_NAME CSV_EXPORTS_FOLDER_ID [--display-name NAME] [--ideas-file PATH] [--org ID ...]}"
shift 2

# Pull --display-name and --ideas-file out; everything left over is forwarded to
# fetch-ideas.sh untouched (it only understands --org), and ignored entirely
# when --ideas-file short-circuits the fetch.
display_name=""
ideas_file=""
_fetch_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --display-name)
      display_name="${2:?--display-name requires a value}"
      shift 2
      ;;
    --ideas-file)
      ideas_file="${2:?--ideas-file requires a value}"
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

command -v jq >/dev/null 2>&1 || die "'jq' is required but not on PATH"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

if [[ -n "$ideas_file" ]]; then
  [[ -r "$ideas_file" ]] || die "ideas file not readable: $ideas_file"
  cp "$ideas_file" "$workdir/ideas.json"
else
  [[ -x "$FETCH_IDEAS" ]] || die "fetch-ideas.sh not found/executable at $FETCH_IDEAS"
  echo "Pulling ideas for ${customer_name} from Aha!..." >&2
  "$FETCH_IDEAS" "$customer_name" "$@" >"$workdir/ideas.json"
fi

echo "Rendering CSV..." >&2
today="$(date +%Y-%m-%d)"
safe_name="$(printf '%s' "$display_name" | tr -c 'A-Za-z0-9_.-' '_')"
csv_name="${safe_name}-FRs-${today}.csv"
python3 "$here/render_report.py" --format csv "$display_name" <"$workdir/ideas.json" >"$workdir/$csv_name"
[[ -s "$workdir/$csv_name" ]] || die "render_report.py produced an empty CSV"

echo "Uploading ${csv_name} to Drive..." >&2
# gws restricts --upload to a path inside the current directory, and $here may
# be a read-only Nix store path once packaged -- upload from $workdir (a real
# mktemp -d), exactly as export-customer-pdf.sh does.
cd "$workdir"
result="$(gws drive files create \
  --json "{\"name\":\"${csv_name}\",\"parents\":[\"${csv_exports_folder_id}\"]}" \
  --upload "./$csv_name" \
  --upload-content-type "text/csv" \
  --params '{"supportsAllDrives":true,"fields":"id,webViewLink"}' 2>/dev/null)"

csv_id="$(echo "$result" | jq -r '.id // empty')"
csv_link="$(echo "$result" | jq -r '.webViewLink // empty')"
[[ -n "$csv_id" ]] || die "upload failed: $result"

printf '%s\t%s\n' "$csv_id" "$csv_link"
echo "Done: ${csv_link}" >&2
