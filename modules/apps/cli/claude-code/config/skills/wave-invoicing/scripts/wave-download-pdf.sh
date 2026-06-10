#!/usr/bin/env bash
# wave-download-pdf.sh PDF_URL OUTFILE
# Downloads the Wave invoice PDF. The pdfUrl is pre-authenticated/expiring, so
# no bearer header is needed; we still verify the result is a PDF.
set -euo pipefail
URL="${1:?PDF_URL required}"
OUT="${2:?OUTFILE required}"

curl -fsSL "${URL}" -o "${OUT}"
head -c 4 "${OUT}" | grep -q '%PDF' || {
  echo "wave-download-pdf: not a PDF: ${OUT}" >&2
  exit 1
}
printf '%s\n' "${OUT}"
