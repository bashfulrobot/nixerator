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

if ! op account list >/dev/null 2>&1; then
    echo "render-secrets-bootstrap: 1Password CLI not signed in." >&2
    echo "  Run: op signin   (then re-run this script)" >&2
    exit 1
fi

mkdir -p "${DEST_DIR}"
chmod 700 "${DEST_DIR}"

# Atomic write: render to tmp in the same dir, chmod, then mv. Partial
# op-inject failure leaves any existing DEST untouched.
tmp="$(mktemp -p "${DEST_DIR}" .render-secrets-bootstrap.XXXXXX)"
trap 'rm -f "${tmp}"' EXIT
op inject -i "${TPL}" -o "${tmp}"
chmod 600 "${tmp}"
mv -f "${tmp}" "${DEST}"
echo "render-secrets-bootstrap: wrote ${DEST}"
echo "  Next: sudo nixos-rebuild switch --impure --flake .#\$(hostname)"
echo "  After that rebuild lands, use 'just render-secrets' for future rotations."
