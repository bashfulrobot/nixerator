#!/usr/bin/env bash
# lib_td.sh — shared `td` retry wrapper for the todoist-triage / todoist-task-update
# skills. Source it, then call `td_retry <subcommand> [args...]` exactly where you
# would have called `td <subcommand> ...`.
#
# WHY: every td-caller here funnels one or more Todoist REST calls per task. A
# batch sweep (triage / task-update over 100+ tasks) bursts past Todoist's ~15-min
# rate window; a single HTTP 429 then kills a `set -euo pipefail` script mid-fetch
# and the whole run cascades. td_retry absorbs that: it retries ONLY on
# rate-limit-shaped failures (429 / RATE_LIMITED / "too many requests") with
# escalating backoff, and passes every other error (bad ref, auth, network)
# straight through so a genuine failure never spins.
#
# Contract: on success, the td call's stdout is emitted verbatim (stderr is
# swallowed on the retried attempts, then surfaced once on final give-up). A
# caller under `set -e` still gets the original non-zero exit once retries are
# exhausted, exactly as a bare `td` would have, only later.
#
# Tunables (env): TD_RETRY_MAX (attempts, default 6), TD_RETRY_BASE_SECS (backoff
# unit, default 5 → sleeps 5,10,15,20,25s between the 6 attempts).
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib_td.sh"
#   task=$(td_retry task view "$ref" --json --full)

# Guard against double-sourcing (functions are idempotent, but keep it cheap).
[ -n "${LIB_TD_SOURCED:-}" ] && return 0 2>/dev/null || true
LIB_TD_SOURCED=1

td_retry() {
  local attempt=0 rc out errf
  local max="${TD_RETRY_MAX:-6}"
  local base="${TD_RETRY_BASE_SECS:-5}"
  errf="$(mktemp)"
  while :; do
    if out="$(td "$@" 2>"$errf")"; then
      rm -f "$errf"
      printf '%s' "$out"
      return 0
    else
      # Capture td's exit HERE: after `fi`, $? is the if-statement's status (0
      # when the condition fails with no else), not the failed command's.
      rc=$?
    fi
    # Retry ONLY rate-limit-shaped failures. td surfaces these on stderr (and
    # sometimes as an {"error":{"code":"RATE_LIMITED"...}} body on stdout), so
    # check both. Anything else is a real error: surface it and stop.
    if grep -qiE 'rate.?limit|429|too many request' "$errf" 2>/dev/null \
      || printf '%s' "$out" | grep -qiE 'rate.?limit|429|too many request'; then
      attempt=$((attempt + 1))
      if [ "$attempt" -ge "$max" ]; then
        cat "$errf" >&2
        rm -f "$errf"
        return "$rc"
      fi
      sleep $((attempt * base))
      continue
    fi
    cat "$errf" >&2
    rm -f "$errf"
    return "$rc"
  done
}
