#!/usr/bin/env bash
# Tests for dup-pairs.jq. Run: bash dup-pairs.test.sh (needs jq 1.7 or newer).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fails=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s (want %s, got %s)\n' "$1" "$3" "$2"
    fails=$((fails + 1))
  fi
}
run() { jq -c -f "$here/dup-pairs.jq" <<<"$1"; }
pairs() { run "$1" | jq -c '[.[] | [.a, .b, .score]]'; }

check "empty list" "$(run '[]')" '[]'
check "one task" "$(run '[{"id":"A","title":"Reply to Acme"}]')" '[]'
check "identical two-word titles score 1" "$(pairs '[{"id":"A","title":"Pay rent"},{"id":"B","title":"pay RENT!"}]')" '[["A","B",1]]'
check "4 of 5 words is 0.8 and pairs" "$(pairs '[{"id":"A","title":"alpha beta gamma delta epsilon"},{"id":"B","title":"alpha beta gamma delta"}]')" '[["A","B",0.8]]'
check "2 of 3 words does not pair" "$(run '[{"id":"A","title":"Reply Acme quote"},{"id":"B","title":"Reply Acme"}]')" '[]'
check "numbers keep tasks apart" "$(run '[{"id":"A","title":"Pay invoice 12"},{"id":"B","title":"Pay invoice 15"}]')" '[]'
check "a quarter tag counts" "$(run '[{"id":"A","title":"Review Q3 plan"},{"id":"B","title":"Review Q4 plan"}]')" '[]'
check "one word titles never pair" "$(run '[{"id":"A","title":"Rent"},{"id":"B","title":"Rent"}]')" '[]'
check "accented title matches itself" "$(pairs '[{"id":"A","title":"Réunion équipe"},{"id":"B","title":"réunion équipe"}]')" '[["A","B",1]]'
check "accented and plain do not match" "$(run '[{"id":"A","title":"Réunion équipe"},{"id":"B","title":"Reunion equipe"}]')" '[]'
nfd=$(printf 'Re\xcc\x81union e\xcc\x81quipe')
check "decomposed accents stay inside words" "$(pairs "$(jq -nc --arg t "$nfd" '[{id:"A",title:$t},{id:"B",title:$t}]')")" '[["A","B",1]]'
check "non-latin title pairs with itself" "$(pairs '[{"id":"A","title":"会议 记录 整理"},{"id":"B","title":"会议 记录 整理"}]')" '[["A","B",1]]'

# 12 identical titles make 66 pairs; the cap keeps 50.
many=$(jq -nc '[range(0;12) | {id: ("T" + tostring), title: "weekly status report"}]')
check "cap at 50 pairs" "$(run "$many" | jq 'length')" '50'
# Best score first, whatever the order of the input.
check "sorted by score" "$(pairs '[{"id":"A","title":"alpha beta gamma delta epsilon"},{"id":"B","title":"alpha beta gamma delta"},{"id":"C","title":"zeta eta"},{"id":"D","title":"zeta eta"}]')" '[["C","D",1],["A","B",0.8]]'
# Only the first 100 tasks are compared.
big=$(jq -nc '[range(0;150) | {id: ("T" + tostring), title: ("word" + tostring + " other" + tostring)}]')
check "150 tasks run and stay bounded" "$(run "$big" | jq 'length')" '0'

if [[ "$fails" -gt 0 ]]; then
  printf '%d check(s) failed\n' "$fails"
  exit 1
fi
printf 'all checks passed\n'
