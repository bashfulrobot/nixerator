#!/usr/bin/env bash
# lib.sh — shared helpers for the wave-invoicing scripts.
# Source it with the config path as $1:  source lib.sh /path/to/config.json
# The config path may instead come from the $WAVE_CONFIG env var as a fallback
# to $1. Sourcing this file sets `-euo pipefail` in the sourcing shell.
set -euo pipefail

WAVE_CONFIG="${1:-${WAVE_CONFIG:-}}"
if [ -z "${WAVE_CONFIG}" ] || [ ! -f "${WAVE_CONFIG}" ]; then
  echo "lib.sh: config not found (pass path as \$1 or set WAVE_CONFIG): '${WAVE_CONFIG}'" >&2
  return 1 2>/dev/null || exit 1
fi

# cfg JQ_PATH — print a scalar from the config. Errors if the value is
# missing/null or resolves to a non-scalar (object or array).
cfg() {
  local path="$1" val
  val="$(jq -er "(${path}) | if type==\"object\" or type==\"array\" then error(\"not a scalar\") else . end" "${WAVE_CONFIG}")" || {
    echo "cfg: missing or non-scalar config value at ${path}" >&2
    return 1
  }
  printf '%s' "${val}"
}

# build_invoice_payload BIZ CUST NUMBER INVOICE_DATE DUE_DATE ITEMS_JSON
# Emits the {input:{...}} variables object for the invoiceCreate mutation.
# Pure (no network) — safe to unit-test offline.
build_invoice_payload() {
  local biz="$1" cust="$2" number="$3" idate="$4" ddate="$5" items="$6"
  jq -nc \
    --arg businessId "${biz}" \
    --arg customerId "${cust}" \
    --arg invoiceNumber "${number}" \
    --arg invoiceDate "${idate}" \
    --arg dueDate "${ddate}" \
    --argjson items "${items}" \
    '{input:{businessId:$businessId,customerId:$customerId,status:"DRAFT",invoiceNumber:$invoiceNumber,invoiceDate:$invoiceDate,dueDate:$dueDate,items:$items}}'
}

# wave_access_token — echo the Wave Full Access Token for capture into a variable.
#
# The token is a personal-use bearer token sourced from the `nixerator` 1Password
# vault (item `wave`, field `credential`) and exposed as the WAVE_FULL_ACCESS_TOKEN
# env var by the nixerator claude-code module (secrets.json.tpl -> secrets.json ->
# env), exactly like AHA_API_TOKEN. The skill never calls `op` at runtime.
#
# SECRETS DISCIPLINE: the returned value is a credential. Callers MUST capture it
# (token="$(wave_access_token)") and pass it only via an Authorization header —
# NEVER print it, log it, or pipe it anywhere a human/agent would see it (not even
# a prefix/length).
wave_access_token() {
  if [ -z "${WAVE_FULL_ACCESS_TOKEN:-}" ]; then
    echo "wave_access_token: WAVE_FULL_ACCESS_TOKEN not set — run 'just render-secrets' then rebuild (just qr)" >&2
    return 1
  fi
  printf '%s' "${WAVE_FULL_ACCESS_TOKEN}"
}
