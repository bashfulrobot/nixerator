#!/usr/bin/env bash
# Tests for ttu_anchor.sh. Run: bash ttu_anchor.test.sh
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

# Multiple comments → newest posted_at wins (order-independent).
j='{"task":{"added_at":"2026-01-01T00:00:00Z"},"comments":[
  {"posted_at":"2026-05-07T17:48:12.365Z"},
  {"posted_at":"2026-05-21T15:55:30.098Z"},
  {"posted_at":"2026-05-13T23:20:08.217Z"}]}'
eq "newest comment" "2026-05-21T15:55:30.098Z" "$(printf '%s' "$j" | bash "$here/ttu_anchor.sh")"

# Zero comments → fall back to added_at.
j='{"task":{"added_at":"2026-03-17T20:38:54.390Z"},"comments":[]}'
eq "added_at fallback" "2026-03-17T20:38:54.390Z" "$(printf '%s' "$j" | bash "$here/ttu_anchor.sh")"

# Zero comments and no added_at → empty (worker treats as "scan recent history").
j='{"task":{},"comments":[]}'
eq "empty when nothing" "" "$(printf '%s' "$j" | bash "$here/ttu_anchor.sh")"

# td error payload (transient 502) → exit 4, print no anchor (orchestrator retries).
out=$(printf '%s' '{"error":{"code":"INTERNAL_ERROR","message":"HTTP 502: Bad Gateway"}}' | bash "$here/ttu_anchor.sh" 2>/dev/null)
rc=$?
eq "error payload exit 4" "4" "$rc"
eq "error payload no anchor" "" "$out"

# Non-object / garbage input → exit 4, no anchor.
out=$(printf '%s' 'not json at all' | bash "$here/ttu_anchor.sh" 2>/dev/null)
rc=$?
eq "garbage exit 4" "4" "$rc"

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
