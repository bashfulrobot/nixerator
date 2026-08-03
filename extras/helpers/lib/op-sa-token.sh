#!/usr/bin/env bash
# shellcheck shell=bash
#
# Shared 1Password service-account token auto-source helper. Sourced by the
# extras/helpers/*.sh scripts that need `op` authenticated without a desktop
# biometric prompt.
#
# NOT usable by modules/apps/cli/render-secrets/render-secrets.sh: that script
# is packaged into a single self-contained file installed straight into the
# Nix store (see its default.nix — `install -Dm755 $src $out/bin/render-secrets`,
# no sibling files travel with it), so it keeps its own inlined copy of this
# same logic rather than sourcing this file, which would not exist at its
# runtime location.
#
# Usage (caller must compute SCRIPT_DIR first, e.g. via
#   SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
# ):
#   source "${SCRIPT_DIR}/lib/op-sa-token.sh"
#   op_source_sa_token "my-script-name"
#
# On success, sets/exports OP_SERVICE_ACCOUNT_TOKEN when a token file is found
# at the canonical path and OP_SERVICE_ACCOUNT_TOKEN wasn't already set. Exits
# 1 (with a chmod hint) if the token file exists with unsafe permissions.
#
# Also exports OP_SA_TOKEN_FILE (the canonical path) for callers that reference
# it in their own "not authenticated" messages.

OP_SA_TOKEN_FILE="${HOME}/.config/op/service-account-token"

op_source_sa_token() {
  local script_name="$1"
  if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -f "${OP_SA_TOKEN_FILE}" ]]; then
    local sa_perms
    sa_perms="$(stat -c '%a' "${OP_SA_TOKEN_FILE}")"
    if [[ "${sa_perms}" != "600" ]]; then
      echo "${script_name}: ${OP_SA_TOKEN_FILE} perms ${sa_perms}, must be 600" >&2
      echo "  Fix:  chmod 600 ${OP_SA_TOKEN_FILE}" >&2
      exit 1
    fi
    OP_SERVICE_ACCOUNT_TOKEN="$(<"${OP_SA_TOKEN_FILE}")"
    export OP_SERVICE_ACCOUNT_TOKEN
  fi
}
