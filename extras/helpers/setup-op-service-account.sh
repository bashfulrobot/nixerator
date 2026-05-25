#!/usr/bin/env bash
# shellcheck shell=bash
#
# This is a post-install helper -- it expects `op` (1Password CLI) to be
# already on PATH (enable `apps.gui.one-password` on the host, or wrap the
# call in `nix-shell -p _1password-cli` if running on a host without the
# module). The plain bash shebang avoids the nix-shell+NIX_PATH dance that
# breaks on hosts with `nix.nixPath = [ ]` (the nixerator default).
#
# Install the nixerator 1Password service-account token at the canonical
# path (~/.config/op/service-account-token, perms 0600). After this script
# runs once on a host, render-secrets and render-secrets-bootstrap.sh both
# auto-source from the file with NO further biometric prompts -- this
# helper's one `op read` is the only biometric you'll see.
#
# How it works: the SA token itself is stored in your Personal 1Password
# vault. We use `op read` to fetch it via the desktop biometric session,
# then atomically install it at the canonical path with 0600 perms.
#
# Usage (preferred path):
#   ./extras/helpers/setup-op-service-account.sh
#     Requires: 1Password CLI on PATH (nix-shell pulls it), signed-in
#     desktop session (`op signin`), read access to the Personal vault
#     item below.
#
# Override the source reference (e.g. token moved to another vault):
#   OP_TOKEN_REF=op://Vault/Item/field ./extras/helpers/setup-op-service-account.sh
#
# Bypass `op read` and paste / pipe / env-supply the token directly --
# useful when the desktop 1Password session isn't available on this host:
#   ./extras/helpers/setup-op-service-account.sh --manual
#   ./extras/helpers/setup-op-service-account.sh < /path/to/token-file
#   OP_TOKEN=ops_... ./extras/helpers/setup-op-service-account.sh
#
# Overwrite an existing different token (default is to refuse):
#   ./extras/helpers/setup-op-service-account.sh --force

set -euo pipefail

DEST_DIR="${HOME}/.config/op"
DEST="${DEST_DIR}/service-account-token"

# Canonical reference for the SA token in 1Password. Pinned to the item ID
# (not name) so renames don't break this script.
TOKEN_REF_DEFAULT="op://Personal/r6auiogd4j3xaapmfn6bh7ul6m/credential"
TOKEN_REF="${OP_TOKEN_REF:-${TOKEN_REF_DEFAULT}}"

MANUAL=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --manual) MANUAL=1 ;;
    --force) FORCE=1 ;;
    -h | --help)
      sed -n '4,32p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

if ! command -v op >/dev/null 2>&1; then
  echo "setup-op-service-account: 'op' (1Password CLI) not in PATH." >&2
  echo "  Either:" >&2
  echo "    - Enable apps.gui.one-password on this host and rebuild, OR" >&2
  echo "    - Re-run inside: nix-shell -p _1password-cli ..." >&2
  echo "  (--manual / OP_TOKEN= / piped stdin do not need op, but the helper" >&2
  echo "  still imports op for the default --op-read path; rerun with one of" >&2
  echo "  those alternate inputs if op truly isn't available here.)" >&2
  exit 1
fi

read_token() {
  local t
  if [[ -n "${OP_TOKEN:-}" ]]; then
    # Explicit env var wins.
    t="${OP_TOKEN}"
  elif [[ ! -t 0 ]]; then
    # Stdin is piped/redirected.
    t="$(cat)"
  elif [[ "${MANUAL}" -eq 1 ]]; then
    echo "Paste the 1Password service-account token (starts with 'ops_'), then Enter:" >&2
    read -r t
  else
    # Default: fetch via `op read` (one biometric prompt on the desktop).
    if ! op whoami >/dev/null 2>&1; then
      echo "setup-op-service-account: 'op' not signed in." >&2
      echo "  Run:  op signin" >&2
      echo "  Or use --manual / OP_TOKEN= / stdin to provide the token directly." >&2
      exit 1
    fi
    echo "Reading SA token from ${TOKEN_REF} (will trigger one biometric prompt)..." >&2
    t="$(op read "${TOKEN_REF}")"
  fi
  # Strip surrounding whitespace defensively (trailing newline from cat,
  # stray paste artefacts).
  t="${t#"${t%%[![:space:]]*}"}"
  t="${t%"${t##*[![:space:]]}"}"
  printf '%s' "$t"
}

token="$(read_token)"

if [[ -z "$token" ]]; then
  echo "setup-op-service-account: empty token, refusing." >&2
  exit 1
fi

if [[ "$token" != ops_* ]]; then
  echo "setup-op-service-account: token doesn't start with 'ops_', refusing." >&2
  echo "  1Password service-account tokens always start with 'ops_'." >&2
  echo "  Got prefix: '${token:0:8}...'" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
chmod 700 "${DEST_DIR}"

if [[ -f "${DEST}" ]]; then
  existing="$(<"${DEST}")"
  if [[ "${existing}" == "${token}" ]]; then
    chmod 600 "${DEST}"
    echo "setup-op-service-account: token at ${DEST} already matches. Perms reset to 600."
    exit 0
  fi
  if [[ ${FORCE} -eq 0 ]]; then
    echo "setup-op-service-account: ${DEST} exists and differs from input." >&2
    echo "  To replace, re-run with --force." >&2
    exit 1
  fi
fi

# Atomic write: render to tmp inside DEST_DIR, chmod, then mv -f.
tmp="$(mktemp -p "${DEST_DIR}" .token.XXXXXX)"
trap 'rm -f "${tmp}"' EXIT
printf '%s' "${token}" >"${tmp}"
chmod 600 "${tmp}"
mv -f "${tmp}" "${DEST}"

echo "setup-op-service-account: installed token at ${DEST} (0600)."
echo "  Verify (no biometric prompt expected):"
echo "    OP_SERVICE_ACCOUNT_TOKEN=\"\$(cat ${DEST})\" op vault list"
