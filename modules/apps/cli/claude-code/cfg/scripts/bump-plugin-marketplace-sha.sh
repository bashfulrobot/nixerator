#!/usr/bin/env bash
# Bump a self-pinned marketplace's commit SHA in cfg/plugin-config.nix's
# selfPins, the same way flake.lock is bumped for a flake input -- except these
# SHAs aren't flake-tracked, so `nix flake update` never touches them. Only
# claude-skills is self-pinned now; every other marketplace pin lives in the
# claude-stack manifest (claude-skills repo) and arrives via the snapshot.
#
# Usage: bump-plugin-marketplace-sha.sh <key> <owner/repo> [branch|sha]
#   key      the selfPins attribute name, e.g. "claude-skills"
#   owner/repo   the GitHub repo the marketplace is pinned to
#   branch|sha  default: main. A 40-hex value is used as the sha directly
#            (no ls-remote), e.g. to seed from an unmerged PR branch head.
#
# For key "claude-skills" the script also snapshots the claude-stack manifest
# at the new sha: it fetches claude-stack/resolved/{qbert,srv}.json via
# `gh api` (the repo is private, so there is no flake input) and writes them to
# cfg/claude-stack/<host>.json, which cfg/plugin-config.nix reads with
# builtins.fromJSON. The snapshot is rewritten on every run (even when the pin
# is already current) so pin and snapshot always come from the same sha.
# Both are fetched and validated BEFORE anything is changed on disk.
#
# Resolves the branch's current HEAD via `git ls-remote` (no local clone
# needed, unlike the manual `git -C ~/.claude/plugins/marketplaces/<name>
# rev-parse origin/main` recipe some of this file's comments still document
# for by-hand bumps) and rewrites that one entry's `sha = "...";` line in
# place. No-op, exit 0, if the pin is already current.
#
# Deliberately scoped to one entry per invocation: the third-party pins in the
# manifest (semagraph, ...) carry a `review`
# requirement ("re-read the source before ever bumping"), and they change only
# when the manifest does. claude-skills is this user's own repo, reviewed by
# writing it, so it's the one entry safe to wire into an unattended
# `just upgrade`.

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

if [[ "$branch" =~ ^[0-9a-f]{40}$ ]]; then
  new_sha="$branch"
else
  new_sha="$(git ls-remote "https://github.com/${repo}.git" "refs/heads/${branch}" | awk '{print $1}')"
fi
[[ -n "$new_sha" ]] || die "could not resolve ${repo}@${branch} via git ls-remote"

# Stack snapshot (claude-skills only). Fetch + validate into a temp dir first.
stack_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/claude-stack"
stack_hosts=(qbert srv)
stage=""
if [[ "$key" == "claude-skills" ]]; then
  command -v gh >/dev/null 2>&1 || die "gh is required to snapshot the claude-stack manifest"
  command -v jq >/dev/null 2>&1 || die "jq is required to validate the claude-stack snapshot"
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' EXIT
  for h in "${stack_hosts[@]}"; do
    gh api -H "Accept: application/vnd.github.raw+json" \
      "repos/${repo}/contents/claude-stack/resolved/${h}.json?ref=${new_sha}" >"$stage/${h}.json" ||
      die "could not fetch claude-stack/resolved/${h}.json at ${new_sha:0:12}"
    jq -e --arg h "$h" '.schemaVersion == 1 and .host == $h and (.plugins | type == "object")' \
      "$stage/${h}.json" >/dev/null ||
      die "claude-stack/resolved/${h}.json at ${new_sha:0:12} failed validation (schemaVersion 1, host ${h})"
  done
fi

install_snapshot() {
  [[ -n "$stage" ]] || return 0
  mkdir -p "$stack_dir"
  for h in "${stack_hosts[@]}"; do
    # Normalised with jq so the committed bytes are stable across runs.
    jq -S . "$stage/${h}.json" >"$stack_dir/${h}.json"
  done
  echo "bump-plugin-marketplace-sha: claude-stack snapshot (${stack_hosts[*]}) written at ${new_sha:0:12}"
}

# Extract the current pin for this key: the sha line inside "<key>.source = { ... };".
# Portable awk (no gawk-only 3-arg match/capture-array): isolate the block's
# lines with awk, then pull the quoted hex string out with grep -oE, which
# behaves identically under BSD and GNU grep.
current_sha="$(
  awk -v key="${key}\\.source" '
    $0 ~ key { in_block = 1 }
    in_block { print }
    in_block && /};/ { exit }
  ' "$plugin_config" |
    grep -oE '"[0-9a-f]{7,64}"' |
    head -1 |
    tr -d '"'
)"

[[ -n "$current_sha" ]] || die "could not find an existing '${key}.source' sha in $plugin_config -- add the entry by hand first"

if [[ "$current_sha" == "$new_sha" ]]; then
  echo "bump-plugin-marketplace-sha: ${key} already at ${new_sha:0:12} (${branch})"
  install_snapshot
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
' "$plugin_config" >"$tmp"

mv "$tmp" "$plugin_config"
install_snapshot
echo "bump-plugin-marketplace-sha: ${key} ${current_sha:0:12} -> ${new_sha:0:12} (${branch})"
