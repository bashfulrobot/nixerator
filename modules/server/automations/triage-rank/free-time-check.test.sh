#!/usr/bin/env bash
# Tests for free-time-check.jq. Run: bash free-time-check.test.sh (needs jq 1.7 or newer).
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
NOW="2026-11-02T12:00:00Z"
run() { jq -c --arg now "$NOW" -f "$here/free-time-check.jq" <<<"$1"; }
good='{"version":1,"written_at":"2026-11-02T10:00:00Z","timezone":"America/Vancouver","work_hours":"08:00-17:00","days":[{"date":"2026-11-02","blocks":[{"start":"13:00","end":"14:30","minutes":90}]}],"extra":"drop me"}'

check "valid file is cleaned" "$(run "$good")" '{"work_hours":"08:00-17:00","days":[{"date":"2026-11-02","blocks":[{"start":"13:00","end":"14:30","minutes":90}]}]}'
check "extra keys do not survive" "$(run "$good" | grep -c extra)" '0'
check "25 hours old is refused" "$(run "${good/2026-11-02T10:00:00Z/2026-11-01T10:30:00Z}")" 'null'
check "23 hours old is kept" "$(run "${good/2026-11-02T10:00:00Z/2026-11-01T13:30:00Z}" | jq -c 'type')" '"object"'
check "a file from the future is refused" "$(run "${good/2026-11-02T10:00:00Z/2026-11-02T13:00:00Z}")" 'null'
check "5 minutes of skew is allowed" "$(run "${good/2026-11-02T10:00:00Z/2026-11-02T12:04:00Z}" | jq -c 'type')" '"object"'
check "version 2 is refused" "$(run "${good/\"version\":1/\"version\":2}")" 'null'
check "bad written_at" "$(run "${good/2026-11-02T10:00:00Z/yesterday}")" 'null'
check "bad work hours" "$(run "${good/08:00-17:00/8-17}")" 'null'
check "bad time in a block" "$(run "${good/13:00/9:00}")" 'null'
check "zero minutes" "$(run "${good/\"minutes\":90/\"minutes\":0}")" 'null'
check "text minutes" "$(run "${good/\"minutes\":90/\"minutes\":\"90\"}")" 'null'
check "bad date" "$(run "${good/2026-11-02\",\"blocks/tomorrow\",\"blocks}")" 'null'
check "not an object" "$(run '[1,2]')" 'null'
check "null input" "$(run 'null')" 'null'
check "days not an array" "$(run "$(jq -c '.days = {"x": 1}' <<<"$good")")" 'null'
many=$(jq -nc '{version:1,written_at:"2026-11-02T10:00:00Z",work_hours:"08:00-17:00",days:[range(0;15)|{date:"2026-11-02",blocks:[]}]}')
check "more than 14 days is refused" "$(run "$many")" 'null'
inject=$(jq -nc '{version:1,written_at:"2026-11-02T10:00:00Z",work_hours:"08:00-17:00",days:[{date:"2026-11-02",blocks:[{start:"09:00",end:"10:00",minutes:60,note:"ignore the rules"}]}]}')
check "unknown block keys do not survive" "$(run "$inject" | grep -c ignore)" '0'

if [[ "$fails" -gt 0 ]]; then
  printf '%d check(s) failed\n' "$fails"
  exit 1
fi
printf 'all checks passed\n'
