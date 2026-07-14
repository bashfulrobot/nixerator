#!/usr/bin/env bash
# query.sh — run an arbitrary READ-ONLY SQL query against the upsight database.
#
# Opens the DB with `sqlite3 -readonly`, so writes fail by construction even if
# the SQL tries them. Use this for one-off / freeform reads; if a query becomes
# routine, promote it to its own named script in this dir (see SKILL.md,
# "Growing this skill").
#
# Usage:
#   query.sh "SELECT ..."            # SQL as an argument
#   echo "SELECT ..." | query.sh -   # SQL from stdin
#   query.sh --format json "SELECT ..."
#
#   --format  column (default) | json | csv | line | box
#   --db      database path (default: ~/.local/share/upsight/upsight.db — the CLI
#             and app always use this file regardless of config.toml)
set -euo pipefail

DB="${HOME}/.local/share/upsight/upsight.db"
FMT="column"
SQL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --format) FMT="$2"; shift 2 ;;
    --db)     DB="$2";  shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -)  SQL="$(cat)"; shift ;;
    *)  SQL="$1"; shift ;;
  esac
done

[ -f "$DB" ] || { echo "db not found: $DB" >&2; exit 1; }
[ -n "$SQL" ] || { echo "no SQL given (pass a string or '-' for stdin)" >&2; exit 2; }

case "$FMT" in
  column) FMT_ARGS=(-header -column) ;;
  json)   FMT_ARGS=(-json) ;;
  csv)    FMT_ARGS=(-header -csv) ;;
  line)   FMT_ARGS=(-line) ;;
  box)    FMT_ARGS=(-header -box) ;;
  *) echo "unknown --format: $FMT" >&2; exit 2 ;;
esac

sqlite3 -readonly "${FMT_ARGS[@]}" "$DB" "$SQL"
