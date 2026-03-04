#!/usr/bin/env bash
set -euo pipefail

# Check locally-built packages for new releases
# Compares current versions against GitHub/npm latest releases

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSIONS_FILE="$REPO_ROOT/settings/versions.nix"

# --- Helpers ---
info()  { echo -e "\033[1;34m[check]\033[0m $*"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
warn()  { echo -e "\033[1;33m  ↑\033[0m $*"; }
err()   { echo -e "\033[1;31m  ✗\033[0m $*"; }

updates_found=0

# --- Check a GitHub release ---
# Args: display_name, owner/repo, current_version, tag_prefix (optional)
check_github() {
    local name="$1" repo="$2" current="$3" prefix="${4:-}"

    local tag
    tag=$(curl -sf "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name // empty' 2>/dev/null) || true

    if [[ -z "$tag" ]]; then
        err "$name — failed to fetch latest release from $repo"
        return
    fi

    local latest="${tag#"$prefix"}"

    if [[ "$current" == "$latest" ]]; then
        ok "$name $current (up to date)"
    else
        warn "$name $current → $latest  ($repo)"
        updates_found=$((updates_found + 1))
    fi
}

# --- Check npm registry ---
# Args: display_name, npm_package, current_version
check_npm() {
    local name="$1" pkg="$2" current="$3"

    local latest
    latest=$(curl -sf "https://registry.npmjs.org/$pkg/latest" | jq -r '.version // empty' 2>/dev/null) || true

    if [[ -z "$latest" ]]; then
        err "$name — failed to fetch latest version from npm ($pkg)"
        return
    fi

    if [[ "$current" == "$latest" ]]; then
        ok "$name $current (up to date)"
    else
        warn "$name $current → $latest  (npm: $pkg)"
        updates_found=$((updates_found + 1))
    fi
}

# --- Extract version from versions.nix ---
get_nix_version() {
    local key="$1"
    grep -A4 "$key" "$VERSIONS_FILE" | grep 'version' | head -1 | sed 's/.*"\(.*\)".*/\1/'
}

# --- Extract version from a build file ---
get_build_version() {
    local file="$1"
    grep 'version = "' "$file" | head -1 | sed 's/.*"\(.*\)".*/\1/'
}

echo "Checking locally-built packages for updates..."
echo ""

# --- Packages in versions.nix ---
info "Packages from settings/versions.nix:"

check_github "meetsum" \
    "bashfulrobot/meetsum" \
    "$(get_nix_version 'meetsum')" \
    "v"

check_github "cpx" \
    "11happy/cpx" \
    "$(get_nix_version 'cpx')" \
    "v"

check_github "yepanywhere" \
    "kzahel/yepanywhere" \
    "$(get_nix_version 'yepanywhere')" \
    "v"

check_npm "get-shit-done" \
    "get-shit-done-cc" \
    "$(get_nix_version 'get-shit-done')"

echo ""

# --- Packages with inline versions ---
info "Packages with inline versions:"

check_github "helium" \
    "imputnet/helium-linux" \
    "$(get_build_version "$REPO_ROOT/modules/apps/gui/helium/build/default.nix")"

check_github "insomnia" \
    "Kong/insomnia" \
    "$(get_build_version "$REPO_ROOT/modules/apps/gui/insomnia/build/default.nix")" \
    "core@"

echo ""

# --- Summary ---
if [[ "$updates_found" -gt 0 ]]; then
    echo -e "\033[1;33m$updates_found update(s) available.\033[0m"
    echo ""
    echo "To update:"
    echo "  GSD:    just setup::update-gsd"
    echo "  Others: manually bump version + hash in the build file"
else
    echo -e "\033[1;32mAll packages up to date.\033[0m"
fi
