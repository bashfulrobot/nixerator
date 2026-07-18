#!/usr/bin/env bash
# Tests for build_card.sh render_card(). Run: bash build_card.test.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CARD_LIB=1 source "$here/build_card.sh"

pass=0
fail=0
has() { if printf '%s' "$3" | grep -qF "$2"; then
  echo "PASS: $1"
  pass=$((pass + 1))
else
  echo "FAIL: $1 (missing [$2])"
  fail=$((fail + 1))
fi; }

json='{"task":{"task_id":"x","title":"Follow up with Chris on SSO","project":"Kong-sony","section":"s1","due":"2020-01-01","recurring":false,"priority":"p1","labels":[],"description":"","url":"https://app.todoist.com/app/task/x"},
"comments":[
 {"content":"Ran RevOps rule vs Sony https://kongstrong.slack.com/archives/C1/p999","posted_at":"2020-01-03T10:00:00Z","attachment":null},
 {"content":"Root cause: trial orgs expired. Not yet confirmed on license.","posted_at":"2020-01-02T10:00:00Z","attachment":null}
]}'

out=$(printf '%s' "$json" | render_card "4/12" "Up Next" "Waiting Internal")
has "header project" "Kong-sony · task 4/12" "$out"
has "title + prio" "Follow up with Chris on SSO" "$out"
has "overdue delta" "overdue" "$out"
has "column arrow" "Up Next → Waiting Internal" "$out"
has "triad sentinel" "<!--TRIAD-->" "$out"
has "worklog header" "Work log (last 2)" "$out"
has "breadcrumb slack" "slack" "$out"
has "hedge unverified" "Unverified" "$out"
has "action line" "done · defer" "$out"

# Regression: malformed/empty stdin must fail loudly (non-zero), not render a
# blank "null"-filled card and exit 0.
bad_rc=0
bad_out=$(printf 'not json at all' | render_card "1/1" "Up Next" "") 2>/dev/null || bad_rc=$?
if [ "$bad_rc" -ne 0 ]; then
  echo "PASS: bad JSON exits non-zero"
  pass=$((pass + 1))
else
  echo "FAIL: bad JSON exits non-zero (got rc=$bad_rc)"
  fail=$((fail + 1))
fi
if printf '%s' "$bad_out" | grep -q .; then
  echo "FAIL: bad JSON printed a card"
  fail=$((fail + 1))
else
  echo "PASS: bad JSON prints no card"
  pass=$((pass + 1))
fi

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
