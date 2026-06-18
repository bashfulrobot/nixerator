#!/usr/bin/env bash
#
# clanker-install.sh — one-shot bootstrap installer for the `clanker` host.
#
# Run as root from a stock NixOS minimal installer ISO. It:
#   1. Renders the 1Password-backed secrets file the flake reads at eval time.
#   2. Builds the disko format script and the clanker system closure IMPURELY
#      (the flake reads an absolute path outside the repo, so eval must be
#      impure — done once here, up front).
#   3. Wipes/partitions/formats/mounts /dev/vda via the built disko script.
#   4. Installs the prebuilt closure with nixos-install (no re-eval).
#   5. Seeds the dustin user's environment (repo clone, SA token, secrets file,
#      SSH key) inside the installed system so future `just rebuild`s just work.
#
# It is interactive: it prompts once (hidden) for the 1Password service-account
# token. The token is never echoed, never written to the repo, and never put on
# a command line. `set -x` is intentionally NOT used (it would leak the token).
#
# Usage (as root, on a stock NixOS minimal ISO with networking):
#   nix-shell -p git --run 'git clone https://github.com/bashfulrobot/nixerator /tmp/nixerator'
#   sudo bash /tmp/nixerator/extras/helpers/clanker-install.sh
#
# After it finishes: add the printed public key to GitHub (auth + signing),
# then `reboot`. The script does NOT auto-reboot.

set -euo pipefail

# Create every file restricted by default (0600 files / 0700 dirs). Closes the
# brief window between writing the rendered secrets / SA-token files and a later
# chmod — the secret bytes are never world-readable, even momentarily.
umask 077

# --- constants ----------------------------------------------------------------

# The flake reads secrets from this ABSOLUTE path at eval time, baked from
# globals.user.homeDirectory (= /home/dustin) — regardless of who runs the
# install. It must contain rendered secrets before any clanker evaluation.
readonly SECRETS_DIR="/home/dustin/.config/nixos-secrets"
readonly SECRETS_FILE="${SECRETS_DIR}/secrets.json"

# Disko-managed target device for clanker (hosts/clanker/disko.nix).
readonly DISK="/dev/vda"

# --- nix wrapper --------------------------------------------------------------
#
# The stock ISO may not have flakes/nix-command enabled. Wrap every nix call so
# the experimental features are always on. Implemented as a function (not a
# string) to sidestep word-splitting / quoting bugs.
nix_() {
  command nix --extra-experimental-features 'nix-command flakes' "$@"
}

# --- output helpers -----------------------------------------------------------

say() { printf '\n>>> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# --- step 1: preflight --------------------------------------------------------

[[ ${EUID} -eq 0 ]] || die "Must run as root (e.g. sudo bash $0)."

# REPO_ROOT is the directory two levels up from this script (extras/helpers/..).
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_DIR REPO_ROOT

[[ -f "${REPO_ROOT}/flake.nix" ]] ||
  die "flake.nix not found at ${REPO_ROOT}. Is this the nixerator repo?"
[[ -f "${REPO_ROOT}/secrets.json.tpl" ]] ||
  die "secrets.json.tpl not found at ${REPO_ROOT}. Is this the nixerator repo?"

readonly FLAKE="${REPO_ROOT}#clanker"

say "nixerator clanker installer"
printf '  repo:   %s\n' "${REPO_ROOT}"
printf '  flake:  %s\n' "${FLAKE}"
printf '  disk:   %s\n' "${DISK}"

# --- step 2: destructive confirmation -----------------------------------------

cat <<EOF

############################################################################
# WARNING: ${DISK} will be COMPLETELY ERASED.
#
# This runs the clanker disko script, which destroys and repartitions the
# entire disk. Every partition and all data on ${DISK} will be lost.
############################################################################

EOF
read -r -p "Type 'yes' to erase ${DISK} and install clanker: " CONFIRM
[[ "${CONFIRM}" == "yes" ]] || die "Aborted (you did not type 'yes')."

# --- step 3: token prompt -----------------------------------------------------
#
# Hidden read. Never printed; never on a command line; never `set -x`-traced.
read -rsp 'Paste the 1Password service-account token (ops_...): ' OP_SERVICE_ACCOUNT_TOKEN
echo
[[ -n "${OP_SERVICE_ACCOUNT_TOKEN}" ]] || die "Empty token — aborting."
export OP_SERVICE_ACCOUNT_TOKEN

# --- step 4: render secrets ---------------------------------------------------
#
# Render into the absolute path the flake reads at eval time. We call `op inject`
# directly through `nix shell` rather than the repo's render-secrets-bootstrap.sh
# because that helper assumes `op` is already on PATH (true on a built nixerator
# host, NOT on a stock ISO). Driving it via `nix shell -p _1password-cli` keeps
# this script self-contained on a virgin ISO. The token is read from the env we
# just exported, so it never reaches a command line.
say "Rendering secrets to ${SECRETS_FILE}"
mkdir -p "${SECRETS_DIR}"
chmod 700 "${SECRETS_DIR}"
nix_ shell nixpkgs#_1password-cli --command \
  op inject --force -i "${REPO_ROOT}/secrets.json.tpl" -o "${SECRETS_FILE}"
chmod 600 "${SECRETS_FILE}"

# Confirm the file exists and is non-empty WITHOUT printing its contents.
[[ -s "${SECRETS_FILE}" ]] ||
  die "Secrets render produced an empty/missing file at ${SECRETS_FILE}."
say "Secrets rendered ($(wc -c <"${SECRETS_FILE}") bytes)."

# --- step 5: build impurely ---------------------------------------------------
#
# Do the impure eval ONCE here. Disko and nixos-install below consume prebuilt
# store paths and never re-evaluate, so they need no --impure of their own.
say "Building the clanker disko (format) script (impure eval)"
DISKO_SCRIPT="$(
  nix_ build --impure --no-link --print-out-paths \
    "${REPO_ROOT}#nixosConfigurations.clanker.config.system.build.disko"
)"
[[ -n "${DISKO_SCRIPT}" && -e "${DISKO_SCRIPT}" ]] ||
  die "disko build did not produce an output path."

say "Building the clanker system closure (impure eval)"
SYS="$(
  nix_ build --impure --no-link --print-out-paths \
    "${REPO_ROOT}#nixosConfigurations.clanker.config.system.build.toplevel"
)"
[[ -n "${SYS}" && -e "${SYS}" ]] ||
  die "system closure build did not produce an output path."

readonly DISKO_SCRIPT SYS
printf '  disko script: %s\n' "${DISKO_SCRIPT}"
printf '  system:       %s\n' "${SYS}"

# --- step 6: partition / format / mount ---------------------------------------
#
# The disko script wipes ${DISK} per hosts/clanker/disko.nix and mounts the new
# root at /mnt.
say "Running disko: wiping, partitioning, formatting, and mounting ${DISK}"
"${DISKO_SCRIPT}"
mountpoint -q /mnt || die "Expected /mnt to be mounted after disko; it is not."

# --- step 7: install the prebuilt system --------------------------------------
#
# --system points at the already-built closure, so nixos-install does no eval
# and the secrets impurity never arises here.
say "Installing the prebuilt clanker system to /mnt"
nixos-install --root /mnt --system "${SYS}" --no-root-passwd

# --- step 8: seed the dustin user environment ---------------------------------

say "Seeding the dustin user environment under /mnt"

# Create the home subdirs we are about to populate (ownership fixed in step 9).
install -d -m 700 \
  /mnt/home/dustin/git \
  /mnt/home/dustin/.config/op \
  /mnt/home/dustin/.config/nixos-secrets \
  /mnt/home/dustin/.ssh

# Copy the repo clone into the installed home, then drop any build symlink so
# the seeded checkout is clean.
cp -a "${REPO_ROOT}" /mnt/home/dustin/git/nixerator
rm -f /mnt/home/dustin/git/nixerator/result

# Write the SA token so future renders/rebuilds need no biometric and no paste.
# printf (not echo) and a fixed 0600 so the secret is never world/group-readable.
printf '%s' "${OP_SERVICE_ACCOUNT_TOKEN}" \
  >/mnt/home/dustin/.config/op/service-account-token
chmod 600 /mnt/home/dustin/.config/op/service-account-token

# Copy the rendered secrets file so the installed system can eval impurely too.
cp "${SECRETS_FILE}" /mnt/home/dustin/.config/nixos-secrets/secrets.json
chmod 600 /mnt/home/dustin/.config/nixos-secrets/secrets.json

# Generate an ed25519 key for auth + signing if one isn't already present.
if [[ ! -f /mnt/home/dustin/.ssh/id_ed25519 ]]; then
  say "Generating SSH key for dustin@clanker"
  ssh-keygen -t ed25519 -N "" -C "dustin@clanker" \
    -f /mnt/home/dustin/.ssh/id_ed25519
fi
chmod 600 /mnt/home/dustin/.ssh/id_ed25519
chmod 644 /mnt/home/dustin/.ssh/id_ed25519.pub

# --- step 9: fix ownership ----------------------------------------------------
#
# Run inside the installed system so dustin's uid:gid resolves from the target
# user database (created during nixos-install), not the ISO's.
say "Fixing ownership of /home/dustin in the installed system"
nixos-enter --root /mnt -- chown -R dustin:dustin /home/dustin

# --- step 10: finish ----------------------------------------------------------

cat <<EOF

============================================================================
Install complete.

Add this public key to GitHub as BOTH an authentication key and a signing
key (https://github.com/settings/keys):

----------------------------------------------------------------------------
$(cat /mnt/home/dustin/.ssh/id_ed25519.pub)
----------------------------------------------------------------------------

Then reboot:

    reboot

After reboot, log in as dustin. The repo is at ~/git/nixerator and the
secrets + SA token are already in place, so 'just rebuild' works with no
further setup.
============================================================================
EOF
