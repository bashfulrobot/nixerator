#!/usr/bin/env bash
# shellcheck shell=bash
#
# Fetches the Okular signature and initials PNGs from the nixerator 1Password
# vault and writes them to ~/.kde/share/icons/{signature,initials}.png where
# Okular's signature-stamp picker looks for them.
#
# 1Password items expected in the `nixerator` vault:
#   - okular-signature (Document) → ~/.kde/share/icons/signature.png
#   - okular-initials  (Document) → ~/.kde/share/icons/initials.png
#
# Uses the SA token at ~/.config/op/service-account-token if present
# (zero biometric prompts). Falls back to whatever the desktop CLI is
# signed in as if not.
#
# Run once per host (after `just setup-op-token`). Re-run only if you ever
# rotate the document in 1Password.
#
# Usage:
#   ./extras/helpers/fetch-okular-signatures.sh
#   just fetch-signatures               (alias: just fs)

set -euo pipefail

ICONS_DIR="${HOME}/.kde/share/icons"
SIG_PATH="${ICONS_DIR}/signature.png"
INIT_PATH="${ICONS_DIR}/initials.png"
SA_TOKEN_FILE="${HOME}/.config/op/service-account-token"

if ! command -v op >/dev/null 2>&1; then
  echo "fetch-okular-signatures: 'op' (1Password CLI) not in PATH." >&2
  echo "  Enable apps.gui.one-password on this host and rebuild, OR" >&2
  echo "  re-run inside: nix-shell -p _1password-cli" >&2
  exit 1
fi

# Service account auto-source — same pattern as render-secrets. Skips
# biometric entirely once `just setup-op-token` has been run.
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -f "${SA_TOKEN_FILE}" ]]; then
  sa_perms="$(stat -c '%a' "${SA_TOKEN_FILE}")"
  if [[ "${sa_perms}" != "600" ]]; then
    echo "fetch-okular-signatures: ${SA_TOKEN_FILE} perms ${sa_perms}, must be 600" >&2
    echo "  Fix:  chmod 600 ${SA_TOKEN_FILE}" >&2
    exit 1
  fi
  OP_SERVICE_ACCOUNT_TOKEN="$(<"${SA_TOKEN_FILE}")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

if ! op whoami >/dev/null 2>&1; then
  echo "fetch-okular-signatures: 'op' not authenticated." >&2
  echo "  Either install the SA token (just setup-op-token), OR run: op signin" >&2
  exit 1
fi

mkdir -p "${ICONS_DIR}"

fetch_one() {
  local title="$1" dest="$2"
  local tmp
  tmp="$(mktemp -p "${ICONS_DIR}" ".fetch-${title}.XXXXXX")"
  trap 'rm -f "${tmp}"' RETURN
  # --force needed because mktemp pre-creates the file, otherwise op asks
  # to confirm overwrite (impossible under SA / non-interactive).
  op document get "${title}" --vault nixerator --out-file "${tmp}" --force
  chmod 644 "${tmp}"
  mv -f "${tmp}" "${dest}"
  trap - RETURN
  echo "fetch-okular-signatures: wrote ${dest}"
}

fetch_one okular-signature "${SIG_PATH}"
fetch_one okular-initials  "${INIT_PATH}"

echo
echo "Done. Both PNGs are at ~/.kde/share/icons/. Re-launch Okular to pick"
echo "them up in the Annotations → Stamp picker."
