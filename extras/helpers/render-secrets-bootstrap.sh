#!/usr/bin/env nix-shell
#! nix-shell -i bash -p _1password-cli coreutils
# shellcheck shell=bash
#
# Pre-rebuild bootstrap helper. Renders ~/.config/nixos-secrets/secrets.json
# from secrets.json.tpl via `op inject`, without needing render-secrets on
# PATH yet.
#
# Use this script ONLY when:
#   - Setting up a new machine from this repo, AND
#   - You want the 1Password flow active for the FIRST rebuild (vs. letting
#     the git-crypt fallback handle bootstrap and switching to 1Password later
#     via `just render-secrets`).
#
# After the first successful rebuild, this script is obsolete on that host —
# use the on-PATH render-secrets / `just render-secrets` instead. The two
# produce identical output; this script just doesn't depend on the Nix store
# having render-secrets installed yet.
#
# Prerequisites:
#   - Nix installed (with flakes enabled). The nix-shell shebang pulls op.
#   - 1Password CLI signed in (`op signin`).
#   - Read access to the `nixerator` 1Password vault.
#
# Usage (from the repo root):
#   ./extras/helpers/render-secrets-bootstrap.sh
#
# Does NOT push to peers — for that, wait for the on-PATH render-secrets
# after the first rebuild lands and use `just push-secrets <host>`.

set -euo pipefail

DEST="${HOME}/.config/nixos-secrets/secrets.json"
DEST_DIR="$(dirname "${DEST}")"

# Resolve repo root from the script location so the helper works regardless
# of cwd.
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TPL="${REPO_ROOT}/secrets.json.tpl"

if [[ ! -f "${TPL}" ]]; then
  echo "render-secrets-bootstrap: template not found at ${TPL}" >&2
  echo "  Are you running this from the nixerator repo?" >&2
  exit 1
fi

# Service account auto-source — same logic as the on-PATH render-secrets
# (intentionally duplicated since this helper is the pre-rebuild bootstrap
# and shouldn't depend on the Nix-wrapped script being available). If a
# token file exists at the canonical path, the helper uses it and skips
# the desktop biometric path entirely.
SA_TOKEN_FILE="${HOME}/.config/op/service-account-token"
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -f "${SA_TOKEN_FILE}" ]]; then
  sa_perms="$(stat -c '%a' "${SA_TOKEN_FILE}")"
  if [[ "${sa_perms}" != "600" ]]; then
    echo "render-secrets-bootstrap: ${SA_TOKEN_FILE} perms ${sa_perms}, must be 600" >&2
    echo "  Fix:  chmod 600 ${SA_TOKEN_FILE}" >&2
    exit 1
  fi
  OP_SERVICE_ACCOUNT_TOKEN="$(<"${SA_TOKEN_FILE}")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

# Sanity-check auth: SA mode succeeds on `op whoami`; desktop biometric mode
# needs an active session. `op whoami` works for both — `op account list`
# does not, because SA tokens aren't desktop accounts.
if ! op whoami >/dev/null 2>&1; then
  echo "render-secrets-bootstrap: 1Password CLI not authenticated." >&2
  echo "  Either:" >&2
  echo "    - Set OP_SERVICE_ACCOUNT_TOKEN (or put the token in ${SA_TOKEN_FILE} with 0600 perms), OR" >&2
  echo "    - Run: op signin   (interactive desktop biometric)" >&2
  echo "  Then re-run this script." >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
chmod 700 "${DEST_DIR}"

# Atomic write: render to tmp in the same dir, chmod, then mv. Partial
# op-inject failure leaves any existing DEST untouched.
tmp="$(mktemp -p "${DEST_DIR}" .render-secrets-bootstrap.XXXXXX)"
trap 'rm -f "${tmp}"' EXIT
op inject --force -i "${TPL}" -o "${tmp}"
chmod 600 "${tmp}"
mv -f "${tmp}" "${DEST}"
echo "render-secrets-bootstrap: wrote ${DEST}"
echo "  Next: sudo nixos-rebuild switch --impure --flake .#\$(hostname)"
echo "  After that rebuild lands, use 'just render-secrets' for future rotations."
