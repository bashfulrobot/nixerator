#!/usr/bin/env bash
# account.sh — show the full record for one account, by id or name substring.
#
# Usage:
#   account.sh 7                 # by numeric id
#   account.sh "acme"            # by case-insensitive name substring (must be unique)
#   account.sh --db PATH <sel>
#
# Errors if a name substring matches zero or more than one account, so it never
# guesses. Read-only.
set -euo pipefail

DB="${HOME}/.local/share/upsight/upsight.db"
SEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --db) DB="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) SEL="$1"; shift ;;
  esac
done
[ -f "$DB" ] || { echo "db not found: $DB" >&2; exit 1; }
[ -n "$SEL" ] || { echo "give an account id or name substring" >&2; exit 2; }

if [[ "$SEL" =~ ^[0-9]+$ ]]; then
  where="id = ${SEL}"
else
  esc="${SEL//\'/\'\'}"
  where="account_name LIKE '%${esc}%'"
fi

n="$(sqlite3 -readonly "$DB" "SELECT count(*) FROM accounts WHERE ${where};")"
if [ "$n" -eq 0 ]; then
  echo "no account matches: $SEL" >&2; exit 3
elif [ "$n" -gt 1 ]; then
  echo "ambiguous ($n matches) — narrow it:" >&2
  sqlite3 -readonly -column "$DB" "SELECT id, account_name FROM accounts WHERE ${where} ORDER BY account_name;" >&2
  exit 4
fi

# transpose to key: value with -line for a readable single-record view
sqlite3 -readonly -line "$DB" "SELECT * FROM accounts WHERE ${where};"
