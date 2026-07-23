#!/usr/bin/env bash
# Tests for ttu_gmail_ref.sh. Run: bash ttu_gmail_ref.test.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0
fail=0
eq() { if [ "$3" = "$2" ]; then
  echo "PASS: $1"
  pass=$((pass + 1))
else
  echo "FAIL: $1 (want=[$2] got=[$3])"
  fail=$((fail + 1))
fi; }

# Classic ?th=<hex> permalink → resolvable thread id.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/?ui=2&view=cv&th=18f2a9c4b7d0e1a2')
eq "th shape" "thread" "$(jq -r .shape <<<"$out")"
eq "th id" "18f2a9c4b7d0e1a2" "$(jq -r .id <<<"$out")"

# Modern web-UI message permalink → best-effort message id.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#inbox/FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12')
eq "message shape" "message" "$(jq -r .shape <<<"$out")"
eq "message id" "FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12" "$(jq -r .id <<<"$out")"

# A different view name still yields a message id.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/1/#sent/QgrcJHrntZQlXjZBRlPgKfMcHxBLbvpZBBg')
eq "sent-view message shape" "message" "$(jq -r .shape <<<"$out")"
eq "sent-view message id" "QgrcJHrntZQlXjZBRlPgKfMcHxBLbvpZBBg" "$(jq -r .id <<<"$out")"

# Label view, no message open → no id, fallback path. The label name itself
# looks id-shaped (matches [A-Za-z0-9_-]{10,}); it must NOT be read as an id.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#label/Kong-Health-Equity')
eq "label shape" "label" "$(jq -r .shape <<<"$out")"
eq "label id empty" "" "$(jq -r .id <<<"$out")"

# Message opened while inside a label view → id is the third segment.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#label/Kong-Health/FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12')
eq "label+msg shape" "message" "$(jq -r .shape <<<"$out")"
eq "label+msg id" "FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12" "$(jq -r .id <<<"$out")"

# Nested label (Gmail encodes the inner slash as %2F) with a message open.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#label/Parent%2FChild/QgrcJHrntZQlXjZBRlPgKfMcHxBLbvpZBBg')
eq "nested-label+msg shape" "message" "$(jq -r .shape <<<"$out")"
eq "nested-label+msg id" "QgrcJHrntZQlXjZBRlPgKfMcHxBLbvpZBBg" "$(jq -r .id <<<"$out")"

# Search view, no message open → no id, fallback path.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#search/from%3Aalice%40example.com')
eq "search shape" "search" "$(jq -r .shape <<<"$out")"
eq "search id empty" "" "$(jq -r .id <<<"$out")"

# Message opened while inside a search view → id is the third segment.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#search/from%3Aalice%40example.com/FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12')
eq "search+msg shape" "message" "$(jq -r .shape <<<"$out")"
eq "search+msg id" "FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12" "$(jq -r .id <<<"$out")"

# googlemail.com alias host is accepted.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.googlemail.com/mail/u/0/#inbox/FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12')
eq "googlemail host shape" "message" "$(jq -r .shape <<<"$out")"
eq "googlemail host id" "FMfcgzQbfWpZcXsLmNoPqRsTuVwXyZ12" "$(jq -r .id <<<"$out")"

# A leading-dash segment is NOT a valid id: it must fall to the fallback (none),
# never emit as an option-looking id argument.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#inbox/----------abc')
eq "leading-dash rejected shape" "none" "$(jq -r .shape <<<"$out")"
eq "leading-dash rejected id" "" "$(jq -r .id <<<"$out")"

# Bare view (#inbox) with no id segment → none, fallback path.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#inbox')
eq "bare inbox shape" "none" "$(jq -r .shape <<<"$out")"
eq "bare inbox id empty" "" "$(jq -r .id <<<"$out")"

# Another bare view (#starred).
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/#starred')
eq "bare starred shape" "none" "$(jq -r .shape <<<"$out")"

# Gmail root with no fragment at all → none.
out=$(bash "$here/ttu_gmail_ref.sh" 'https://mail.google.com/mail/u/0/')
eq "root no-fragment shape" "none" "$(jq -r .shape <<<"$out")"

# Non-gmail URL → non-zero exit, no JSON.
if bash "$here/ttu_gmail_ref.sh" 'https://example.com/nope' >/dev/null 2>&1; then
  echo "FAIL: non-gmail url should exit non-zero"
  fail=$((fail + 1))
else
  echo "PASS: non-gmail url exits non-zero"
  pass=$((pass + 1))
fi

# Empty arg → usage error, non-zero exit.
if bash "$here/ttu_gmail_ref.sh" >/dev/null 2>&1; then
  echo "FAIL: empty arg should exit non-zero"
  fail=$((fail + 1))
else
  echo "PASS: empty arg exits non-zero"
  pass=$((pass + 1))
fi

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
