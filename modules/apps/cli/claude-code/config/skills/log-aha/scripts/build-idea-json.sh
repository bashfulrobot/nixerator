#!/usr/bin/env bash
# Turn a feature-request FR markdown file into the JSON body for creating an
# Aha idea. The FR's H1 becomes the idea name; everything after the H1 becomes
# the description, converted to HTML with pandoc so Aha renders the headings,
# lists, inline code, and block quotes properly.
#
# Usage:
#   build-idea-json.sh <fr.md> [--portal] > idea.json
#
# --portal  Submit through the customer portal (skip_portal=false). Default is
#           skip_portal=true: the idea is created internally, which is what you
#           want when Kong logs it on the customer's behalf and then attaches a
#           proxy vote. A portal submission would also surface customer-facing,
#           and the FR body is written to be customer-independent for triage,
#           not for the portal.
#
# Notes:
#   * The FR header block (Date captured, Product area, Category, Priority,
#     Proxy votes) sits just under the H1 and is deliberately kept: it renders
#     as a short lead paragraph that gives a PM the triage metadata at a glance.
#   * The "Feature Request:" label on the H1 is stripped so the idea name reads
#     as the capability, not as a document title.
set -euo pipefail
fr="${1:?usage: build-idea-json.sh <fr.md> [--portal]}"
[[ -f "$fr" ]] || { echo "ERROR: file not found: $fr" >&2; exit 2; }
skip_portal=true
[[ "${2:-}" == "--portal" ]] && skip_portal=false
command -v pandoc >/dev/null || { echo "ERROR: pandoc is required" >&2; exit 2; }

name="$(grep -m1 '^# ' "$fr" | sed -e 's/^# *//' -e 's/^Feature Request: *//')"
[[ -n "$name" ]] || { echo "ERROR: no H1 (# ...) title found in $fr" >&2; exit 2; }

# Drop everything up to and including the H1 line, convert the rest to HTML.
html="$(sed '0,/^# /d' "$fr" | pandoc -f gfm -t html --wrap=none)"
[[ -n "$html" ]] || { echo "ERROR: FR body is empty after the H1" >&2; exit 2; }

jq -n --arg name "$name" --arg desc "$html" --argjson sp "$skip_portal" \
  '{idea: {name: $name, description: $desc, skip_portal: $sp}}'
