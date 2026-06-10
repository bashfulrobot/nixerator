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

# _source_op_token — mirror render-secrets.sh: if OP_SERVICE_ACCOUNT_TOKEN is
# unset and the canonical token file exists, source it (refusing perms != 600).
_source_op_token() {
  local f="${HOME}/.config/op/service-account-token"
  if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -f "${f}" ]; then
    local p
    p="$(stat -c '%a' "${f}")"
    [ "${p}" = "600" ] || {
      echo "lib: ${f} perms ${p}, must be 600" >&2
      return 1
    }
    OP_SERVICE_ACCOUNT_TOKEN="$(<"${f}")"
    export OP_SERVICE_ACCOUNT_TOKEN
  fi
}

# wave_access_token — exchange the stored refresh_token for an access_token and
# echo the bare token to stdout for capture into a variable.
#
# SECRETS DISCIPLINE: the returned value is a credential. Callers MUST capture
# it (token="$(wave_access_token)") and pass it only via an Authorization header
# or env var — NEVER print it, log it, or pipe it anywhere a human/agent would
# see it (not even a prefix/length). There is deliberately no standalone CLI
# that prints the token, to avoid it landing in a terminal/transcript.
wave_access_token() {
  _source_op_token
  local item token_url cid csec rtok resp
  item="$(cfg '.wave.op_item')"
  token_url="$(cfg '.wave.token_url')"
  cid="$(op read "${item}/client_id")"
  csec="$(op read "${item}/client_secret")"
  rtok="$(op read "${item}/refresh_token")"
  resp="$(curl -fsS -X POST "${token_url}" \
    -d "client_id=${cid}" -d "client_secret=${csec}" \
    -d "grant_type=refresh_token" -d "refresh_token=${rtok}")" ||
    {
      echo "wave_access_token: token request failed" >&2
      return 1
    }
  echo "${resp}" | jq -er '.access_token' ||
    {
      echo "wave_access_token: no access_token in response" >&2
      return 1
    }
}
