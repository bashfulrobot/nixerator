#!/usr/bin/env bash
# Bump a git-backed marketplace's pinned commit SHA in
# cfg/plugin-config.nix's marketplaceSources, the same way flake.lock is
# bumped for a flake input -- except these SHAs aren't flake-tracked, so
# `nix flake update` never touches them (see the doc comment atop
# marketplaceSources).
#
# Usage: bump-plugin-marketplace-sha.sh <key> <owner/repo> [branch]
#   key      the marketplaceSources attribute name, e.g. "claude-skills"
#   owner/repo   the GitHub repo the marketplace is pinned to
#   branch   default: main
#
# Resolves the branch's current HEAD via `git ls-remote` (no local clone
# needed, unlike the manual `git -C ~/.claude/plugins/marketplaces/<name>
# rev-parse origin/main` recipe some of this file's comments still document
# for by-hand bumps) and rewrites that one entry's `sha = "...";` line in
# place. No-op, exit 0, if the pin is already current.
#
# Deliberately scoped to one entry per invocation, not "bump every pinned
# marketplace" -- several entries in marketplaceSources (semagraph,
# alexgreensh-token-optimizer, impeccable, hyperframes) carry an explicit
# "re-read the source before ever bumping" requirement in their own comments.
# Auto-bumping those would defeat the point of pinning them. claude-skills is
# this user's own repo, reviewed by writing it, so it's the one entry safe to
# wire into an unattended `just upgrade`.

set -euo pipefail

die() {
  echo "bump-plugin-marketplace-sha: $*" >&2
  exit 1
}

[[ $# -ge 2 ]] || die "usage: $0 <marketplaceSources key> <owner/repo> [branch]"

key="$1"
repo="$2"
branch="${3:-main}"

plugin_config="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/plugin-config.nix"
[[ -f "$plugin_config" ]] || die "plugin-config.nix not found at $plugin_config"

command -v git >/dev/null 2>&1 || die "git is required but not on PATH"

new_sha="$(git ls-remote "https://github.com/${repo}.git" "refs/heads/${branch}" | awk '{print $1}')"
[[ -n "$new_sha" ]] || die "could not resolve ${repo}@${branch} via git ls-remote"

# Extract the current pin for this key: the sha line inside "<key>.source = { ... };".
# Portable awk (no gawk-only 3-arg match/capture-array): isolate the block's
# lines with awk, then pull the quoted hex string out with grep -oE, which
# behaves identically under BSD and GNU grep.
current_sha="$(
  awk -v key="${key}\\.source" '
    $0 ~ key { in_block = 1 }
    in_block { print }
    in_block && /};/ { exit }
  ' "$plugin_config" \
    | grep -oE '"[0-9a-f]{7,64}"' \
    | head -1 \
    | tr -d '"'
)"

[[ -n "$current_sha" ]] || die "could not find an existing '${key}.source' sha in $plugin_config -- add the entry by hand first"

if [[ "$current_sha" == "$new_sha" ]]; then
  echo "bump-plugin-marketplace-sha: ${key} already at ${new_sha:0:12} (${branch})"
  exit 0
fi

# Rewrite only the sha line inside this key's block, leaving every other
# entry's sha untouched -- same awk-located block, sed on that one line.
tmp="$(mktemp)"
awk -v key="${key}\\.source" -v old="$current_sha" -v new="$new_sha" '
  $0 ~ key { in_block = 1 }
  in_block && index($0, "sha = \"" old "\"") {
    sub(old, new)
    in_block = 0
  }
  { print }
' "$plugin_config" > "$tmp"

mv "$tmp" "$plugin_config"
echo "bump-plugin-marketplace-sha: ${key} ${current_sha:0:12} -> ${new_sha:0:12} (${branch})"
