#!/usr/bin/env bash
set -euo pipefail

# Data-driven package updater
# Updates pinned packages in settings/versions.nix by source type.
# Usage: update-pkg.bash <name> | --all [--include-commits]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIX_TO_JSON="$REPO_ROOT/extras/scripts/nix-to-json.nix"
VERSIONS_FILE="$REPO_ROOT/settings/versions.nix"

# GitHub API auth (optional, avoids 60 req/hr rate limit)
CURL_GITHUB=(-sf)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    CURL_GITHUB+=(-H "Authorization: token $GITHUB_TOKEN")
fi

# --- Color helpers ---
info()  { echo -e "\033[1;34m[update]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[update]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[update]\033[0m $*"; }
err()   { echo -e "\033[1;31m[update]\033[0m $*" >&2; }

# --- Usage ---
usage() {
    cat <<'USAGE'
Usage: update-pkg.bash <name> | --all [--include-commits]

  <name>              Update a single package by name
  --all               Update all packages (skips github-commit by default)
  --include-commits   Include github-commit packages when using --all

Examples:
  update-pkg.bash amber
  update-pkg.bash --all
  update-pkg.bash --all --include-commits
USAGE
    exit 1
}

# --- Argument parsing ---
TARGET=""
UPDATE_ALL=false
INCLUDE_COMMITS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            UPDATE_ALL=true
            shift
            ;;
        --include-commits)
            INCLUDE_COMMITS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            err "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -n "$TARGET" ]]; then
                err "Only one package name allowed (got '$TARGET' and '$1')"
                usage
            fi
            TARGET="$1"
            shift
            ;;
    esac
done

if [[ "$UPDATE_ALL" == false && -z "$TARGET" ]]; then
    err "Provide a package name or --all"
    usage
fi

# --- Prerequisite check ---
for cmd in jq curl nix; do
    if ! command -v "$cmd" &>/dev/null; then
        err "Required command not found: $cmd"
        exit 1
    fi
done

# --- Load versions.nix as JSON ---
info "Loading versions from settings/versions.nix..."
versions_json=$(nix eval --json -f "$NIX_TO_JSON" 2>/dev/null) || {
    err "Failed to evaluate versions.nix"
    exit 1
}

# --- Locate a package by name across all categories ---
# Returns: category name (sets pkg_json as side effect)
pkg_json=""

find_package() {
    local name="$1"
    local categories
    categories=$(echo "$versions_json" | jq -r 'keys[]')

    for cat in $categories; do
        if echo "$versions_json" | jq -e --arg c "$cat" --arg p "$name" '.[$c][$p]' &>/dev/null; then
            pkg_json=$(echo "$versions_json" | jq --arg c "$cat" --arg p "$name" '.[$c][$p]')
            echo "$cat"
            return 0
        fi
    done
    return 1
}

# --- sed helpers to update fields in versions.nix ---

update_version() {
    local pkg_name="$1" new_version="$2"
    sed -i "/[[:space:]]$pkg_name = {/,/^[[:space:]]*};/ s|version = \"[^\"]*\"|version = \"$new_version\"|" "$VERSIONS_FILE"
}

update_hash() {
    local pkg_name="$1" new_hash="$2"
    # Anchor to line start (with whitespace) to avoid matching vendorHash/npmDepsHash
    sed -i "/[[:space:]]$pkg_name = {/,/^[[:space:]]*};/ s|^\([[:space:]]*\)hash = \"[^\"]*\"|\1hash = \"$new_hash\"|" "$VERSIONS_FILE"
}

update_rev() {
    local pkg_name="$1" new_rev="$2"
    sed -i "/[[:space:]]$pkg_name = {/,/^[[:space:]]*};/ s|rev = \"[^\"]*\"|rev = \"$new_rev\"|" "$VERSIONS_FILE"
}

# --- Source-type update handlers ---

update_github_release() {
    local name="$1" repo="$2" version="$3" prefix="$4"

    local tag latest
    tag=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/releases/latest" \
        | jq -r '.tag_name // empty' 2>/dev/null) || true

    # Fallback to tags API if no formal releases exist
    if [[ -z "$tag" ]]; then
        tag=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/tags?per_page=1" \
            | jq -r '.[0].name // empty' 2>/dev/null) || true
    fi

    if [[ -z "$tag" ]]; then
        err "$name -- failed to fetch latest release or tag from $repo"
        return 1
    fi

    latest="${tag#"$prefix"}"

    if [[ "$version" == "$latest" ]]; then
        ok "$name $version is already up to date"
        return 0
    fi

    info "$name: $version -> $latest"

    update_version "$name" "$latest"

    # Check if package uses platformHashes (per-platform, e.g. insomnia)
    local has_platform_hashes
    has_platform_hashes=$(echo "$pkg_json" | jq 'has("platformHashes")' 2>/dev/null) || true
    if [[ "$has_platform_hashes" == "true" ]]; then
        # Clear all platform hashes -- Nix will report the correct ones on rebuild
        sed -i "/[[:space:]]$name = {/,/^[[:space:]]*};/ s|= \"sha256-[^\"]*\"|= \"\"|" "$VERSIONS_FILE"
        warn "$name: version updated to $latest, platform hashes cleared -- rebuild to get correct hashes per platform"
    else
        update_hash "$name" ""
        warn "$name: version updated to $latest, hash cleared -- rebuild to get correct hash"
    fi
}

update_npm() {
    local name="$1" npm_pkg="$2" version="$3"
    local has_npm_deps_hash="$4"

    local latest
    latest=$(curl -sf "https://registry.npmjs.org/$npm_pkg/latest" \
        | jq -r '.version // empty' 2>/dev/null) || true

    if [[ -z "$latest" ]]; then
        err "$name -- failed to fetch latest version from npm ($npm_pkg)"
        return 1
    fi

    if [[ "$version" == "$latest" ]]; then
        ok "$name $version is already up to date"
        return 0
    fi

    info "$name: $version -> $latest"

    # Prefetch the npm tarball
    local raw_hash="" sri_hash=""
    info "$name: prefetching npm tarball..."
    raw_hash=$(nix-prefetch-url "https://registry.npmjs.org/$npm_pkg/-/$npm_pkg-$latest.tgz" 2>/dev/null) || true

    if [[ -n "$raw_hash" ]]; then
        sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$raw_hash" 2>/dev/null) || true
    fi

    if [[ -n "$sri_hash" ]]; then
        update_version "$name" "$latest"
        update_hash "$name" "$sri_hash"
        ok "$name: updated to $latest with hash $sri_hash"
    else
        update_version "$name" "$latest"
        update_hash "$name" ""
        warn "$name: version updated to $latest, hash prefetch failed -- rebuild to get correct hash"
    fi

    if [[ "$has_npm_deps_hash" == "true" ]]; then
        warn "$name: has npmDepsHash which may need updating after rebuild"
    fi

    # Check for colocated package-lock.json files that reference this package
    local lock_files
    lock_files=$(find "$REPO_ROOT/modules" -name "package-lock.json" 2>/dev/null) || true
    if [[ -n "$lock_files" ]]; then
        while IFS= read -r lock_file; do
            if grep -q "\"$npm_pkg\"" "$lock_file" 2>/dev/null; then
                warn "$name: found package-lock.json at $lock_file -- may need version string update"
            fi
        done <<< "$lock_files"
    fi
}

update_github_commit() {
    local name="$1" repo="$2" current_rev="$3"

    local latest_rev
    latest_rev=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/commits?per_page=1" \
        | jq -r '.[0].sha // empty' 2>/dev/null) || true

    if [[ -z "$latest_rev" ]]; then
        err "$name -- failed to fetch latest commit from $repo"
        return 1
    fi

    if [[ "$current_rev" == "$latest_rev" ]]; then
        ok "$name ${current_rev:0:7} is already up to date"
        return 0
    fi

    info "$name: ${current_rev:0:7} -> ${latest_rev:0:7}"

    # Prefetch the source
    local prefetch_json="" new_hash=""
    if command -v nix-prefetch-git &>/dev/null; then
        info "$name: prefetching commit $latest_rev..."
        prefetch_json=$(nix-prefetch-git "https://github.com/$repo" --rev "$latest_rev" --quiet 2>/dev/null) || true
        if [[ -n "$prefetch_json" ]]; then
            new_hash=$(echo "$prefetch_json" | jq -r '.hash // .sha256 // empty' 2>/dev/null) || true
        fi
    fi

    # Build the new version string: unstable-YYYY-MM-DD
    local new_version
    new_version="unstable-$(date +%Y-%m-%d)"

    update_version "$name" "$new_version"
    update_rev "$name" "$latest_rev"

    if [[ -n "$new_hash" ]]; then
        update_hash "$name" "$new_hash"
        ok "$name: updated to $new_version ($latest_rev) with hash $new_hash"
    else
        update_hash "$name" ""
        warn "$name: updated to $new_version ($latest_rev), hash prefetch failed -- rebuild to get correct hash"
    fi

    # Check for vendorHash
    local vendor_hash
    vendor_hash=$(echo "$pkg_json" | jq -r '.vendorHash // empty' 2>/dev/null) || true
    if [[ -n "$vendor_hash" ]]; then
        warn "$name: has vendorHash which may need updating after rebuild"
    fi
}

# --- Single package update ---

update_single() {
    local name="$1"

    local category
    category=$(find_package "$name") || {
        err "Package '$name' not found in versions.nix"
        exit 1
    }

    pkg_json=$(echo "$versions_json" | jq --arg c "$category" --arg p "$name" '.[$c][$p]')

    local source
    source=$(echo "$pkg_json" | jq -r '.source')

    info "Found $name in category '$category' (source: $source)"

    case "$source" in
        github-release)
            local version repo prefix
            version=$(echo "$pkg_json" | jq -r '.version')
            repo=$(echo "$pkg_json" | jq -r '.repo')
            prefix=$(echo "$pkg_json" | jq -r '.tagPrefix // ""')
            update_github_release "$name" "$repo" "$version" "$prefix"
            ;;
        npm)
            local version npm_pkg has_npm_deps
            version=$(echo "$pkg_json" | jq -r '.version')
            npm_pkg=$(echo "$pkg_json" | jq -r '.npmPkg // empty')
            [[ -z "$npm_pkg" ]] && npm_pkg="$name"
            has_npm_deps=$(echo "$pkg_json" | jq 'has("npmDepsHash")')
            update_npm "$name" "$npm_pkg" "$version" "$has_npm_deps"
            ;;
        github-commit)
            local repo rev
            repo=$(echo "$pkg_json" | jq -r '.repo')
            rev=$(echo "$pkg_json" | jq -r '.rev')
            update_github_commit "$name" "$repo" "$rev"
            ;;
        sourcehut)
            warn "$name: sourcehut packages require manual update"
            ;;
        *)
            err "$name: unknown source type '$source'"
            return 1
            ;;
    esac
}

# --- Update all packages ---

update_all() {
    local categories
    categories=$(echo "$versions_json" | jq -r 'keys[]')
    local had_failure=false

    for category in $categories; do
        info "Category: $category"

        local packages
        packages=$(echo "$versions_json" | jq -r --arg c "$category" '.[$c] | keys[]')

        for pkg in $packages; do
            pkg_json=$(echo "$versions_json" | jq --arg c "$category" --arg p "$pkg" '.[$c][$p]')
            local source
            source=$(echo "$pkg_json" | jq -r '.source')

            case "$source" in
                github-release)
                    local version repo prefix
                    version=$(echo "$pkg_json" | jq -r '.version')
                    repo=$(echo "$pkg_json" | jq -r '.repo')
                    prefix=$(echo "$pkg_json" | jq -r '.tagPrefix // ""')
                    update_github_release "$pkg" "$repo" "$version" "$prefix" || had_failure=true
                    ;;
                npm)
                    local version npm_pkg has_npm_deps
                    version=$(echo "$pkg_json" | jq -r '.version')
                    npm_pkg=$(echo "$pkg_json" | jq -r '.npmPkg // empty')
                    [[ -z "$npm_pkg" ]] && npm_pkg="$pkg"
                    has_npm_deps=$(echo "$pkg_json" | jq 'has("npmDepsHash")')
                    update_npm "$pkg" "$npm_pkg" "$version" "$has_npm_deps" || had_failure=true
                    ;;
                github-commit)
                    if [[ "$INCLUDE_COMMITS" == true ]]; then
                        local repo rev
                        repo=$(echo "$pkg_json" | jq -r '.repo')
                        rev=$(echo "$pkg_json" | jq -r '.rev')
                        update_github_commit "$pkg" "$repo" "$rev" || had_failure=true
                    else
                        info "$pkg: skipping github-commit (use --include-commits)"
                    fi
                    ;;
                sourcehut)
                    info "$pkg: skipping sourcehut (manual update required)"
                    ;;
                *)
                    err "$pkg: unknown source type '$source'"
                    had_failure=true
                    ;;
            esac
        done

        echo ""
    done

    if [[ "$had_failure" == true ]]; then
        warn "Some packages failed to update -- see errors above"
    fi
}

# --- Main ---

echo ""

if [[ "$UPDATE_ALL" == true ]]; then
    update_all
else
    update_single "$TARGET"
fi

echo ""
info "Done. Run 'just qr' to rebuild and verify."
