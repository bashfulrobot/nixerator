#!/usr/bin/env bash
# naming.sh — derive the invoice number and all filenames from issuer/period/seq.
#   naming.sh number PERIOD SEQ                       -> YYYY-MM-NNN
#   naming.sh files  ISSUER PERIOD SEQ [VENDOR...]    -> JSON of derived names
set -euo pipefail

cmd="${1:?usage: number|files}"
shift

fmt_number() { # PERIOD SEQ
  local period="$1" seq="$2"
  [[ "${period}" =~ ^[0-9]{4}-[0-9]{2}$ ]] || {
    echo "naming: bad period '${period}'" >&2
    return 1
  }
  [[ "${seq}" =~ ^[0-9]+$ ]] || {
    echo "naming: bad sequence '${seq}'" >&2
    return 1
  }
  printf '%s-%03d' "${period}" "${seq}"
}

case "${cmd}" in
  number)
    fmt_number "${1:?PERIOD}" "${2:?SEQ}"
    ;;
  files)
    issuer="${1:?ISSUER}"
    period="${2:?PERIOD}"
    seq="${3:?SEQ}"
    shift 3
    number="$(fmt_number "${period}" "${seq}")"
    evidence_json='[]'
    if [ "$#" -gt 0 ]; then
      ev=()
      for v in "$@"; do ev+=("${period}-${v}"); done
      evidence_json="$(printf '%s\n' "${ev[@]}" | jq -R . | jq -sc .)"
    fi
    jq -nc \
      --arg number "${number}" \
      --arg invoicePdf "${issuer}-Invoice_${number}.pdf" \
      --arg zip "${period}-${issuer}.zip" \
      --arg folder "${period//-//}" \
      --argjson evidence "${evidence_json}" \
      '{number:$number,invoicePdf:$invoicePdf,zip:$zip,folder:$folder,evidence:$evidence}'
    ;;
  *)
    echo "naming: unknown command '${cmd}'" >&2
    exit 1
    ;;
esac
