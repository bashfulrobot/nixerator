#!/usr/bin/env nix-shell
#! nix-shell -i bash -p gopass gnupg jq gawk gnugrep coreutils git openssh diffutils findutils gnused
# shellcheck shell=bash
#
# Live-USB secrets bootstrap that needs no 1Password service account. It replaces
# the old service-account bootstrap scripts, which are removed (see
# extras/docs/secrets-roadmap.md). NOT yet run on a real install: test it in a
# VM before relying on it.
#
# What it stages, from an existing host you can reach over SSH (SOURCE_SSH):
#   - the secauto GPG key, streamed into ~/.gnupg (never written to a file here)
#   - the encrypted secauto store (a tar of ciphertext, safe to copy)
#   - secrets.json, rendered from that store with `render-secrets --from gopass`
#     (RENDER_SECRETS_ALLOW_MISSING=1, so a bootstrap does not stop on a required
#     entry that has not been imported yet)
# It does not restore the SSH or git-crypt keys: those stay in 1Password and come
# back after first boot with `just render-secrets-op` (desktop session, one prompt).
#
# Usage (run from the nixerator repo root on the live USB, as root):
#   SOURCE_SSH=user@host INSTALL_USER=dustin ./extras/helpers/bootstrap-install-gopass.sh stage
#   ... sudo nixos-install --impure --flake ".#$TARGET_HOST" ...
#   INSTALL_USER=dustin ./extras/helpers/bootstrap-install-gopass.sh promote
#
# SOURCE_STORE (default ~/.local/share/gopass/stores/root on the source) and
# SECAUTO_UID (default 'secauto automation') can be overridden.
# shellcheck disable=SC2029 # the ssh commands below expand variables on this side on purpose
set -euo pipefail

INSTALL_USER="${INSTALL_USER:-dustin}"
TARGET_HOME="/home/${INSTALL_USER}"
SOURCE_SSH="${SOURCE_SSH:-}"
SOURCE_STORE="${SOURCE_STORE:-.local/share/gopass/stores/root}"
SECAUTO_UID="${SECAUTO_UID:-secauto automation}"

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RS_DIR="${REPO_ROOT}/modules/apps/cli/render-secrets"

say() { printf '%s\n' "$*"; }
fail() {
  printf 'bootstrap-install-gopass: %s\n' "$*" >&2
  exit 1
}

ssh_opts=(-o BatchMode=yes -o ConnectTimeout=8)

cmd_stage() {
  [[ $EUID -eq 0 ]] || fail "stage must run as root (it writes into ${TARGET_HOME}). Re-run with sudo."
  [[ -n "${SOURCE_SSH}" ]] || fail "set SOURCE_SSH=user@host (an existing nixerator host, normally qbert)."
  [[ -r "${RS_DIR}/render-secrets.sh" ]] || fail "run this from the nixerator repo (render-secrets.sh not found)."
  ssh "${ssh_opts[@]}" "${SOURCE_SSH}" true || fail "cannot reach ${SOURCE_SSH} over SSH with the keys on this live USB."

  say "1/4 Stream the secauto GPG key from ${SOURCE_SSH}"
  install -d -m 700 -o root -g root "${TARGET_HOME}" "${TARGET_HOME}/.gnupg"
  local fpr
  fpr="$(ssh "${ssh_opts[@]}" "${SOURCE_SSH}" "gpg --list-keys --with-colons '${SECAUTO_UID}' 2>/dev/null | awk -F: '/^fpr/ {print \$10; exit}'")"
  [[ -n "${fpr}" ]] || fail "no '${SECAUTO_UID}' key in ${SOURCE_SSH}'s keyring."
  ssh "${ssh_opts[@]}" "${SOURCE_SSH}" "gpg --export-secret-keys --armor '${fpr}'" |
    GNUPGHOME="${TARGET_HOME}/.gnupg" gpg --batch --pinentry-mode loopback --passphrase '' --import >/dev/null 2>&1
  echo "${fpr}:6:" | GNUPGHOME="${TARGET_HOME}/.gnupg" gpg --import-ownertrust >/dev/null 2>&1
  GNUPGHOME="${TARGET_HOME}/.gnupg" gpg --list-secret-keys --with-colons 2>/dev/null | grep -q "${fpr}" ||
    fail "the secauto key did not import."

  say "2/4 Copy the encrypted secauto store (ciphertext only)"
  install -d -m 700 "${TARGET_HOME}/.local/share/gopass/stores"
  ssh "${ssh_opts[@]}" "${SOURCE_SSH}" "tar -C \"\$(dirname \"\$HOME/${SOURCE_STORE}\")\" -cf - \"\$(basename \"${SOURCE_STORE}\")\"" |
    tar -C "${TARGET_HOME}/.local/share/gopass/stores" -xf -
  [[ -d "${TARGET_HOME}/.local/share/gopass/stores/root" ]] || fail "the store did not arrive."

  say "3/4 Render secrets.json from gopass"
  local run dest_dir
  dest_dir="${TARGET_HOME}/.config/nixos-secrets"
  install -d -m 700 "${dest_dir}"
  run="$(mktemp)"
  # Fill the build-time placeholders the Nix module normally substitutes.
  sed -e "s|@DEST@|${dest_dir}/secrets.json|" \
    -e "s|@TPL@|${REPO_ROOT}/secrets.json.tpl|" \
    -e "s|@MAP@|${RS_DIR}/gopass-map.tsv|" \
    -e "s|@DOCS@|${RS_DIR}/gopass-documents.psv|" "${RS_DIR}/render-secrets.sh" >"${run}"
  HOME="${TARGET_HOME}" GNUPGHOME="${TARGET_HOME}/.gnupg" RENDER_SECRETS_ALLOW_MISSING=1 \
    bash "${run}" --from gopass || {
    rm -f "${run}"
    fail "render failed; read the output above."
  }
  rm -f "${run}"

  say "4/4 Lock down permissions"
  chmod 600 "${dest_dir}/secrets.json"
  chmod -R go-rwx "${TARGET_HOME}/.gnupg" "${TARGET_HOME}/.local/share/gopass" "${dest_dir}"
  say
  say "Staged. Next: nixos-install, then run: ${0} promote"
  say "After first boot, restore the SSH and git-crypt keys: just render-secrets-op"
}

cmd_promote() {
  [[ $EUID -eq 0 ]] || fail "promote must run as root."
  mountpoint -q /mnt || fail "/mnt is not a mountpoint. Did nixos-install run?"
  [[ -f /mnt/etc/NIXOS ]] || fail "/mnt does not look like a NixOS install."
  local ids uid gid
  ids="$(nixos-enter --root /mnt -c "id -u ${INSTALL_USER} && id -g ${INSTALL_USER}" 2>/dev/null)" ||
    fail "user '${INSTALL_USER}' does not exist on the target."
  uid="$(head -1 <<<"${ids}")"
  gid="$(tail -1 <<<"${ids}")"
  for p in .gnupg .config/nixos-secrets .local/share/gopass; do
    [[ -e "${TARGET_HOME}/${p}" ]] || fail "${TARGET_HOME}/${p} is not staged. Run stage first."
    install -d -m 700 "/mnt${TARGET_HOME}/$(dirname "${p}")"
    cp -a "${TARGET_HOME}/${p}" "/mnt${TARGET_HOME}/$(dirname "${p}")/"
  done
  chown -R "${uid}:${gid}" "/mnt${TARGET_HOME}/.gnupg" "/mnt${TARGET_HOME}/.config/nixos-secrets" "/mnt${TARGET_HOME}/.local/share/gopass"
  say "Promoted to /mnt${TARGET_HOME}. Finish bootstrap.txt (passwords, umount, reboot)."
}

case "${1:-}" in
  stage) cmd_stage ;;
  promote) cmd_promote ;;
  *)
    say "usage: bootstrap-install-gopass.sh stage | promote"
    exit 2
    ;;
esac
