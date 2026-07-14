#!/usr/bin/env bash
# scan-transcripts.sh — list meeting transcripts on disk in a date window.
#
# Emits one tab-separated line per *.txt transcript that sits inside a
# YYYY-MM-DD folder whose date is >= --since:
#     <date>\t<top-folder>\t<meeting-name>\t<path>
# where <meeting-name> is the parent folder of the date folder (matching how
# `upsight summarize` infers the meeting name).
#
# Usage:
#   scan-transcripts.sh [--since YYYY-MM-DD] [--root DIR]
#   --since   earliest meeting date to include (default: 14 days ago)
#   --root    customer notes root (default: ~/insync/kong/My-drive/Customer)
set -euo pipefail

ROOT="${HOME}/insync/kong/My-drive/Customer"
SINCE="$(date -d '14 days ago' +%Y-%m-%d 2>/dev/null || date -v-14d +%Y-%m-%d)"

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --root)  ROOT="$2";  shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -d "$ROOT" ] || { echo "root not found: $ROOT" >&2; exit 1; }

# Find every YYYY-MM-DD directory, keep those >= SINCE, then list the .txt in each.
find "$ROOT" -type d -regextype posix-extended -regex '.*/[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
  | sort \
  | while IFS= read -r datedir; do
      d="$(basename "$datedir")"
      [ "$d" \< "$SINCE" ] && continue           # string compare works for ISO dates
      # top-level customer folder = first path component under ROOT
      rel="${datedir#"$ROOT"/}"
      top="${rel%%/*}"
      meeting="$(basename "$(dirname "$datedir")")"
      find "$datedir" -maxdepth 1 -type f -name '*.txt' | sort | while IFS= read -r txt; do
        printf '%s\t%s\t%s\t%s\n' "$d" "$top" "$meeting" "$txt"
      done
    done
