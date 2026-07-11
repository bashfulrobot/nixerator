#!/usr/bin/env bash
# shellcheck shell=bash
#
# Walks through rotating the nixerator 1Password service-account token,
# end to end, on THIS host. Rotating this token by hand is failure-prone:
# the token has to agree in three places --
#   1. The 1Password service account's own vault grants (nixerator +
#      automation).
#   2. The 1Password item secrets.json.tpl / setup-op-service-account.sh
#      read from (onepassword.serviceAccountToken).
#   3. The local file at ~/.config/op/service-account-token on this host.
# -- and `op-toggle`'s "back to service-account" path reads its token from
# the RENDERED secrets.json, not that local file. Until you've rendered at
# least once with an EXPLICIT token override, a successful rotation still
# looks broken (every command keeps re-loading the stale, dead token from
# the old render).
#
# The classic silent failure is DRIFT between (2) and (3): the local file
# gets the new token but the 1Password item is never updated (or updated with
# a different token). Then op-toggle and `push-secrets` keep reading the dead
# token from the item forever, with nothing to tell you. This script closes
# that gap: it writes the rotated token to BOTH places itself, and verifies
# the op-toggle path before claiming success.
#
# This script:
#   1. Prints the manual 1Password steps (generate/rotate the token, confirm
#      vault grants) and waits for you.
#   2. Installs the token locally (setup-op-service-account.sh --force).
#   3. Writes that same token into the 1Password item the template reads from
#      (desktop session -- one biometric prompt), so the file and the item
#      can never drift.
#   4. Renders secrets.json with an EXPLICIT token override -- bypassing
#      op-toggle entirely, so the fresh token is what actually lands.
#   5. Verifies auth AND the op-toggle path (bare render-secrets --check),
#      failing loudly if the embedded token is wrong (metadata only -- never
#      prints token/secret values). Then prints the fleet push command.
#
# Usage:
#   ./extras/helpers/rotate-op-service-account.sh            # op read (biometric)
#   ./extras/helpers/rotate-op-service-account.sh --manual   # paste instead

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TPL="${REPO_ROOT}/secrets.json.tpl"
CANONICAL="${HOME}/.config/op/service-account-token"
SECRETS_FILE="${HOME}/.config/nixos-secrets/secrets.json"

PASSTHROUGH_ARGS=()
for a in "$@"; do
  case "$a" in
    --manual)
      PASSTHROUGH_ARGS+=(--manual)
      ;;
    -h | --help)
      sed -n '4,29p' "$0"
      exit 0
      ;;
    *)
      echo "rotate-op-service-account: unknown arg: $a" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "${TPL}" ]]; then
  echo "rotate-op-service-account: ${TPL} not found -- run from a nixerator checkout." >&2
  exit 1
fi

item_ref="$(sed -n 's#.*"serviceAccountToken": *"{{ *\(op://[^ ]*\) *}}".*#\1#p' "${TPL}")"
if [[ -z "${item_ref}" ]]; then
  echo "rotate-op-service-account: couldn't find onepassword.serviceAccountToken in ${TPL}" >&2
  exit 1
fi

# Split the op:// reference into vault / item / field so step 3 can write the
# rotated token back into the item -- keeping the 1Password item and the local
# file in lockstep. Expected shape: op://<vault>/<item>/<field>.
_ref_noproto="${item_ref#op://}"
op_vault="${_ref_noproto%%/*}"
_ref_rest="${_ref_noproto#*/}"
op_item="${_ref_rest%%/*}"
op_field="${_ref_rest#*/}"
if [[ -z "${op_vault}" || -z "${op_item}" || -z "${op_field}" || "${op_item}" == "${op_field}" ]]; then
  echo "rotate-op-service-account: couldn't parse vault/item/field from ${item_ref}" >&2
  exit 1
fi

cat <<EOF

=== Step 1 of 5: rotate the service account in 1Password ===

In the 1Password web UI (Developer Tools -> the current SA, e.g. op-cli):

  a. Rotate the token, or generate a brand-new service account if the old one
     is unrecoverable. Copy the new token (starts with 'ops_'). If you made a
     NEW service account, also update the op:// reference in
       ${TPL}
     ("onepassword.serviceAccountToken") to the new item BEFORE continuing,
     and re-run this script (it re-reads the template each time).
  b. Confirm the service account is granted READ on BOTH vaults:
       - nixerator
       - automation

You do NOT need to update the item's credential field by hand -- step 3 does
that for you, from the same token, so the file and the item can't drift.

Press Enter once the token is rotated and vault grants confirmed...
EOF
read -r _

echo
echo "=== Step 2 of 5: install the token locally ==="
echo
"${SCRIPT_DIR}/setup-op-service-account.sh" --force "${PASSTHROUGH_ARGS[@]}"

if [[ ! -f "${CANONICAL}" ]]; then
  echo "rotate-op-service-account: ${CANONICAL} still missing after install -- aborting." >&2
  exit 1
fi

echo
echo "=== Step 3 of 5: sync the token into the 1Password item ==="
echo
echo "Writing the installed token into ${item_ref}"
echo "(desktop 1Password session -- may prompt for biometric approval)."
# Blind copy: the value flows file -> op arg, never to stdout. Force the
# desktop session (unset any SA token) so this uses YOUR write access, not the
# read-only SA. Output suppressed so a concealed field can never echo.
item_synced=0
if env -u OP_SERVICE_ACCOUNT_TOKEN op whoami >/dev/null 2>&1; then
  if env -u OP_SERVICE_ACCOUNT_TOKEN op item edit "${op_item}" \
    "${op_field}=$(<"${CANONICAL}")" --vault "${op_vault}" >/dev/null 2>&1; then
    echo "  item updated: file and 1Password item now hold the same token."
    item_synced=1
  else
    echo "  WARNING: couldn't write the item (no write access, or wrong item/field)." >&2
  fi
else
  echo "  WARNING: desktop 1Password isn't signed in -- skipping the item update." >&2
  echo "  Run 'op signin' and re-run, or update it yourself:" >&2
fi
if [[ "${item_synced}" -eq 0 ]]; then
  echo "    op item edit ${op_item} \"${op_field}=\$(cat ${CANONICAL})\" --vault ${op_vault}" >&2
  echo "  Until the item matches the file, op-toggle and push-secrets keep using" >&2
  echo "  the OLD token (step 5 will flag this)." >&2
fi

echo
echo "=== Step 4 of 5: render secrets.json (explicit token, bypassing op-toggle) ==="
echo
if ! command -v render-secrets >/dev/null 2>&1; then
  echo "rotate-op-service-account: 'render-secrets' not on PATH." >&2
  echo "  On a fresh host before the first rebuild, use render-secrets-bootstrap.sh instead." >&2
  exit 1
fi
OP_SERVICE_ACCOUNT_TOKEN="$(<"${CANONICAL}")" render-secrets

echo
echo "=== Step 5 of 5: verify ==="
echo
OP_SERVICE_ACCOUNT_TOKEN="$(<"${CANONICAL}")" op whoami
echo
echo "Vaults visible to this token:"
OP_SERVICE_ACCOUNT_TOKEN="$(<"${CANONICAL}")" op vault list

missing=()
for key in .grafana.dashboardsToken .onepassword.serviceAccountToken; do
  present="$(jq -r "(${key} // \"\") != \"\"" "${SECRETS_FILE}" 2>/dev/null || echo false)"
  [[ "${present}" == "true" ]] || missing+=("${key}")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo
  echo "WARNING: these fields are empty in ${SECRETS_FILE}: ${missing[*]}" >&2
  echo "  (values not shown -- checked for presence only)" >&2
fi

# The critical drift check: bare render-secrets (no explicit token) uses the
# op-toggle path, which reads the token EMBEDDED in secrets.json -- i.e. the
# value that came from the 1Password item. If this fails, the item still holds
# the wrong token and push-secrets / op-toggle are silently broken fleet-wide.
echo
echo "Checking the op-toggle path (token embedded in secrets.json)..."
if render-secrets --check >/dev/null 2>&1; then
  echo "  OK: the embedded token authenticates. op-toggle and push-secrets will work."
  toggle_ok=1
else
  toggle_ok=0
  echo "  FAILED: the token embedded in secrets.json does NOT authenticate." >&2
  echo "  The 1Password item (${item_ref}) still holds the old/wrong token, so" >&2
  echo "  op-toggle and push-secrets stay broken until it's fixed:" >&2
  echo "    op item edit ${op_item} \"${op_field}=\$(cat ${CANONICAL})\" --vault ${op_vault}" >&2
  echo "  then re-run this script (or just 'render-secrets' once)." >&2
fi

if [[ "${toggle_ok}" -eq 1 ]]; then
  cat <<EOF

Rotation complete and self-checked on this host. Both the local file and the
1Password item hold the new token, and op-toggle reads it correctly.

Next: propagate to the rest of the fleet, e.g.:
  just push-secrets donkeykong srv clanker
(this script does not push automatically -- run that yourself once you're
happy with the verification above.)
EOF
else
  echo >&2
  echo "Rotation is INCOMPLETE: fix the item (above) before pushing to the fleet." >&2
  exit 1
fi
