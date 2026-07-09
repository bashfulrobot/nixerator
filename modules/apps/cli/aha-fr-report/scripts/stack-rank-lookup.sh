#!/usr/bin/env bash
# Look up Stack Rank values from the upsight-go CRM's local SQLite database,
# keyed by Aha idea reference number, for one or more Aha idea-organization
# ids (a customer may have more than one pinned org -- see customers.txt).
#
# Usage:
#   stack-rank-lookup.sh ORG_ID [ORG_ID...]
#
# Prints a JSON object {"REF-123": 1, "REF-456": 2, ...} on stdout. Rank is
# upsight-go's manually-curated CSM prioritization (the idea_ranks table),
# not an Aha field -- lower number means higher priority, matching
# upsight-go's own `ORDER BY rank ASC` convention.
#
# Degrades to "{}" (non-fatal) when sqlite3 isn't on PATH, the upsight
# database doesn't exist, or none of the given orgs have ranked ideas -- a
# customer with no upsight-go tracking yet should never break report
# generation.
#
# Config via environment:
#   UPSIGHT_DB   Path to upsight.db (default: ~/.local/share/upsight/upsight.db,
#                upsight-go's own XDG default).

set -euo pipefail

UPSIGHT_DB="${UPSIGHT_DB:-$HOME/.local/share/upsight/upsight.db}"

[[ $# -ge 1 ]] || {
  echo '{}'
  exit 0
}
command -v sqlite3 >/dev/null 2>&1 || {
  echo '{}'
  exit 0
}
[[ -r "$UPSIGHT_DB" ]] || {
  echo '{}'
  exit 0
}

declare -a quoted=()
for id in "$@"; do
  quoted+=("'${id//\'/\'\'}'")
done
IFS=,
placeholders="${quoted[*]}"
unset IFS

sqlite3 -readonly -json "$UPSIGHT_DB" "
  SELECT aic.reference_num AS ref, ir.rank AS rank
  FROM idea_ranks ir
  JOIN aha_idea_cache aic ON aic.id = ir.aha_idea_id
  JOIN accounts acc ON acc.id = ir.account_id
  WHERE acc.aha_organization_id IN (${placeholders})
    AND ir.rank IS NOT NULL
  ORDER BY ir.rank ASC;
" 2>/dev/null | jq -s '(add // []) | map({(.ref): .rank}) | add // {}'
