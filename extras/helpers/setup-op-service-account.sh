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
# How it works: the SA token itself is stored in 1Password at the SAME
# item secrets.json.tpl's onepassword.serviceAccountToken reads from --
# this script extracts that op:// reference from the template rather than
# hardcoding its own copy, so there's one place to update when the item
# changes (e.g. a full SA regeneration, not just a token rotation). We use
# `op read` to fetch it via the desktop biometric session, then atomically
# install it at the canonical path with 0600 perms.
#
# Rotating the token? Use `just rotate-op-token` instead of running this
# script by hand -- it walks the full sequence (1Password steps, install,
# an explicit-token render that bypasses op-toggle's chicken-and-egg
# fallback, and verification) end to end.
#
# Usage (preferred path):
#   ./extras/helpers/setup-op-service-account.sh
#     Requires: 1Password CLI on PATH (nix-shell pulls it), signed-in
#     desktop session (`op signin`), read access to the item
#     secrets.json.tpl's onepassword.serviceAccountToken points at.
#
# Override the source reference (e.g. testing against a different item):
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
#
# Install at a non-default path (e.g. from root on a live USB writing into
# the target user's home before nixos-install):
#   sudo ./extras/helpers/setup-op-service-account.sh \
#       --dest /home/dustin/.config/op/service-account-token

set -euo pipefail

# Default destination: the current user's ~/.config/op/. Overridable via
# --dest for live-USB bootstrap (writing into /home/dustin/... from root).
DEST="${HOME}/.config/op/service-account-token"

# Canonical reference for the SA token in 1Password. Derived from
# secrets.json.tpl's own onepassword.serviceAccountToken entry (pinned to
# an item ID there, not a name) so this script and the template can never
# drift to two different items. OP_TOKEN_REF still overrides explicitly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DEFAULT="${SCRIPT_DIR}/../../secrets.json.tpl"
TOKEN_REF_FROM_TPL=""
if [[ -f "${TPL_DEFAULT}" ]]; then
  TOKEN_REF_FROM_TPL="$(sed -n 's#.*"serviceAccountToken": *"{{ *\(op://[^ ]*\) *}}".*#\1#p' "${TPL_DEFAULT}")"
fi
TOKEN_REF="${OP_TOKEN_REF:-${TOKEN_REF_FROM_TPL}}"

MANUAL=0
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manual)
      MANUAL=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dest)
      shift
      [[ $# -gt 0 ]] || {
        echo "--dest requires a PATH argument" >&2
        exit 2
      }
      DEST="$1"
      shift
      ;;
    -h | --help)
      sed -n '4,50p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

DEST_DIR="$(dirname "${DEST}")"

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
    if [[ -z "${TOKEN_REF}" ]]; then
      echo "setup-op-service-account: couldn't find onepassword.serviceAccountToken in ${TPL_DEFAULT}" >&2
      echo "  Set OP_TOKEN_REF=op://Vault/Item/field explicitly, or use --manual / OP_TOKEN= / stdin." >&2
      exit 1
    fi
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
if [[ "${DEST}" != "${HOME}/.config/op/service-account-token" ]]; then
  echo "  NOTE: --dest used. If this is bootstrap-install-secrets staging,"
  echo "  remember to chown the file to the target user before reboot."
fi
