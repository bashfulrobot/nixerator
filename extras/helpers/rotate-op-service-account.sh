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
# This script:
#   1. Prints the manual 1Password steps and waits for you to do them.
#   2. Installs the token locally (setup-op-service-account.sh --force).
#   3. Renders secrets.json with an EXPLICIT token override -- bypassing
#      op-toggle entirely, so step 2's fresh token is what actually lands.
#   4. Verifies auth and reports which vaults are visible (metadata only --
#      never prints token/secret values).
#   5. Prints (does not run) the push-secrets command for the fleet.
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

cat <<EOF

=== Step 1 of 4: rotate the service account in 1Password ===

In the 1Password web UI (Developer Tools -> the current SA, e.g. op-cli):

  a. Rotate the token. If the old service account is unrecoverable, generate
     a brand-new one instead -- if you do, update the op:// reference in
       ${TPL}
     ("onepassword.serviceAccountToken") to the new item BEFORE continuing,
     and re-run this script (it re-reads the template each time).
  b. Confirm the service account is granted READ on BOTH vaults:
       - nixerator
       - automation
  c. Update the credential field at:
       ${item_ref}
     with the new token value. This is the ONLY 1Password item that needs
     updating -- setup-op-service-account.sh reads from this same reference.

Press Enter once all three are done...
EOF
read -r _

echo
echo "=== Step 2 of 4: install the token locally ==="
echo
"${SCRIPT_DIR}/setup-op-service-account.sh" --force "${PASSTHROUGH_ARGS[@]}"

if [[ ! -f "${CANONICAL}" ]]; then
  echo "rotate-op-service-account: ${CANONICAL} still missing after install -- aborting." >&2
  exit 1
fi

echo
echo "=== Step 3 of 4: render secrets.json (explicit token, bypassing op-toggle) ==="
echo
if ! command -v render-secrets >/dev/null 2>&1; then
  echo "rotate-op-service-account: 'render-secrets' not on PATH." >&2
  echo "  On a fresh host before the first rebuild, use render-secrets-bootstrap.sh instead." >&2
  exit 1
fi
OP_SERVICE_ACCOUNT_TOKEN="$(<"${CANONICAL}")" render-secrets

echo
echo "=== Step 4 of 4: verify ==="
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

cat <<EOF

Rotation complete on this host. op-toggle should now work normally -- it
reads its "back to service-account" token from the secrets.json we just
re-rendered.

Next: propagate to the rest of the fleet, e.g.:
  just push-secrets donkeykong srv clanker
(this script does not push automatically -- run that yourself once you're
happy with the verification above.)
EOF
