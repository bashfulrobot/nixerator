#!/usr/bin/env bash
# Tests for lib_extract.sh pure helpers. Run: bash lib_extract.test.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_EXTRACT=1 source "$here/lib_extract.sh"

pass=0
fail=0
check() { # name expected actual
  if [ "$3" = "$2" ]; then
    echo "PASS: $1"
    pass=$((pass + 1))
  else
    echo "FAIL: $1 (want=[$2] got=[$3])"
    fail=$((fail + 1))
  fi
}
has() { # name needle haystack
  if printf '%s' "$3" | grep -qF "$2"; then
    echo "PASS: $1"
    pass=$((pass + 1))
  else
    echo "FAIL: $1 (missing [$2])"
    fail=$((fail + 1))
  fi
}

blob='Follow up with Chris https://kongstrong.slack.com/archives/C1/p123
Teams thread https://teams.microsoft.com/l/message/abc
Doc /home/dustin/insync/notes/sony.md and aha GTWY-I-1484
org f3170a13-482d-4cf6-8121-ae7a185cde8d SF opp 006PJ00000Oct2UYAR Case 00073440'
crumbs=$(printf '%s' "$blob" | extract_breadcrumbs)
has "slack url" "slack" "$crumbs"
has "teams url" "teams" "$crumbs"
has "file path" "file	/home/dustin/insync/notes/sony.md" "$crumbs"
has "aha ref" "aha	GTWY-I-1484" "$crumbs"
has "org uuid" "org	f3170a13-482d-4cf6-8121-ae7a185cde8d" "$crumbs"
has "sf id" "sfid	006PJ00000Oct2UYAR" "$crumbs"
has "case" "case	Case 00073440" "$crumbs"

hedgeblob='This did NOT pass verification, treat as rumor.
The orgs are active.'
hedges=$(printf '%s' "$hedgeblob" | harvest_hedges)
has "hedge harvested" "rumor" "$hedges"

check "days_since empty is empty" "" "$(days_since '')"
# A date 3 days before a fixed 'today' is impractical to assert absolutely; assert
# it returns an integer for a valid date.
d=$(days_since '2020-01-01')
case "$d" in '' | *[!0-9-]*) r=bad ;; *) r=int ;; esac
check "days_since returns int" "int" "$r"

# Regression: extract_breadcrumbs must survive `set -e`+pipefail (dig_fetch.sh sets
# it before sourcing). A blob whose FIRST grep stage (URLs) matches nothing but a
# LATER stage (case) does must still return the later match AND exit 0 — not abort
# on the first empty stage.
# Run in a fresh top-level `bash -c` under `set -euo pipefail`, with
# extract_breadcrumbs piped onward (`| cat`) — exactly dig_fetch.sh's context
# (`... | extract_breadcrumbs | jq`). That is the position where a failing early
# grep stage trips errexit and aborts the remaining stages. A `$( )` around the
# current shell does NOT reproduce it; a real top-level script context does.
e_rc=0
e_out=$(bash -c "set -euo pipefail; source '$here/lib_extract.sh'; \
  printf 'A stray Case 00073440 with no url.' | extract_breadcrumbs | cat") || e_rc=$?
check "extract survives set -e (exit 0)" "0" "$e_rc"
has "extract survives set -e (case kept)" "case	Case 00073440" "$e_out"

# URLs must not capture trailing sentence punctuation.
punct=$(printf 'See https://kongstrong.slack.com/archives/C1/p999.' | extract_breadcrumbs)
if printf '%s' "$punct" | grep -qF 'p999.'; then
  echo "FAIL: url trailing period not stripped"
  fail=$((fail + 1))
else
  echo "PASS: url trailing period stripped"
  pass=$((pass + 1))
fi

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
