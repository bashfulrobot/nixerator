#!/usr/bin/env bash
set -euo pipefail

# Data-driven package update checker
# Reads all packages from settings/versions.nix via nix eval,
# dispatches by source type, and writes structured results.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIX_TO_JSON="$REPO_ROOT/extras/scripts/nix-to-json.nix"
OUTPUT_FILE="/tmp/nixerator-pkg-status.json"

# GitHub API auth (optional, avoids 60 req/hr rate limit)
CURL_GITHUB=(-sf)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    CURL_GITHUB+=(-H "Authorization: token $GITHUB_TOKEN")
fi

# --- Color helpers ---
info()  { echo -e "\033[1;34m[check]\033[0m $*"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
warn()  { echo -e "\033[1;33m  ↑\033[0m $*"; }
err()   { echo -e "\033[1;31m  ✗\033[0m $*"; }
manual(){ echo -e "\033[1;35m  ?\033[0m $*"; }

# --- Load versions.nix as JSON ---
info "Loading versions from settings/versions.nix..."
versions_json=$(nix eval --json -f "$NIX_TO_JSON" 2>/dev/null) || {
    err "Failed to evaluate versions.nix -- is nix available?"
    exit 1
}

# --- Results accumulator (JSON array) ---
results="[]"

add_result() {
    local name="$1" category="$2" current="$3" latest="$4" status="$5" detail="$6"
    results=$(echo "$results" | jq --arg n "$name" --arg c "$category" \
        --arg cur "$current" --arg lat "$latest" --arg s "$status" --arg d "$detail" \
        '. + [{name: $n, category: $c, current: $cur, latest: $lat, status: $s, detail: $d}]') \
        || { err "jq failed while adding result for $name"; exit 1; }
}

# --- Source-type checkers ---

check_github_release() {
    local name="$1" category="$2" repo="$3" version="$4" prefix="$5"

    local tag latest
    tag=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/releases/latest" \
        | jq -r '.tag_name // empty' 2>/dev/null) || true

    # Fallback to tags API if no formal releases exist
    if [[ -z "$tag" ]]; then
        tag=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/tags?per_page=1" \
            | jq -r '.[0].name // empty' 2>/dev/null) || true
    fi

    if [[ -z "$tag" ]]; then
        add_result "$name" "$category" "$version" "" "error" "Failed to fetch latest release or tag from $repo"
        err "$name -- failed to fetch latest release or tag from $repo"
        return
    fi

    latest="${tag#"$prefix"}"

    if [[ "$version" == "$latest" ]]; then
        add_result "$name" "$category" "$version" "$latest" "up-to-date" ""
        ok "$name $version (up to date)"
    else
        add_result "$name" "$category" "$version" "$latest" "update-available" "$repo: $tag"
        warn "$name $version -> $latest  ($repo)"
    fi
}

check_npm() {
    local name="$1" category="$2" npm_pkg="$3" version="$4"

    local latest
    latest=$(curl -sf "https://registry.npmjs.org/$npm_pkg/latest" \
        | jq -r '.version // empty' 2>/dev/null) || true

    if [[ -z "$latest" ]]; then
        add_result "$name" "$category" "$version" "" "error" "Failed to fetch from npm registry ($npm_pkg)"
        err "$name -- failed to fetch latest version from npm ($npm_pkg)"
        return
    fi

    if [[ "$version" == "$latest" ]]; then
        add_result "$name" "$category" "$version" "$latest" "up-to-date" ""
        ok "$name $version (up to date)"
    else
        add_result "$name" "$category" "$version" "$latest" "update-available" "npm: $npm_pkg"
        warn "$name $version -> $latest  (npm: $npm_pkg)"
    fi
}

check_github_commit() {
    local name="$1" category="$2" repo="$3" pinned_rev="$4" version="$5"
    local short_pinned="${pinned_rev:0:7}"

    # Fetch latest commit on default branch
    local latest_rev
    latest_rev=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/commits?per_page=1" \
        | jq -r '.[0].sha // empty' 2>/dev/null) || true

    if [[ -z "$latest_rev" ]]; then
        add_result "$name" "$category" "$short_pinned" "" "error" "Failed to fetch latest commit from $repo"
        err "$name -- failed to fetch latest commit from $repo"
        return
    fi

    local short_latest="${latest_rev:0:7}"

    if [[ "$pinned_rev" == "$latest_rev" ]]; then
        add_result "$name" "$category" "$short_pinned" "$short_latest" "up-to-date" ""
        ok "$name $short_pinned (up to date)"
        return
    fi

    # Commits differ -- gather age and distance info
    local detail_parts=()
    local age_str="" behind_str=""

    # Get commit date for pinned rev
    local commit_date
    commit_date=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/commits/$pinned_rev" \
        | jq -r '.commit.committer.date // empty' 2>/dev/null) || true

    if [[ -n "$commit_date" ]]; then
        local commit_epoch now_epoch days_old
        commit_epoch=$(date -d "$commit_date" +%s 2>/dev/null) || true
        now_epoch=$(date +%s)
        if [[ -n "$commit_epoch" ]]; then
            days_old=$(( (now_epoch - commit_epoch) / 86400 ))
            age_str="${days_old} days old"
            detail_parts+=("$age_str")
        fi
    fi

    # Count commits behind via compare API
    local behind_count
    behind_count=$(curl "${CURL_GITHUB[@]}" "https://api.github.com/repos/$repo/compare/${pinned_rev}...HEAD" \
        | jq -r '.ahead_by // empty' 2>/dev/null) || true

    if [[ -n "$behind_count" && "$behind_count" != "null" ]]; then
        behind_str="${behind_count} commits behind"
        detail_parts+=("$behind_str")
    fi

    local detail=""
    if [[ ${#detail_parts[@]} -gt 0 ]]; then
        detail=$(IFS=", "; echo "${detail_parts[*]}")
    fi

    add_result "$name" "$category" "$short_pinned" "$short_latest" "update-available" "$detail"

    local suffix=""
    if [[ -n "$detail" ]]; then
        suffix=" ($detail)"
    fi
    warn "$name $short_pinned -> $short_latest${suffix}"
}

check_sourcehut() {
    local name="$1" category="$2" version="$3" repo="$4"

    add_result "$name" "$category" "$version" "" "manual" "SourceHut package -- check manually at https://git.sr.ht/$repo"
    manual "$name $version (sourcehut: manual check required)"
}

# --- Main loop: iterate categories and packages ---
echo ""
categories=$(echo "$versions_json" | jq -r 'keys[]')

for category in $categories; do
    info "Category: $category"

    packages=$(echo "$versions_json" | jq -r --arg c "$category" '.[$c] | keys[]')

    for pkg in $packages; do
        # Extract package metadata
        pkg_json=$(echo "$versions_json" | jq --arg c "$category" --arg p "$pkg" '.[$c][$p]')
        source=$(echo "$pkg_json" | jq -r '.source')

        case "$source" in
            github-release)
                version=$(echo "$pkg_json" | jq -r '.version')
                repo=$(echo "$pkg_json" | jq -r '.repo')
                prefix=$(echo "$pkg_json" | jq -r '.tagPrefix // ""')
                check_github_release "$pkg" "$category" "$repo" "$version" "$prefix"
                ;;
            npm)
                version=$(echo "$pkg_json" | jq -r '.version')
                npm_pkg=$(echo "$pkg_json" | jq -r '.npmPkg // empty')
                if [[ -z "$npm_pkg" ]]; then
                    npm_pkg="$pkg"
                fi
                check_npm "$pkg" "$category" "$npm_pkg" "$version"
                ;;
            github-commit)
                repo=$(echo "$pkg_json" | jq -r '.repo')
                rev=$(echo "$pkg_json" | jq -r '.rev')
                version=$(echo "$pkg_json" | jq -r '.version // ""')
                check_github_commit "$pkg" "$category" "$repo" "$rev" "$version"
                ;;
            sourcehut)
                version=$(echo "$pkg_json" | jq -r '.version')
                repo=$(echo "$pkg_json" | jq -r '.repo')
                check_sourcehut "$pkg" "$category" "$version" "$repo"
                ;;
            *)
                add_result "$pkg" "$category" "" "" "error" "Unknown source type: $source"
                err "$pkg -- unknown source type: $source"
                ;;
        esac
    done

    echo ""
done

# --- Write JSON results ---
echo "$results" | jq '.' > "$OUTPUT_FILE"
info "Results written to $OUTPUT_FILE"

# --- Summary ---
total=$(echo "$results" | jq 'length')
up_to_date=$(echo "$results" | jq '[.[] | select(.status == "up-to-date")] | length')
updates=$(echo "$results" | jq '[.[] | select(.status == "update-available")] | length')
errors=$(echo "$results" | jq '[.[] | select(.status == "error")] | length')
manuals=$(echo "$results" | jq '[.[] | select(.status == "manual")] | length')

echo "---"
echo -e "\033[1mSummary:\033[0m $total packages checked"
echo -e "  \033[1;32m$up_to_date up to date\033[0m"

if [[ "$updates" -gt 0 ]]; then
    echo -e "  \033[1;33m$updates update(s) available\033[0m"
fi
if [[ "$errors" -gt 0 ]]; then
    echo -e "  \033[1;31m$errors error(s)\033[0m"
fi
if [[ "$manuals" -gt 0 ]]; then
    echo -e "  \033[1;35m$manuals manual check(s)\033[0m"
fi

if [[ "$updates" -gt 0 ]]; then
    echo ""
    echo "To update a single package:"
    echo "  just setup::update-pkg <name>"
    echo ""
    echo "To update all packages with available updates:"
    echo "  just setup::update-pkg --all"
fi
