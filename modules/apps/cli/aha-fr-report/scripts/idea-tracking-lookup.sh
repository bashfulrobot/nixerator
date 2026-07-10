#!/usr/bin/env bash
# Look up CSM-curated per-idea tracking data from the upsight-go CRM's local
# SQLite database, keyed by Aha idea reference number, for one or more Aha
# idea-organization ids (a customer may have more than one pinned org -- see
# customers.txt).
#
# Usage:
#   idea-tracking-lookup.sh ORG_ID [ORG_ID...]
#
# Prints a JSON object keyed by reference number, e.g.:
#   {"REF-123": {"rank": 1, "production_blocker": 1, "target_release": "3.16",
#                "use_case": "Shared Gateway Migration",
#                "source_url": "https://...", "notes": "...",
#                "internal_discussion_url": "https://kong.slack.com/...",
#                "requester_name": "Chris Fulara",
#                "requester_email": "chris.fulara@example.com",
#                "team_name": "Platform Engineering"}, ...}
# Every field is independently nullable -- an idea with only a rank set (or
# nothing at all) is just missing the other keys' values, not an error.
# requester_name/requester_email/team_name are resolved from upsight-go's
# contacts (and, for team_name, teams) tables via
# idea_ranks.requester_contact_id, not stored as free text.
#
# Schema dependency: this reads seven columns added to idea_ranks by
# bashfulrobot/upsight-go#60 (requester_contact_id, production_blocker,
# target_release, use_case, source_url, notes) and #61
# (internal_discussion_url, the Kong-internal Slack thread, kept distinct
# from source_url's customer-facing link). Until those migrations have run
# on a given upsight.db, those columns don't exist yet -- this script
# degrades to "{}" on any SQLite error (including "no such column"), same
# as every other graceful-miss path here, so running against an
# un-migrated database just means blank cells, not a broken report.
# team_name has no idea_ranks column of its own -- it's derived the same way
# upsight-go#65 derives it in the app UI: requester_contact_id ->
# contacts.team_id -> teams.id -> teams.team_name.
#
# Degrades to "{}" (non-fatal) when sqlite3 isn't on PATH, the upsight
# database doesn't exist, the schema predates upsight-go#60/#61, or none of
# the given orgs have any tracked ideas.
#
# Config via environment:
#   UPSIGHT_DB   Path to upsight.db (default: ~/.local/share/upsight/upsight.db,
#                upsight-go's own XDG default).

# Deliberately no -e: a query failure (e.g. a not-yet-migrated schema) must
# degrade to "{}", not abort the caller.
set -uo pipefail

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
  SELECT
    aic.reference_num                   AS ref,
    ir.rank                             AS rank,
    ir.production_blocker               AS production_blocker,
    ir.target_release                   AS target_release,
    ir.use_case                         AS use_case,
    ir.source_url                       AS source_url,
    ir.notes                            AS notes,
    ir.internal_discussion_url          AS internal_discussion_url,
    c.first_name || ' ' || c.last_name  AS requester_name,
    c.email                             AS requester_email,
    t.team_name                         AS team_name
  FROM idea_ranks ir
  JOIN aha_idea_cache aic ON aic.id = ir.aha_idea_id
  JOIN accounts acc ON acc.id = ir.account_id
  LEFT JOIN contacts c ON c.id = ir.requester_contact_id
  LEFT JOIN teams t ON t.id = c.team_id
  WHERE acc.aha_organization_id IN (${placeholders})
    AND (ir.rank IS NOT NULL
         OR ir.production_blocker IS NOT NULL
         OR ir.target_release IS NOT NULL
         OR ir.use_case IS NOT NULL
         OR ir.source_url IS NOT NULL
         OR ir.notes IS NOT NULL
         OR ir.internal_discussion_url IS NOT NULL)
  ORDER BY (ir.rank IS NULL), ir.rank ASC;
" 2>/dev/null | jq -s '(add // []) | map({(.ref): del(.ref)}) | add // {}' 2>/dev/null || true
# The || true above matters: with pipefail, a sqlite3 query failure (e.g.
# "no such column" on a pre-upsight-go#60 schema) makes the pipeline report
# a non-zero exit even though jq still printed a correct "{}" -- and the
# caller (fetch-ideas.sh) runs this under `set -e` in a plain assignment,
# so a non-zero exit here would abort it despite valid output already
# having been produced.
