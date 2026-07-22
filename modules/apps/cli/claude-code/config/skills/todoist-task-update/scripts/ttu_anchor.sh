#!/usr/bin/env bash
# ttu_anchor.sh — compute a task's delta anchor from td_fetch.sh JSON on stdin.
# anchor = newest comment posted_at; if no comments, task.added_at; else empty.
# ISO-8601 UTC strings sort lexicographically == chronologically. Pure transform.
#
# If the input is a td error payload ({"error":...}) or otherwise not a td_fetch
# object (no "task" key), exit 4 WITHOUT printing an anchor. This matters in the
# batch context: a transient td 502 must not silently become an empty anchor (which
# would make the worker over-scan and risk duplicate updates) — the orchestrator
# should retry or skip the task instead.
case $- in *x*)
  echo "refusing to run under set -x" >&2
  exit 2
  ;;
esac
set -uo pipefail
in="$(cat)"
if ! printf '%s' "$in" | jq -e 'type == "object" and has("task") and (has("error") | not)' >/dev/null 2>&1; then
  echo "ttu_anchor: input is not a valid td_fetch payload (fetch error?)" >&2
  exit 4
fi
printf '%s' "$in" | jq -r '
  (.comments // []) as $c
  | if ($c | length) > 0
    then ([$c[].posted_at] | map(select(. != null)) | sort | last) // (.task.added_at // "")
    else (.task.added_at // "")
    end
'
