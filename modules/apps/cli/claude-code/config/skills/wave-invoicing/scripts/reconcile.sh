#!/usr/bin/env bash
# reconcile.sh ROOT ISSUER TARGET_PERIOD
#   ROOT          invoice tree root: ROOT/YYYY/MM/ISSUER-Invoice_YYYY-MM-NNN.pdf
#   ISSUER        issuer code, e.g. BrMfg
#   TARGET_PERIOD YYYY-MM we intend to bill now
# Prints JSON: {lastPeriod,lastSeq,billedPeriods,gaps,targetAlreadyBilled}
set -euo pipefail

ROOT="${1:?ROOT required}"
ISSUER="${2:?ISSUER required}"
TARGET="${3:?TARGET_PERIOD (YYYY-MM) required}"

# Collect every billed "YYYY-MM:NNN" by walking matching invoice PDFs.
periods=()
if [ -d "${ROOT}" ]; then
  while IFS= read -r -d '' f; do
    base="$(basename "${f}")"
    # ISSUER-Invoice_YYYY-MM-NNN.pdf  -> capture period + seq
    if [[ "${base}" =~ ^${ISSUER}-Invoice_([0-9]{4}-[0-9]{2})-([0-9]{3})\.pdf$ ]]; then
      periods+=("${BASH_REMATCH[1]}:${BASH_REMATCH[2]}")
    fi
  done < <(find "${ROOT}" -type f -name "${ISSUER}-Invoice_*.pdf" -print0 2>/dev/null)
fi

# Sorted unique list of billed periods (YYYY-MM).
billed_periods_json='[]'
last_period='null'
last_seq=0
target_billed=false

if [ "${#periods[@]}" -gt 0 ]; then
  sorted="$(printf '%s\n' "${periods[@]}" | sort)"
  billed_periods_json="$(printf '%s\n' "${sorted}" | cut -d: -f1 | sort -u | jq -R . | jq -sc .)"
  last_entry="$(printf '%s\n' "${sorted}" | tail -n1)"
  last_period="\"${last_entry%%:*}\""
  last_seq="$(printf '%s' "${last_entry##*:}" | sed 's/^0*//')"
  last_seq="${last_seq:-0}"
  if printf '%s\n' "${sorted}" | cut -d: -f1 | grep -qx "${TARGET}"; then
    target_billed=true
  fi
fi

# Compute month gaps strictly between last billed period and TARGET (exclusive).
gaps_json='[]'
if [ "${last_period}" != "null" ]; then
  lp="${last_period//\"/}"
  gaps=()
  cur="${lp}"
  while :; do
    cur="$(date -u -d "${cur}-01 +1 month" +%Y-%m)"
    [ "${cur}" \< "${TARGET}" ] || break
    gaps+=("${cur}")
  done
  if [ "${#gaps[@]}" -gt 0 ]; then
    gaps_json="$(printf '%s\n' "${gaps[@]}" | jq -R . | jq -sc .)"
  fi
fi

jq -nc \
  --argjson lastPeriod "${last_period}" \
  --argjson lastSeq "${last_seq}" \
  --argjson billedPeriods "${billed_periods_json}" \
  --argjson gaps "${gaps_json}" \
  --argjson targetAlreadyBilled "${target_billed}" \
  '{lastPeriod:$lastPeriod,lastSeq:$lastSeq,billedPeriods:$billedPeriods,gaps:$gaps,targetAlreadyBilled:$targetAlreadyBilled}'
