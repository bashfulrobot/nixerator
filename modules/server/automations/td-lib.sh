# Shared `td` caller for the automations jobs. Read into the job script by
# default.nix, so it carries no shebang and no `set` line (writeShellApplication
# adds both). The caller sets td_tag (the log prefix) before the first call and
# calls td_finish from its EXIT trap.
#
# Todoist allows 1000 partial and 100 full sync requests per user per 15
# minutes, and answers a burst with HTTP 429 (RATE_LIMITED). Three rules keep a
# job under that:
#   1. A gap of td_min_gap_ms between two td calls (default 1500 ms).
#   2. A 429 waits for the Retry-After seconds when td prints them, else
#      45 then 90 seconds. At most td_max_tries calls (3), then exit non-zero.
#   3. A Retry-After above td_max_wait seconds (180) gives up at once: the
#      window is too long to sit out and hammering only extends it.
# td_calls_file counts every td invocation, retries included, and td_finish logs
# the total as "td calls: N" so the next audit reads it from the journal.

td_tag=${td_tag:-automations-td}
td_min_gap_ms=${td_min_gap_ms:-1500}
td_max_tries=${td_max_tries:-3}
td_max_wait=${td_max_wait:-180}
td_backoff_base=${td_backoff_base:-45}

td_state=$(mktemp -d)
td_calls_file=$td_state/calls
td_stamp_file=$td_state/last-call-ms
: > "$td_calls_file"

# Logs the call count. Call it from the EXIT trap, then it removes its state.
td_finish() {
  local calls
  calls=$(wc -c < "$td_calls_file" 2> /dev/null || echo 0)
  echo "$td_tag: td calls: ${calls//[[:space:]]/}" >&2
  rm -rf "$td_state"
}

# Sleeps until td_min_gap_ms has passed since the last td call ended. The
# timestamp lives in a file because td_retry usually runs in a $(...) subshell.
td_throttle() {
  local now_ms last_ms wait_ms
  now_ms=$(( $(date +%s%N) / 1000000 ))
  last_ms=$(cat "$td_stamp_file" 2> /dev/null || echo 0)
  wait_ms=$(( last_ms + td_min_gap_ms - now_ms ))
  if [ "$wait_ms" -gt 0 ]; then
    sleep "$(( wait_ms / 1000 )).$(printf '%03d' $(( wait_ms % 1000 )))"
  fi
}

td_stamp() {
  echo $(( $(date +%s%N) / 1000000 )) > "$td_stamp_file"
}

# Seconds from a "Retry-After: 30", "retry_after=30" or "retry after 30" style
# message on stdin, empty when there is none. td 5.8.4 builds its 429 message
# from the SDK error, so whether it ever carries the header is UNVERIFIED and
# the fixed backoff below is the normal path.
td_retry_after() {
  grep -oiE 'retry[-_ ]?after"?[:= ]+[0-9]+' | head -n 1 | grep -oE '[0-9]+$' || true
}

# Runs `td "$@"`. Prints stdout on success. On failure prints nothing from td
# (td's output can echo request details), only a fixed line, and returns 1.
# A failed call that is not a 429 returns at once, with no retry.
td_retry() {
  local out errfile attempt=0 msg wait_s
  errfile=$(mktemp -p "$td_state")
  while :; do
    attempt=$(( attempt + 1 ))
    td_throttle
    printf 'x' >> "$td_calls_file"
    if out=$(td "$@" 2> "$errfile"); then
      td_stamp
      rm -f "$errfile"
      printf '%s\n' "$out"
      return 0
    fi
    td_stamp
    msg="$out$(< "$errfile")"
    if ! grep -q -e RATE_LIMITED -e 'HTTP 429' <<< "$msg"; then
      echo "$td_tag: td $1 $2 failed" >&2
      rm -f "$errfile"
      return 1
    fi
    wait_s=$(td_retry_after <<< "$msg")
    if [ -n "$wait_s" ] && [ "$wait_s" -gt "$td_max_wait" ]; then
      echo "$td_tag: Todoist rate limited, Retry-After ${wait_s}s is over ${td_max_wait}s, giving up" >&2
      rm -f "$errfile"
      return 1
    fi
    if [ "$attempt" -ge "$td_max_tries" ]; then
      echo "$td_tag: Todoist rate limited, gave up after $attempt tries" >&2
      rm -f "$errfile"
      return 1
    fi
    wait_s=${wait_s:-$(( attempt * td_backoff_base ))}
    echo "$td_tag: Todoist rate limited, try $attempt of $td_max_tries, waiting ${wait_s}s" >&2
    sleep "$wait_s"
  done
}
