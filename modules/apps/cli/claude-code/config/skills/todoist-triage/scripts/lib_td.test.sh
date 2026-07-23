#!/usr/bin/env bash
# Tests for lib_td.sh (td_retry). Run: bash lib_td.test.sh
# `td` is mocked with a shell function; a temp counter file survives the command
# substitutions td_retry runs the call in, so we can assert attempt counts.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib_td.sh"

# Fast + deterministic: no real backoff sleeps, small attempt ceiling.
export TD_RETRY_BASE_SECS=0
export TD_RETRY_MAX=4

CNT="$(mktemp)"
reset() { echo 0 >"$CNT"; }
count() { cat "$CNT"; }

# Mock `td`: bumps the shared counter, then behaves per $MOCK_MODE.
td() {
  local n
  n=$(($(cat "$CNT") + 1))
  echo "$n" >"$CNT"
  case "${MOCK_MODE:-ok}" in
    ok) printf 'OK:%s' "$*"; return 0 ;;
    ratelimit_then_ok)
      if [ "$n" -lt 2 ]; then
        echo "HTTP 429: Too Many Requests" >&2
        return 1
      fi
      printf 'OK'
      return 0
      ;;
    always_ratelimit)
      echo '{"error":{"code":"RATE_LIMITED"}}' >&2
      return 7
      ;;
    hard_error)
      echo "task does not exist or no permission" >&2
      return 3
      ;;
  esac
}

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

# 1. success passes stdout through verbatim, exactly one call.
reset
MOCK_MODE=ok
out="$(td_retry task view abc --json)"
rc=$?
check "success rc" "0" "$rc"
check "success stdout passthrough" "OK:task view abc --json" "$out"
check "success single attempt" "1" "$(count)"

# 2. a transient rate-limit is retried, then succeeds.
reset
MOCK_MODE=ratelimit_then_ok
out="$(td_retry comment list x)"
rc=$?
check "retry-then-ok rc" "0" "$rc"
check "retry-then-ok stdout" "OK" "$out"
check "retry-then-ok attempts" "2" "$(count)"

# 3. a non-rate-limit error returns immediately, NO retry spin.
reset
MOCK_MODE=hard_error
out="$(td_retry task view missing 2>/dev/null)"
rc=$?
check "hard-error propagates rc" "3" "$rc"
check "hard-error single attempt (no spin)" "1" "$(count)"

# 4. sustained rate-limit exhausts TD_RETRY_MAX attempts, returns the td rc.
reset
MOCK_MODE=always_ratelimit
out="$(td_retry project list 2>/dev/null)"
rc=$?
check "exhausted rc is td's rc" "7" "$rc"
check "exhausted attempt count == TD_RETRY_MAX" "4" "$(count)"

rm -f "$CNT"
echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
