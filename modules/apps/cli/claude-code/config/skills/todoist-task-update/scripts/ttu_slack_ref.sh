#!/usr/bin/env bash
# ttu_slack_ref.sh — parse a Slack (kongstrong) permalink into {channel,ts,thread_ts}.
# Pure: arg in, JSON out, no network. ts = p<digits> with a '.' inserted 6 from the
# right; channel from cid= (else /archives/<CH>/); thread_ts from the query, else ts.
case $- in *x*) echo "refusing to run under set -x" >&2; exit 2;; esac
set -uo pipefail
url="${1:-}"
[ -n "$url" ] || { echo "usage: ttu_slack_ref.sh <slack-permalink>" >&2; exit 2; }

chan=$(printf '%s' "$url" | grep -oE '[?&]cid=[A-Z0-9]+' | head -1 | sed -E 's/.*cid=//')
[ -n "$chan" ] || chan=$(printf '%s' "$url" | grep -oE '/archives/[A-Z0-9]+' | head -1 | sed -E 's#/archives/##')

pdigits=$(printf '%s' "$url" | grep -oE '/p[0-9]+' | head -1 | sed -E 's#/p##')
ts=""
if [ -n "$pdigits" ] && [ "${#pdigits}" -gt 6 ]; then
  ts="${pdigits:0:${#pdigits}-6}.${pdigits:${#pdigits}-6}"
fi

thread=$(printf '%s' "$url" | grep -oE '[?&]thread_ts=[0-9.]+' | head -1 | sed -E 's/.*thread_ts=//')
[ -n "$thread" ] || thread="$ts"

[ -n "$chan" ] && [ -n "$ts" ] || { echo "not a parseable slack permalink: $url" >&2; exit 1; }
jq -n --arg c "$chan" --arg t "$ts" --arg th "$thread" '{channel:$c, ts:$t, thread_ts:$th}'
