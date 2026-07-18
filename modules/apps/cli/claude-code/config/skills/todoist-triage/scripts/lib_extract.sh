#!/usr/bin/env bash
# lib_extract.sh — pure text-extraction helpers shared by build_card.sh and
# dig_fetch.sh. No td calls, no side effects: read args/stdin, print to stdout,
# so they are unit-testable with fixtures.
#
# Source as a library (defines functions, runs nothing):
#   LIB_EXTRACT=1 source lib_extract.sh
set -uo pipefail

# extract_breadcrumbs: read a text blob on stdin (task title + comment bodies).
# Print one breadcrumb per line as "<kind>\t<value>", deduped, first-seen order.
#
# Every grep stage is guarded with `|| true`: a stage that matches nothing exits
# non-zero, and dig_fetch.sh runs this under `set -e`+pipefail with the function
# piped onward (`... | extract_breadcrumbs | jq`). Without the guards the first
# empty stage would abort the group and silently drop every later category.
extract_breadcrumbs() {
  local blob; blob="$(cat)"
  {
    # URLs, classified by host. Strip trailing sentence punctuation (a URL at the
    # end of a sentence otherwise swallows the '.'/','/';' etc.).
    grep -oE 'https?://[^ )<>"'"'"']+' <<<"$blob" | sed -E 's/[.,;:!?]+$//' \
      | while IFS= read -r u; do
      case "$u" in
        *slack.com*)            printf 'slack\t%s\n' "$u" ;;
        *teams.microsoft.com*)  printf 'teams\t%s\n' "$u" ;;
        *mail.google.com*)      printf 'gmail\t%s\n' "$u" ;;
        *docs.google.com*)      printf 'gdocs\t%s\n' "$u" ;;
        *.aha.io*)              printf 'aha\t%s\n' "$u" ;;
        *atlassian.net*)        printf 'jira\t%s\n' "$u" ;;
        *confluence*)           printf 'confluence\t%s\n' "$u" ;;
        *zoom.us*)              printf 'zoom\t%s\n' "$u" ;;
        *tactiq*)               printf 'transcript\t%s\n' "$u" ;;
        *app.todoist.com*)      printf 'todoist\t%s\n' "$u" ;;
        *)                      printf 'url\t%s\n' "$u" ;;
      esac
    done || true
    # Local file paths (Insync-synced notes/transcripts).
    grep -oE '/home/dustin/[A-Za-z0-9_./-]+' <<<"$blob" | sed 's/^/file\t/' || true
    # Aha idea refs (bare).
    grep -oE '\b[A-Z]{3,5}-I-[0-9]+\b' <<<"$blob" | sed 's/^/aha\t/' || true
    # Jira keys (bare), excluding Aha -I- refs.
    grep -oE '\b[A-Z]{2,6}-[0-9]+\b' <<<"$blob" | grep -vE '\-I-' | sed 's/^/jira\t/' || true
    # Konnect org UUIDs.
    grep -oiE '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b' <<<"$blob" | sed 's/^/org\t/' || true
    # Salesforce record IDs (15 or 18 char, 00-prefixed object ids).
    grep -oE '\b00[0-9A-Za-z]{13}([0-9A-Za-z]{3})?\b' <<<"$blob" | sed 's/^/sfid\t/' || true
    # Case numbers.
    grep -oE '\bCase [0-9]{5,}\b' <<<"$blob" | sed 's/^/case\t/' || true
  } | awk -F'\t' '!seen[$0]++'
}

# harvest_hedges: read text on stdin, print short hedge snippets (one per line)
# that signal unverified claims. Deduped. A no-match run exits 0 (the trailing
# `|| true` keeps it safe under a caller's `set -e`+pipefail, same as
# extract_breadcrumbs).
harvest_hedges() {
  grep -oiE "[^.]*(treat[^.]{0,20}rumou?r|did ?n[o']?t pass|not (yet )?confirmed|unverified|confirm via|need to (confirm|verify)|to be verified)[^.]*" \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | awk 'length>0 && !seen[$0]++' || true
}

# days_since <iso-date-or-datetime>: integer days from that date to today.
# Empty if no/invalid date. Negative if the date is in the future.
days_since() {
  local d="${1:-}"; [ -n "$d" ] || { echo ""; return 0; }
  local then now
  then=$(date -d "$d" +%s 2>/dev/null) || { echo ""; return 0; }
  now=$(date +%s)
  echo $(( (now - then) / 86400 ))
}
