#!/usr/bin/env bash
# shellcheck shell=bash
#
# Writes the gmailctl OAuth *client* credentials to ~/.gmailctl/credentials.json,
# where `gmailctl init` expects the OAuth client (verified from the gmailctl 0.12.0
# binary: it reads "<configdir>/credentials.json" and writes "<configdir>/token.json",
# configdir defaulting to $HOME/.gmailctl).
#
# The values come from the secauto gopass store, not 1Password. They go straight
# to disk at 0600, never through the Nix store, argv or the terminal.
#
# gopass entries expected (created by `just import-secrets-to-gopass --mirror`
# from the nixerator vault Login item `gmailctl`; the mirror slugs the field
# labels "Client ID" and "Client Secret"):
#   - nixerator/gmailctl/client-id
#   - nixerator/gmailctl/client-secret
# The other keys (auth_uri / token_uri / redirect_uris) are non-secret Google
# constants for a Desktop-app ("installed") OAuth client, hardcoded below.
#
# NOT fetched here:
#   - token.json   -- produced locally by `gmailctl init` after browser consent.
#   - config.jsonnet -- lives in the ~/git/gmail-filters repo, not a secret.
#
# Run once per host. Re-run only if you rotate the OAuth client in Google Cloud
# and update the gopass entries.
#
# Usage:
#   ./extras/helpers/fetch-gmailctl-credentials.sh
#   just fetch-gmailctl-creds            (alias: just fgc)

set -euo pipefail

# Parameters (all optional, defaults preserve the original personal-account
# behaviour so existing callers / the `fetch-gmailctl-creds` recipe are unchanged):
#   $1  config dir       (default ~/.gmailctl)              -> gmailctl --config
#   $2  gopass item      (default gmailctl, under nixerator/)
#   $3  account label    (default dustin@bashfulrobot.com)  -- message only
# Example (Kong work account, reusing the SAME OAuth client entries):
#   ./fetch-gmailctl-credentials.sh ~/.gmailctl-kong gmailctl dustin@konghq.com
GMAILCTL_DIR="${1:-${HOME}/.gmailctl}"
ITEM="${2:-gmailctl}"
ACCOUNT_LABEL="${3:-dustin@bashfulrobot.com}"
CRED_PATH="${GMAILCTL_DIR}/credentials.json"

for tool in gopass jq; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "fetch-gmailctl-credentials: '${tool}' not in PATH." >&2
    echo "  Enable the dev suite on this host and rebuild, OR" >&2
    echo "  re-run inside: nix-shell -p gopass gnupg jq" >&2
    exit 1
  fi
done

ID_ENTRY="nixerator/${ITEM}/client-id"
SECRET_ENTRY="nixerator/${ITEM}/client-secret"
for entry in "${ID_ENTRY}" "${SECRET_ENTRY}"; do
  # Existence check only: the value is tested for non-emptiness and discarded.
  if [[ -z "$(gopass show -o -- "${entry}" 2>/dev/null)" ]]; then
    echo "fetch-gmailctl-credentials: gopass entry ${entry} is missing or empty." >&2
    echo "  On qbert run: just import-secrets-to-gopass --mirror" >&2
    exit 1
  fi
done

mkdir -p "${GMAILCTL_DIR}"
chmod 700 "${GMAILCTL_DIR}"

tmp="$(mktemp -p "${GMAILCTL_DIR}" ".fetch-credentials.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT
chmod 600 "${tmp}"
# Reconstruct credentials.json. gopass output reaches jq through process
# substitution (a pipe), so no value appears on argv or in a file other than the
# 0600 target.
jq -n \
  --rawfile id <(gopass show -o -- "${ID_ENTRY}") \
  --rawfile secret <(gopass show -o -- "${SECRET_ENTRY}") \
  '{installed: {
      client_id: ($id | rtrimstr("\n")),
      client_secret: ($secret | rtrimstr("\n")),
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      redirect_uris: ["http://localhost"]}}' >"${tmp}"
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
