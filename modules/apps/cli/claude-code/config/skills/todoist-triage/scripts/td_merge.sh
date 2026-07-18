#!/usr/bin/env bash
# td_merge.sh — fold one or more duplicate tasks into a survivor: cross-reference
# on the survivor, pointer-comment each loser, then close the losers. The
# "is this a duplicate" call is the caller's; this performs the mechanics. One
# confirm (the caller's) authorises the closes.
# Usage:
#   td_merge.sh --survivor <ref> --loser <ref> [--loser <ref>...] [--survivor-url <url>] --reason "<why>" [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v td >/dev/null || { echo "td not found (todoist-cli skill)" >&2; exit 127; }
survivor=""; survivor_url=""; reason=""; dry_run=0; losers=()
while [ $# -gt 0 ]; do
  case "$1" in
    --survivor) survivor="${2:-}"; shift 2 ;;
    --survivor-url) survivor_url="${2:-}"; shift 2 ;;
    --loser) losers+=("${2:-}"); shift 2 ;;
    --reason) reason="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
{ [ -n "$survivor" ] && [ "${#losers[@]}" -gt 0 ]; } || { echo "need --survivor and at least one --loser" >&2; exit 2; }
dflag=(); [ "$dry_run" -eq 1 ] && dflag=(--dry-run)

# 1. Cross-reference the merged-in tasks on the survivor.
sw=("$survivor" --verb merge --entry "Absorbed ${#losers[@]} duplicate task(s). ${reason}")
[ "$dry_run" -eq 1 ] && sw+=(--dry-run)
bash "$SCRIPT_DIR/td_worklog.sh" "${sw[@]}"

# 2. Pointer-comment + close each loser.
for l in "${losers[@]}"; do
  lw=("$l" --verb merge --entry "Merged into survivor task. ${reason}")
  [ -n "$survivor_url" ] && lw+=(--link "survivor=$survivor_url")
  [ "$dry_run" -eq 1 ] && lw+=(--dry-run)
  bash "$SCRIPT_DIR/td_worklog.sh" "${lw[@]}"
  td task complete "$l" ${dflag[@]+"${dflag[@]}"} >/dev/null
done
[ "$dry_run" -eq 1 ] || printf 'merged %s loser(s) into %s\n' "${#losers[@]}" "$survivor"
