#!/usr/bin/env bash
# Tests for ttu_slack_ref.sh. Run: bash ttu_slack_ref.test.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0; fail=0
eq() { if [ "$3" = "$2" ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (want=[$2] got=[$3])"; fail=$((fail+1)); fi; }

# Threaded reply permalink.
out=$(bash "$here/ttu_slack_ref.sh" 'https://kongstrong.slack.com/archives/C06UKBU6LKU/p1778176238331839?thread_ts=1776802884.699019&cid=C06UKBU6LKU')
eq "threaded channel"   "C06UKBU6LKU"        "$(jq -r .channel   <<<"$out")"
eq "threaded ts"        "1778176238.331839"  "$(jq -r .ts        <<<"$out")"
eq "threaded thread_ts" "1776802884.699019"  "$(jq -r .thread_ts <<<"$out")"

# Root message (no thread_ts query) → thread_ts falls back to ts.
out=$(bash "$here/ttu_slack_ref.sh" 'https://kongstrong.slack.com/archives/CRMUEHMNU/p1772587702484529')
eq "root channel"    "CRMUEHMNU"          "$(jq -r .channel   <<<"$out")"
eq "root ts"         "1772587702.484529"  "$(jq -r .ts        <<<"$out")"
eq "root thread=ts"  "1772587702.484529"  "$(jq -r .thread_ts <<<"$out")"

# Non-slack / unparseable → non-zero exit, no JSON.
if bash "$here/ttu_slack_ref.sh" 'https://example.com/nope' >/dev/null 2>&1; then
  echo "FAIL: bad url should exit non-zero"; fail=$((fail+1))
else
  echo "PASS: bad url exits non-zero"; pass=$((pass+1))
fi

echo "----"; echo "pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
