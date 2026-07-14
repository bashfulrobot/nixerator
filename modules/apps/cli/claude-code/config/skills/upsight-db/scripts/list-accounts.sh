#!/usr/bin/env bash
# list-accounts.sh — list all accounts in the upsight database.
#
# Usage:
#   list-accounts.sh [--like FRAGMENT] [--db PATH]
#   --like  case-insensitive substring filter on account_name
#   --db    database path (default: ~/.local/share/upsight/upsight.db — the CLI
#           and app always use this file regardless of config.toml)
set -euo pipefail

DB="${HOME}/.local/share/upsight/upsight.db"
LIKE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --like) LIKE="$2"; shift 2 ;;
    --db)   DB="$2";   shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -f "$DB" ] || { echo "db not found: $DB" >&2; exit 1; }

if [ -n "$LIKE" ]; then
  esc="${LIKE//\'/\'\'}"
  sqlite3 -header -column "$DB" \
    "SELECT id, account_name FROM accounts WHERE account_name LIKE '%${esc}%' ORDER BY account_name;"
else
  sqlite3 -header -column "$DB" \
    "SELECT id, account_name FROM accounts ORDER BY account_name;"
fi
