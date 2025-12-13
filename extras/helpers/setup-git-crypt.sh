#!/usr/bin/env nix-shell
#! nix-shell -i bash -p git-crypt git coreutils file gnugrep
#
# Setup git-crypt for the nixerator repository on a new system
#
# This script uses nix-shell to ensure all required tools are available.
# It will automatically download and use the necessary packages.
#
# Prerequisites:
#   - Nix must be installed (with flakes enabled)
#   - The git-crypt key must be at ~/.ssh/nixerator-git-crypt
#
# Usage:
#   ./setup-git-crypt.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

KEY_PATH="$HOME/.ssh/nixerator-git-crypt"
ENCRYPTED_FILE="modules/system/ssh/hosts.nix"

echo -e "${YELLOW}Setting up git-crypt for nixerator repository...${NC}\n"
echo -e "${GREEN}✓${NC} Required tools loaded via nix-shell"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} In git repository"

# Check if the key exists
if [[ ! -f "$KEY_PATH" ]]; then
    echo -e "${RED}Error: git-crypt key not found at $KEY_PATH${NC}"
    echo ""
    echo "Please copy the key to this location first:"
    echo "  scp source-machine:~/.ssh/nixerator-git-crypt ~/.ssh/"
    echo "  chmod 600 ~/.ssh/nixerator-git-crypt"
    exit 1
fi
echo -e "${GREEN}✓${NC} git-crypt key found at $KEY_PATH"

# Check key permissions
KEY_PERMS=$(stat -c %a "$KEY_PATH" 2>/dev/null || stat -f %A "$KEY_PATH" 2>/dev/null)
if [[ "$KEY_PERMS" != "600" ]]; then
    echo -e "${YELLOW}Warning: Key permissions are $KEY_PERMS, should be 600${NC}"
    echo "Fixing permissions..."
    chmod 600 "$KEY_PATH"
    echo -e "${GREEN}✓${NC} Key permissions fixed"
fi

# Check if repository is already unlocked
if git-crypt status | grep -q "not encrypted" 2>/dev/null; then
    if [[ -f "$ENCRYPTED_FILE" ]] && file "$ENCRYPTED_FILE" | grep -q "ASCII text"; then
        echo -e "${GREEN}✓${NC} Repository is already unlocked"
        echo -e "\n${GREEN}Success!${NC} git-crypt is configured and working"
        exit 0
    fi
fi

# Unlock the repository
echo "Unlocking repository with git-crypt..."
if git-crypt unlock "$KEY_PATH"; then
    echo -e "${GREEN}✓${NC} Repository unlocked successfully"
else
    echo -e "${RED}Error: Failed to unlock repository${NC}"
    exit 1
fi

# Verify the encrypted file is now readable
if [[ -f "$ENCRYPTED_FILE" ]]; then
    if file "$ENCRYPTED_FILE" | grep -q "ASCII text"; then
        echo -e "${GREEN}✓${NC} Encrypted files are now readable"
    else
        echo -e "${YELLOW}Warning: $ENCRYPTED_FILE might not be properly decrypted${NC}"
    fi
fi

echo -e "\n${GREEN}Success!${NC} git-crypt is configured and working"
echo ""
echo "Encrypted files:"
git-crypt status | grep "encrypted:" || echo "  (none shown - all unlocked)"
