#!/usr/bin/env bash
# list-db-meetings.sh — list meetings already in the upsight database in a window.
#
# Usage:
#   list-db-meetings.sh [--since YYYY-MM-DD] [--db PATH]
#   --since  earliest meeting_date to include (default: 14 days ago)
#   --db     database path (default: ~/.local/share/upsight/upsight.db — the CLI
#            and app always use this file regardless of config.toml)
set -euo pipefail

DB="${HOME}/.local/share/upsight/upsight.db"
SINCE="$(date -d '14 days ago' +%Y-%m-%d 2>/dev/null || date -v-14d +%Y-%m-%d)"

while [ $# -gt 0 ]; do
  case "$1" in
    --since)
      SINCE="$2"
      shift 2
      ;;
    --db)
      DB="$2"
      shift 2
      ;;
    -h | --help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[ -f "$DB" ] || {
  echo "db not found: $DB" >&2
  exit 1
}

sqlite3 -header -column "$DB" "
  SELECT m.id,
         a.account_name AS account,
         m.meeting_date AS date,
         m.meeting_name AS meeting,
         m.status
  FROM meeting_summaries m
  JOIN accounts a ON a.id = m.account_id
  WHERE m.meeting_date >= '${SINCE}'
  ORDER BY m.meeting_date, account;"
