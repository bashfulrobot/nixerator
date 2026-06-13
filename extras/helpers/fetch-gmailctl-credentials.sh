#!/usr/bin/env bash
# shellcheck shell=bash
#
# Fetches the gmailctl OAuth *client* credentials from the nixerator 1Password
# vault and writes them to ~/.gmailctl/credentials.json, where `gmailctl init`
# expects the OAuth client (verified from the gmailctl 0.12.0 binary: it reads
# "<configdir>/credentials.json" and writes "<configdir>/token.json", configdir
# defaulting to $HOME/.gmailctl).
#
# This is the file-shaped-secret pattern (same as fetch-okular-signatures.sh):
# the value is written straight to disk at 0600, never through the Nix store.
#
# 1Password item expected in the `nixerator` vault:
#   - gmailctl (Login) with two fields holding the OAuth client:
#       op://nixerator/gmailctl/Client ID
#       op://nixerator/gmailctl/Client Secret
#     credentials.json is reconstructed from these via `op inject`. The other
#     keys (auth_uri / token_uri / redirect_uris) are non-secret Google
#     constants for a Desktop-app ("installed") OAuth client, hardcoded in the
#     template below.
#
# NOT fetched here:
#   - token.json   -- produced locally by `gmailctl init` after browser consent.
#   - config.jsonnet -- lives in the ~/git/gmail-filters repo, not a secret.
#
# Uses the SA token at ~/.config/op/service-account-token if present (zero
# biometric prompts). Falls back to whatever the desktop CLI is signed in as.
#
# Run once per host (after `just setup-op-token`). Re-run only if you rotate
# the OAuth client in Google Cloud / update the 1Password item.
#
# Usage:
#   ./extras/helpers/fetch-gmailctl-credentials.sh
#   just fetch-gmailctl-creds            (alias: just fgc)

set -euo pipefail

# Parameters (all optional, defaults preserve the original personal-account
# behaviour so existing callers / the `fetch-gmailctl-creds` recipe are unchanged):
#   $1  config dir       (default ~/.gmailctl)              -> gmailctl --config
#   $2  1Password item   (default gmailctl, in vault nixerator)
#   $3  account label    (default dustin@bashfulrobot.com)  -- message only
# Example (Kong work account, reusing the SAME OAuth client item):
#   ./fetch-gmailctl-credentials.sh ~/.gmailctl-kong gmailctl dustin@konghq.com
GMAILCTL_DIR="${1:-${HOME}/.gmailctl}"
OP_ITEM="${2:-gmailctl}"
ACCOUNT_LABEL="${3:-dustin@bashfulrobot.com}"
CRED_PATH="${GMAILCTL_DIR}/credentials.json"
SA_TOKEN_FILE="${HOME}/.config/op/service-account-token"

if ! command -v op >/dev/null 2>&1; then
  echo "fetch-gmailctl-credentials: 'op' (1Password CLI) not in PATH." >&2
  echo "  Enable apps.gui.one-password on this host and rebuild, OR" >&2
  echo "  re-run inside: nix-shell -p _1password-cli" >&2
  exit 1
fi

# Service account auto-source -- same pattern as render-secrets. Skips
# biometric entirely once `just setup-op-token` has been run.
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -f "${SA_TOKEN_FILE}" ]]; then
  sa_perms="$(stat -c '%a' "${SA_TOKEN_FILE}")"
  if [[ "${sa_perms}" != "600" ]]; then
    echo "fetch-gmailctl-credentials: ${SA_TOKEN_FILE} perms ${sa_perms}, must be 600" >&2
    echo "  Fix:  chmod 600 ${SA_TOKEN_FILE}" >&2
    exit 1
  fi
  OP_SERVICE_ACCOUNT_TOKEN="$(<"${SA_TOKEN_FILE}")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

if ! op whoami >/dev/null 2>&1; then
  echo "fetch-gmailctl-credentials: 'op' not authenticated." >&2
  echo "  Either install the SA token (just setup-op-token), OR run: op signin" >&2
  exit 1
fi

mkdir -p "${GMAILCTL_DIR}"
chmod 700 "${GMAILCTL_DIR}"

tmp="$(mktemp -p "${GMAILCTL_DIR}" ".fetch-credentials.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT
chmod 600 "${tmp}"
# Reconstruct credentials.json. The two {{ op://... }} references are resolved
# by `op inject`; the value never touches stdout or the terminal. --force
# overwrites the mktemp-precreated file under the non-interactive SA session.
# Heredoc is UNquoted so ${OP_ITEM} expands in bash (it selects which 1Password
# item to read); the {{ op://... }} braces stay literal for `op inject`. The
# template contains no other $/backtick metacharacters, so no secret can leak.
op inject --force --out-file "${tmp}" <<CREDENTIALS_TPL
{
  "installed": {
    "client_id": "{{ op://nixerator/${OP_ITEM}/Client ID }}",
    "client_secret": "{{ op://nixerator/${OP_ITEM}/Client Secret }}",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "redirect_uris": ["http://localhost"]
  }
}
CREDENTIALS_TPL
chmod 600 "${tmp}"
mv -f "${tmp}" "${CRED_PATH}"
echo "fetch-gmailctl-credentials: wrote ${CRED_PATH} (0600)"

# gmailctl selects its config dir via --config (default ~/.gmailctl), NOT the
# current working directory. For a non-default dir, every subcommand needs the flag.
if [[ "${GMAILCTL_DIR}" == "${HOME}/.gmailctl" ]]; then
  CFG_FLAG=""
else
  CFG_FLAG=" --config ${GMAILCTL_DIR}"
fi

echo
echo "Next: run 'gmailctl${CFG_FLAG} init' to complete the browser OAuth consent"
echo "on ${ACCOUNT_LABEL}. Pick that exact account in Google's account chooser,"
echo "then it writes ${GMAILCTL_DIR}/token.json. Then 'gmailctl${CFG_FLAG} diff'"
echo "to compare the live account against your config."
