#!/usr/bin/env nix-shell
#! nix-shell -i bash -p _1password-cli coreutils
# shellcheck shell=bash
#
# Live-USB orchestrator for the nixerator secrets bootstrap. Walks the user
# through staging the SA token + rendered secrets file so that:
#   - nixos-install can read /home/dustin/.config/nixos-secrets/secrets.json
#     during the install eval.
#   - The installed system, after first boot, has the same files in place
#     so daily-driver workflows (just qr, just render-secrets) work
#     immediately with zero biometric prompts.
#
# Usage (run from the nixerator repo root on the live USB):
#
#   ./extras/helpers/bootstrap-install-secrets.sh stage
#     PRE-install. Verifies op signin, fetches the SA token from your
#     Personal vault via `op read`, renders secrets, and stages both under
#     /home/dustin/. Run this BEFORE `sudo nixos-install`.
#
#   ./extras/helpers/bootstrap-install-secrets.sh promote
#     POST-install (before reboot). Copies the staged files from
#     /home/dustin/ into /mnt/home/dustin/ on the target filesystem, then
#     chowns to the install user. Run this AFTER `sudo nixos-install` and
#     BEFORE `umount /mnt && reboot`.
#
# Both subcommands are interactive: they print what they're about to do,
# confirm before touching anything destructive, and tell you what to do
# next. Safe to re-run -- the underlying helpers are idempotent.
#
# Override the install user (default: dustin, matching settings/globals.nix):
#   INSTALL_USER=somebody ./extras/helpers/bootstrap-install-secrets.sh stage
#
# Override the 1Password reference for the SA token (default matches
# setup-op-service-account.sh's TOKEN_REF_DEFAULT):
#   OP_TOKEN_REF=op://Vault/Item/field ./extras/helpers/bootstrap-install-secrets.sh stage

set -euo pipefail

INSTALL_USER="${INSTALL_USER:-dustin}"
TARGET_HOME="/home/${INSTALL_USER}"

# Resolve repo root from the script location so the helper works regardless
# of cwd. Subcommands invoke the other helpers via these paths.
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# --- output helpers -----------------------------------------------------------

# Coloured terminal output, falls back to plain on non-TTY.
if [[ -t 1 ]]; then
  C_HEAD=$'\033[1;36m'   # bold cyan
  C_OK=$'\033[1;32m'     # bold green
  C_WARN=$'\033[1;33m'   # bold yellow
  C_ERR=$'\033[1;31m'    # bold red
  C_DIM=$'\033[2m'       # dim
  C_RESET=$'\033[0m'
else
  C_HEAD="" C_OK="" C_WARN="" C_ERR="" C_DIM="" C_RESET=""
fi

heading() { echo; echo "${C_HEAD}=== $* ===${C_RESET}"; }
ok()      { echo "${C_OK}✓${C_RESET} $*"; }
warn()    { echo "${C_WARN}!${C_RESET} $*" >&2; }
fail()    { echo "${C_ERR}✗${C_RESET} $*" >&2; exit 1; }
note()    { echo "${C_DIM}  $*${C_RESET}"; }

confirm() {
  local prompt="${1:-Continue?}"
  local reply
  read -r -p "$(printf '%s [y/N] ' "${prompt}")" reply
  case "${reply}" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

# --- subcommand: stage --------------------------------------------------------

cmd_stage() {
  heading "Pre-install bootstrap (live USB)"
  cat <<EOF
This script will:

  1. Verify the 1Password CLI is signed in (one-time interactive sign-in if not).
  2. Fetch the nixerator service-account token from your Personal vault via
     'op read' (one biometric prompt -- the only one you'll see).
  3. Install the token at:  ${TARGET_HOME}/.config/op/service-account-token  (0600)
  4. Render secrets to:     ${TARGET_HOME}/.config/nixos-secrets/secrets.json (0600)

Both paths use ${TARGET_HOME} (the future installed user's home directory)
because the flake.nix reads secretsFile from a path baked from
globals.user.homeDirectory at eval time -- regardless of who runs
nixos-install.

After this script, you'll proceed with the standard nixos-install steps
(disko / hardware-config / nixos-install). Then re-run this script with the
'promote' subcommand to copy the staged files onto /mnt before reboot.
EOF
  echo
  confirm "Proceed with staging?" || { warn "Aborted by user."; exit 0; }

  # Step 1: prereqs ------------------------------------------------------------
  heading "Step 1: Verify prerequisites"

  [[ -f "${REPO_ROOT}/secrets.json.tpl" ]] || \
    fail "secrets.json.tpl not found at ${REPO_ROOT}. Are you in the nixerator repo?"
  ok "Template at ${REPO_ROOT}/secrets.json.tpl"

  if [[ $EUID -ne 0 ]]; then
    fail "stage must run as root (writes into ${TARGET_HOME}). Re-run with sudo."
  fi
  ok "Running as root"

  # Step 2: op signin ----------------------------------------------------------
  heading "Step 2: 1Password CLI sign-in"

  # `op whoami` works for both desktop biometric AND service-account sessions.
  if op whoami >/dev/null 2>&1; then
    ok "1Password CLI already signed in: $(op whoami 2>/dev/null | head -1)"
  else
    cat <<EOF
1Password CLI not signed in. You'll be prompted for:
  - Your 1Password account email
  - Your secret key (from your 1Password emergency kit)
  - Your account password
EOF
    echo
    confirm "Sign in to 1Password now?" || fail "Cannot proceed without 1Password sign-in."
    # `op signin` is interactive — it sets up the local session.
    if ! op signin; then
      fail "op signin failed. See https://developer.1password.com/docs/cli/sign-in-manually"
    fi
    ok "Signed in"
  fi

  # Step 3: install the SA token ----------------------------------------------
  heading "Step 3: Install service-account token to ${TARGET_HOME}/.config/op/"

  mkdir -p "${TARGET_HOME}/.config/op"
  chmod 700 "${TARGET_HOME}/.config/op"
  "${SCRIPT_DIR}/setup-op-service-account.sh" \
    --dest "${TARGET_HOME}/.config/op/service-account-token"
  ok "SA token installed at ${TARGET_HOME}/.config/op/service-account-token"

  # Step 4: render the secrets file -------------------------------------------
  heading "Step 4: Render secrets to ${TARGET_HOME}/.config/nixos-secrets/"

  mkdir -p "${TARGET_HOME}/.config/nixos-secrets"
  chmod 700 "${TARGET_HOME}/.config/nixos-secrets"
  # render-secrets-bootstrap.sh auto-sources OP_SERVICE_ACCOUNT_TOKEN from
  # the token file we just installed, so this runs with no biometric prompt.
  HOME="${TARGET_HOME}" "${SCRIPT_DIR}/render-secrets-bootstrap.sh" \
    --dest "${TARGET_HOME}/.config/nixos-secrets/secrets.json"
  ok "Secrets rendered at ${TARGET_HOME}/.config/nixos-secrets/secrets.json"

  # Done ----------------------------------------------------------------------
  heading "Stage complete"
  cat <<EOF
${C_OK}Ready to install.${C_RESET}

Next steps (from bootstrap.txt):
  - Step 5-6: verify disk, run disko to partition
  - Step 7:   generate hardware-configuration.nix
  - Step 8:   sudo nixos-install --impure --flake ".#\$TARGET_HOST"

When nixos-install finishes (BEFORE reboot), come back and run:
  sudo ${SCRIPT_DIR}/bootstrap-install-secrets.sh promote

EOF
}

# --- subcommand: promote ------------------------------------------------------

cmd_promote() {
  heading "Post-install promotion (live USB, /mnt mounted, pre-reboot)"
  cat <<EOF
This script will:

  1. Verify /mnt is mounted and has a NixOS install on it.
  2. Verify the staged files exist at ${TARGET_HOME}/.config/...
  3. Verify the install user (${INSTALL_USER}) exists on the target.
  4. Copy:
       ${TARGET_HOME}/.config/op/service-account-token
       ${TARGET_HOME}/.config/nixos-secrets/secrets.json
     into /mnt${TARGET_HOME}/.config/...
  5. chown both directories to ${INSTALL_USER}:users on the target.

After this completes, finish bootstrap.txt:
  Step 10: set passwords with nixos-enter
  Step 11: umount /mnt && reboot
EOF
  echo
  confirm "Proceed with promotion?" || { warn "Aborted by user."; exit 0; }

  # Step 1: /mnt sanity --------------------------------------------------------
  heading "Step 1: Verify /mnt"

  [[ -d /mnt ]] || fail "/mnt does not exist."
  mountpoint -q /mnt || fail "/mnt is not a mountpoint. Did nixos-install run?"
  [[ -f /mnt/etc/NIXOS ]] || \
    fail "/mnt doesn't look like a NixOS install (no /mnt/etc/NIXOS)."
  ok "/mnt is mounted and looks like a NixOS install"

  if [[ $EUID -ne 0 ]]; then
    fail "promote must run as root (writes into /mnt). Re-run with sudo."
  fi
  ok "Running as root"

  # Step 2: staged files exist ------------------------------------------------
  heading "Step 2: Verify staged files exist on live USB"

  local SRC_TOKEN="${TARGET_HOME}/.config/op/service-account-token"
  local SRC_SECRETS="${TARGET_HOME}/.config/nixos-secrets/secrets.json"

  [[ -f "${SRC_TOKEN}" ]] || \
    fail "Staged SA token not found at ${SRC_TOKEN}. Did 'stage' run first?"
  ok "SA token staged at ${SRC_TOKEN}"

  [[ -f "${SRC_SECRETS}" ]] || \
    fail "Staged secrets file not found at ${SRC_SECRETS}. Did 'stage' run first?"
  ok "Secrets file staged at ${SRC_SECRETS}"

  # Step 3: install user exists on target -------------------------------------
  heading "Step 3: Verify install user '${INSTALL_USER}' exists on target"

  local UID_GID
  if ! UID_GID="$(nixos-enter --root /mnt -c "id -u ${INSTALL_USER} && id -g ${INSTALL_USER}" 2>/dev/null)"; then
    fail "User '${INSTALL_USER}' doesn't exist on the target filesystem.
  This is set in settings/globals.nix and gets created on first activation
  during nixos-install. If you set INSTALL_USER to override the default,
  verify the value matches what's in globals.nix."
  fi
  local TARGET_UID TARGET_GID
  TARGET_UID="$(echo "${UID_GID}" | head -1)"
  TARGET_GID="$(echo "${UID_GID}" | tail -1)"
  ok "User '${INSTALL_USER}' exists on target with uid=${TARGET_UID} gid=${TARGET_GID}"

  # Step 4: copy --------------------------------------------------------------
  heading "Step 4: Copy staged files into /mnt${TARGET_HOME}/.config/"

  local DST_OP="/mnt${TARGET_HOME}/.config/op"
  local DST_NS="/mnt${TARGET_HOME}/.config/nixos-secrets"

  mkdir -p "${DST_OP}" "${DST_NS}"
  install -m 0600 "${SRC_TOKEN}"   "${DST_OP}/service-account-token"
  install -m 0600 "${SRC_SECRETS}" "${DST_NS}/secrets.json"
  chmod 700 "${DST_OP}" "${DST_NS}"
  ok "Copied to ${DST_OP}/ and ${DST_NS}/"

  # Step 5: chown -------------------------------------------------------------
  heading "Step 5: chown to ${INSTALL_USER}:users on target"

  # chown via nixos-enter so the uid:gid is resolved on the target system,
  # not the live USB (where the user may not exist or may have a different id).
  nixos-enter --root /mnt -c "chown -R ${INSTALL_USER}:users \
    ${TARGET_HOME}/.config/op \
    ${TARGET_HOME}/.config/nixos-secrets"
  ok "Ownership set on target"

  # Done ----------------------------------------------------------------------
  heading "Promote complete"
  cat <<EOF
${C_OK}Secrets are ready for first boot.${C_RESET}

When you reboot and log in as ${INSTALL_USER}, 'just qr' will read from
${TARGET_HOME}/.config/nixos-secrets/secrets.json directly (no git-crypt
transit, no biometric).

Remaining bootstrap.txt steps:
  Step 10: sudo nixos-enter --root /mnt -c 'passwd root'
           sudo nixos-enter --root /mnt -c "passwd ${INSTALL_USER}"
  Step 11: sudo umount -R /mnt && sudo reboot

EOF
}

# --- dispatch -----------------------------------------------------------------

usage() {
  sed -n '5,32p' "$0" >&2
  exit "${1:-2}"
}

case "${1:-}" in
  stage) shift; cmd_stage "$@" ;;
  promote) shift; cmd_promote "$@" ;;
  -h | --help | help | "") usage 0 ;;
  *)
    echo "Unknown subcommand: $1" >&2
    echo "Use: $(basename "$0") {stage|promote}" >&2
    exit 2
    ;;
esac
