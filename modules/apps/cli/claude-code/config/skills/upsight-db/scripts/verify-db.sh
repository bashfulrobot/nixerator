#!/usr/bin/env bash
# verify-db.sh — health check the upsight database after imports/edits.
# Reports: integrity, foreign-key violations, stuck (non-completed) rows, and
# logical duplicates (same account + date + normalized meeting name).
#
# Usage: verify-db.sh [--db PATH]
set -euo pipefail

DB="${HOME}/.local/share/upsight/upsight.db"
while [ $# -gt 0 ]; do
  case "$1" in
    --db) DB="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -f "$DB" ] || { echo "db not found: $DB" >&2; exit 1; }

echo "== integrity =="
sqlite3 "$DB" "PRAGMA integrity_check;"

echo "== foreign key violations (empty = ok) =="
sqlite3 "$DB" "PRAGMA foreign_key_check;"

echo "== rows not completed (empty = ok) =="
sqlite3 -column "$DB" "
  SELECT id, account_id, meeting_date, meeting_name, status
  FROM meeting_summaries WHERE status <> 'completed';"

echo "== logical duplicates (empty = ok) =="
sqlite3 -column "$DB" "
  SELECT account_id, meeting_date, meeting_name_norm, count(*) c
  FROM meeting_summaries GROUP BY 1,2,3 HAVING c > 1;"

echo "== totals =="
sqlite3 "$DB" "SELECT count(*) AS meetings, max(id) AS max_id FROM meeting_summaries;"
