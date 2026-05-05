#!/usr/bin/env bash
set -uo pipefail

# Dependabot alert tracker
# Queries GitHub for open Dependabot alerts on the origin repo, diffs against
# the prior snapshot, and surfaces what changed since last run.
#
# Workflow: run after `just up`/`just rebuild` to detect when upstream package
# bumps have resolved (or introduced) security alerts. No local overrides are
# applied — this is a reporting tool only.
#
# Output: /tmp/nixerator-security-status.json (current snapshot)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SNAPSHOT_FILE="/tmp/nixerator-security-status.json"

info()  { echo -e "\033[1;34m[security]\033[0m $*"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
warn()  { echo -e "\033[1;33m  ↑\033[0m $*"; }
err()   { echo -e "\033[1;31m  ✗\033[0m $*" >&2; }

# --- Preflight ---
if ! command -v gh &>/dev/null; then
    err "gh CLI not found -- skipping security check"
    exit 0
fi
if ! command -v jq &>/dev/null; then
    err "jq not found -- skipping security check"
    exit 0
fi
if ! gh auth status &>/dev/null; then
    err "gh not authenticated -- skipping security check"
    exit 0
fi

# Resolve owner/repo from the git remote so this works for any clone.
remote_url=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null) || {
    err "no git remote 'origin' -- skipping security check"
    exit 0
}
repo_slug=$(echo "$remote_url" \
    | sed -E 's|^git@github.com:|https://github.com/|; s|\.git$||' \
    | sed -E 's|^https?://github.com/||')
if [[ -z "$repo_slug" || "$repo_slug" == "$remote_url" ]]; then
    err "could not parse GitHub repo from remote: $remote_url"
    exit 0
fi

info "Checking Dependabot alerts on $repo_slug..."

# --- Fetch current open alerts ---
current=$(gh api "repos/$repo_slug/dependabot/alerts?state=open&per_page=100" --paginate 2>/dev/null) || {
    err "failed to query Dependabot API (is the repo private? does the token have security_events scope?)"
    exit 0
}

# Compact representation: {number, severity, package, manifest_path, created_at, ghsa}
current_compact=$(echo "$current" | jq '[.[] | {
    number: .number,
    severity: .security_advisory.severity,
    package: .dependency.package.name,
    manifest: .dependency.manifest_path,
    created: .created_at,
    ghsa: .security_advisory.ghsa_id,
    summary: .security_advisory.summary
}]')

# --- Diff against snapshot ---
prev_numbers="[]"
if [[ -f "$SNAPSHOT_FILE" ]]; then
    prev_numbers=$(jq '[.[].number]' "$SNAPSHOT_FILE" 2>/dev/null) || prev_numbers="[]"
fi
curr_numbers=$(echo "$current_compact" | jq '[.[].number]')

newly_fixed=$(jq -n --argjson p "$prev_numbers" --argjson c "$curr_numbers" '$p - $c')
newly_opened=$(jq -n --argjson p "$prev_numbers" --argjson c "$curr_numbers" '$c - $p')

# --- Report deltas ---
fixed_count=$(echo "$newly_fixed" | jq 'length')
opened_count=$(echo "$newly_opened" | jq 'length')

if [[ -f "$SNAPSHOT_FILE" ]]; then
    if [[ "$fixed_count" -gt 0 ]]; then
        ok "$fixed_count alert(s) resolved since last check (upstream caught up)"
        echo "$newly_fixed" | jq -r '.[]' | while read -r num; do
            ok "  resolved: #$num"
        done
    fi
    if [[ "$opened_count" -gt 0 ]]; then
        warn "$opened_count new alert(s) since last check"
        echo "$newly_opened" | jq -r '.[]' | while read -r num; do
            details=$(echo "$current_compact" | jq -r --argjson n "$num" '.[] | select(.number == $n) | "\(.severity)\t\(.package)\t\(.manifest)"')
            warn "  new: #$num $details"
        done
    fi
    if [[ "$fixed_count" -eq 0 && "$opened_count" -eq 0 ]]; then
        info "no change since last check"
    fi
fi

# --- Current state summary, grouped by manifest ---
total=$(echo "$current_compact" | jq 'length')
high=$(echo "$current_compact" | jq '[.[] | select(.severity == "high" or .severity == "critical")] | length')
medium=$(echo "$current_compact" | jq '[.[] | select(.severity == "medium")] | length')
low=$(echo "$current_compact" | jq '[.[] | select(.severity == "low")] | length')

echo ""
echo -e "\033[1mOpen alerts:\033[0m $total ($high high, $medium medium, $low low)"

if [[ "$total" -gt 0 ]]; then
    # Stale alerts (>90 days) are the ones worth considering for local override.
    cutoff=$(date -u -d '90 days ago' +%s 2>/dev/null || date -u -v-90d +%s)
    stale=$(echo "$current_compact" | jq --argjson cutoff "$cutoff" '[.[] | select((.created | fromdateiso8601) < $cutoff)] | length')
    if [[ "$stale" -gt 0 ]]; then
        warn "$stale alert(s) open >90 days -- consider local override or upstream issue"
    fi

    echo ""
    echo "By module:"
    echo "$current_compact" \
        | jq -r 'group_by(.manifest) | .[] | "  \(.[0].manifest | split("/")[3]): \(length) (\([.[] | select(.severity == "high" or .severity == "critical")] | length) high)"'
fi

# --- Persist snapshot ---
echo "$current_compact" > "$SNAPSHOT_FILE"
