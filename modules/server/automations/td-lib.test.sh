#!/usr/bin/env bash
# Tests for td-lib.sh with a stub `td`. Run: bash td-lib.test.sh (needs GNU date
# and sleep with fractional seconds, so run it through `just test-td-lib`).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# macOS date has no %N. `just test-td-lib` supplies GNU coreutils.
if [[ "$(date +%N)" == "N" ]]; then
  echo 'skipped: needs GNU date (run: just test-td-lib)'
  exit 0
fi
fails=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s (want %s, got %s)\n' "$1" "$3" "$2"
    fails=$((fails + 1))
  fi
}

stub_dir=$(mktemp -d)
trap 'rm -rf "$stub_dir"' EXIT
# The stub prints $STUB_OUT on stdout and $STUB_ERR on stderr, exits $STUB_RC.
cat > "$stub_dir/td" << 'EOF'
#!/usr/bin/env bash
# STUB_FAIL_FIRST=N makes the first N calls fail, then the stub succeeds.
n=$(cat "$STUB_DIR/n" 2> /dev/null || echo 0)
echo $((n + 1)) > "$STUB_DIR/n"
first=${STUB_FAIL_FIRST:-$([ -n "${STUB_RC:-}" ] && echo 99999 || echo 0)}
if [ "$n" -lt "$first" ]; then
  printf '%s\n' "${STUB_ERR:-}" >&2
  exit "${STUB_RC:-1}"
fi
printf '%s\n' "${STUB_OUT:-}"
exit 0
EOF
chmod +x "$stub_dir/td"
export PATH="$stub_dir:$PATH"
export STUB_DIR="$stub_dir"

# Each case runs in a fresh shell so the counters start at zero. Prints
# "<rc> <calls>"; stderr lines go to $stub_dir/err.
run_case() {
  rm -f "$stub_dir/n"
  bash -c '
    set -euo pipefail
    td_min_gap_ms=0 td_backoff_base=1
    source "$1"
    td_tag=test
    rc=0
    out=$(td_retry task list 2>> "$2") || rc=$?
    calls=$(wc -c < "$td_calls_file")
    rm -rf "$td_state"
    echo "$rc ${calls//[[:space:]]/} $out"
  ' _ "$here/td-lib.sh" "$stub_dir/err"
}

: > "$stub_dir/err"
check "success makes 1 call and returns the payload" "$(STUB_OUT='{"a":1}' STUB_FAIL_FIRST=0 run_case)" '0 1 {"a":1}'

: > "$stub_dir/err"
check "non-429 failure makes 1 call and fails" "$(STUB_ERR='API_ERROR: boom' STUB_RC=1 run_case)" "1 1 "

: > "$stub_dir/err"
check "429 without Retry-After stops after 3 calls" "$(STUB_ERR='RATE_LIMITED: slow down' STUB_RC=1 run_case)" "1 3 "
: > "$stub_dir/err"
check "429 then success returns the payload after 2 calls" "$(STUB_OUT='{"ok":true}' STUB_ERR='RATE_LIMITED: slow' STUB_FAIL_FIRST=1 run_case)" '0 2 {"ok":true}'
: > "$stub_dir/err"
check "2 x 429 then success returns the payload after 3 calls" "$(STUB_OUT='{"ok":true}' STUB_ERR='RATE_LIMITED: slow' STUB_FAIL_FIRST=2 run_case)" '0 3 {"ok":true}'

: > "$stub_dir/err"
check "429 with Retry-After over the cap stops after 1 call" "$(STUB_ERR='RATE_LIMITED: Retry-After: 900' STUB_RC=1 run_case)" "1 1 "
check "cap message names the wait" "$(grep -c 'Retry-After 900s is over' "$stub_dir/err")" "1"

: > "$stub_dir/err"
check "429 with a short Retry-After still stops after 3 calls" "$(STUB_ERR='RATE_LIMITED: retry_after=1' STUB_RC=1 run_case)" "1 3 "
check "Retry-After value is the wait" "$(grep -c 'waiting 1s' "$stub_dir/err")" "2"

: > "$stub_dir/err"
check "20 digit Retry-After stops after 1 call" "$(STUB_ERR='RATE_LIMITED: Retry-After: 99999999999999999999' STUB_RC=1 run_case)" "1 1 "

# A non-numeric setting never reaches arithmetic.
out=$(td_min_gap_ms='a[$(touch '"$stub_dir"'/pwned)]' bash -c 'source "$1"' _ "$here/td-lib.sh" 2>&1)
check "bad setting is refused" "$out" "automations-td: td_min_gap_ms must be a number, got a bad value"
check "bad setting runs nothing" "$([ -e "$stub_dir/pwned" ] && echo ran || echo none)" "none"

# Minimum gap: 3 calls with a 400 ms gap take at least 0.8 s.
start_ms=$(( $(date +%s%N) / 1000000 ))
rm -f "$stub_dir/n"
bash -c '
  set -euo pipefail
  td_min_gap_ms=400
  source "$1"
  td_tag=test
  td_retry task list > /dev/null
  td_retry task list > /dev/null
  td_retry task list > /dev/null
  rm -rf "$td_state"
' _ "$here/td-lib.sh"
end_ms=$(( $(date +%s%N) / 1000000 ))
elapsed=$(( end_ms - start_ms ))
if [ "$elapsed" -ge 800 ] && [ "$elapsed" -le 2500 ]; then check "gap spaces 3 calls over 800 to 2500 ms" ok ok; else check "gap spaces 3 calls over 800 to 2500 ms" "$elapsed ms" "800-2500 ms"; fi

# td_finish logs the call count.
rm -f "$stub_dir/n"
out=$(bash -c '
  set -euo pipefail
  td_min_gap_ms=0
  source "$1"
  td_tag=test
  td_retry task list > /dev/null
  td_retry task list > /dev/null
  td_finish
' _ "$here/td-lib.sh" 2>&1)
check "td_finish logs the count" "$out" "test: td calls: 2"

if [ "$fails" -gt 0 ]; then
  printf '%s failed\n' "$fails"
  exit 1
fi
printf 'all passed\n'
