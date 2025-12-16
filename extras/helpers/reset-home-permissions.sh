#!/usr/bin/env bash
# Reset permissions for home directory, SSH keys, and GPG keys
# This script ensures proper security permissions for SSH and GPG functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the actual home directory (not root's home when using sudo)
if [ -n "${SUDO_USER:-}" ]; then
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER_NAME="$SUDO_USER"
    USER_GROUP=$(id -gn "$SUDO_USER")
else
    HOME_DIR="$HOME"
    USER_NAME="$USER"
    USER_GROUP=$(id -gn)
fi

echo -e "${GREEN}🔒 Resetting permissions for $USER_NAME:$USER_GROUP ($HOME_DIR)${NC}"
echo ""

# Function to set permissions and ownership
set_perms() {
    local path="$1"
    local perms="$2"
    local description="$3"

    if [ -e "$path" ]; then
        echo -e "${YELLOW}→${NC} $description"
        sudo chmod "$perms" "$path"
        sudo chown "$USER_NAME:$USER_GROUP" "$path"
        echo -e "  ${GREEN}✓${NC} Set to $perms: $path"
    fi
}

# Fix home directory permissions (ensure user ownership, don't restrict perms)
echo -e "${GREEN}📁 Home Directory${NC}"
sudo chown "$USER_NAME:$USER_GROUP" "$HOME_DIR"
echo -e "  ${GREEN}✓${NC} Fixed ownership: $HOME_DIR"
echo ""

# Fix .ssh directory and files
echo -e "${GREEN}🔑 SSH Directory and Keys${NC}"
SSH_DIR="$HOME_DIR/.ssh"

if [ -d "$SSH_DIR" ]; then
    # SSH directory itself
    set_perms "$SSH_DIR" "700" "SSH directory"

    # SSH config file
    set_perms "$SSH_DIR/config" "600" "SSH config"

    # Private keys (id_*, *_rsa, *_ed25519, *_ecdsa, etc.)
    find "$SSH_DIR" -type f \( -name "id_*" ! -name "*.pub" \) -o -name "*_rsa" -o -name "*_ed25519" -o -name "*_ecdsa" 2>/dev/null | while read -r key; do
        if [ -f "$key" ] && [[ ! "$key" =~ \.pub$ ]]; then
            set_perms "$key" "600" "Private key: $(basename "$key")"
        fi
    done

    # Public keys
    find "$SSH_DIR" -type f -name "*.pub" 2>/dev/null | while read -r pubkey; do
        set_perms "$pubkey" "644" "Public key: $(basename "$pubkey")"
    done

    # authorized_keys
    set_perms "$SSH_DIR/authorized_keys" "600" "Authorized keys"

    # known_hosts
    set_perms "$SSH_DIR/known_hosts" "644" "Known hosts"
    set_perms "$SSH_DIR/known_hosts.old" "644" "Known hosts backup"

    # Git-crypt keys
    find "$SSH_DIR" -type f -name "*git-crypt*" 2>/dev/null | while read -r gckey; do
        set_perms "$gckey" "600" "Git-crypt key: $(basename "$gckey")"
    done
else
    echo -e "  ${YELLOW}⚠${NC}  SSH directory not found: $SSH_DIR"
fi

echo ""

# Fix .gnupg directory and files
echo -e "${GREEN}🔐 GPG Directory and Keys${NC}"
GPG_DIR="$HOME_DIR/.gnupg"

if [ -d "$GPG_DIR" ]; then
    # GPG directory itself
    set_perms "$GPG_DIR" "700" "GPG directory"

    # GPG configuration files
    set_perms "$GPG_DIR/gpg.conf" "600" "GPG config"
    set_perms "$GPG_DIR/gpg-agent.conf" "600" "GPG agent config"

    # GPG private key files
    set_perms "$GPG_DIR/private-keys-v1.d" "700" "Private keys directory"

    if [ -d "$GPG_DIR/private-keys-v1.d" ]; then
        find "$GPG_DIR/private-keys-v1.d" -type f 2>/dev/null | while read -r keyfile; do
            set_perms "$keyfile" "600" "Private key: $(basename "$keyfile")"
        done
    fi

    # GPG public keyring
    set_perms "$GPG_DIR/pubring.kbx" "600" "Public keyring"
    set_perms "$GPG_DIR/trustdb.gpg" "600" "Trust database"

    # GPG sockets
    set_perms "$GPG_DIR/S.gpg-agent" "600" "GPG agent socket"
    set_perms "$GPG_DIR/S.gpg-agent.ssh" "600" "GPG SSH agent socket"

    # All other files in .gnupg default to 600
    find "$GPG_DIR" -type f -not -path "*/private-keys-v1.d/*" 2>/dev/null | while read -r gpgfile; do
        sudo chmod 600 "$gpgfile" 2>/dev/null || true
        sudo chown "$USER_NAME:$USER_GROUP" "$gpgfile" 2>/dev/null || true
    done
else
    echo -e "  ${YELLOW}⚠${NC}  GPG directory not found: $GPG_DIR"
fi

echo ""
echo -e "${GREEN}✅ Permission reset complete!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} If you're still having SSH/GPG issues, you may need to:"
echo "  • Restart gpg-agent: gpgconf --kill gpg-agent"
echo "  • Restart ssh-agent or gcr-ssh-agent"
echo "  • Log out and log back in"
