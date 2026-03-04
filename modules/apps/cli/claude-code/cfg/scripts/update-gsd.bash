#!/usr/bin/env bash
set -euo pipefail

# Update GSD (get-shit-done-cc) to latest npm version
# Updates: versions.nix and package-lock.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSIONS_FILE="$MODULE_DIR/../../../../settings/versions.nix"
LOCKFILE="$MODULE_DIR/build/gsd/package-lock.json"
PKG_NAME="get-shit-done-cc"

# --- Helpers ---
info()  { echo -e "\033[1;34m[gsd-update]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[gsd-update]\033[0m $*"; }
err()   { echo -e "\033[1;31m[gsd-update]\033[0m $*" >&2; }

# --- Get current version from versions.nix ---
current_version=$(grep -A4 'get-shit-done' "$VERSIONS_FILE" | grep 'version' | head -1 | sed 's/.*"\(.*\)".*/\1/')
info "Current version: $current_version"

# --- Check latest version on npm ---
info "Checking npm for latest version..."
latest_version=$(curl -s "https://registry.npmjs.org/$PKG_NAME/latest" | jq -r '.version')

if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
    err "Failed to fetch latest version from npm"
    exit 1
fi

info "Latest version:  $latest_version"

if [[ "$current_version" == "$latest_version" ]]; then
    ok "Already up to date ($current_version)"
    exit 0
fi

info "Updating $current_version → $latest_version"

# --- Prefetch tarball ---
tarball_url="https://registry.npmjs.org/$PKG_NAME/-/$PKG_NAME-$latest_version.tgz"
info "Prefetching tarball..."
nix_hash=$(nix-prefetch-url "$tarball_url" 2>/dev/null)
sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$nix_hash")
info "SHA256: $sri_hash"

# --- Update versions.nix ---
info "Updating versions.nix..."
sed -i "s/version = \"$current_version\"/version = \"$latest_version\"/" "$VERSIONS_FILE"
sed -i "/get-shit-done/,/}/ s|sha256 = \"sha256-[^\"]*\"|sha256 = \"$sri_hash\"|" "$VERSIONS_FILE"
ok "Updated versions.nix"

# --- Update package-lock.json ---
info "Updating package-lock.json..."
sed -i "s/\"version\": \"$current_version\"/\"version\": \"$latest_version\"/g" "$LOCKFILE"
ok "Updated package-lock.json"

# --- Summary ---
echo ""
ok "GSD updated: $current_version → $latest_version"
echo ""
info "Next steps:"
info "  1. just rebuild"
info "  2. just setup::gsd"
