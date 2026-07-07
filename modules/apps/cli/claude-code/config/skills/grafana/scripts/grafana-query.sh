#!/usr/bin/env bash
# Deterministic PromQL/LogQL query wrapper against Grafana Cloud, via the
# datasource-proxy API. Exists so metrics/logs can be read directly -- by a
# human or an agent -- without hand-rolling the proxy path each time, because
# that path has two easy-to-get-wrong gotchas:
#   1. Prometheus wants unix *seconds* for start/end; Loki wants unix
#      *nanoseconds*. Mixing these up silently returns an empty result, not
#      an error.
#   2. The proxy path is keyed by datasource *uid*, not name, and this Grafana
#      Cloud org has near-duplicate datasources (e.g. a "-nonprovisioned"
#      Loki twin, and Loki instances for alert-history/usage-insights that
#      are NOT your cluster's logs). Picking the wrong one also fails silent
#      -- it just queries a different, empty-looking backend.
# This script resolves the uid by name (defaulting to the verified-correct
# datasources for this org) and gets the time-unit conversion right, so
# neither has to be re-derived per call.
#
# Usage:
#   grafana-query.sh prom '<promql>' [--instant | --since 1h --step 60s] [--datasource NAME]
#   grafana-query.sh loki '<logql>' [--since 1h] [--limit 100] [--datasource NAME]
#
# prom defaults to an instant query (evaluated at now). Pass --since to run
# a range query instead (e.g. to plot a trend rather than read the current
# value). loki always runs a range query over the --since window, newest
# first, because "logs" without a time window doesn't mean much.
#
# Options:
#   --since DURATION    Lookback window, e.g. 30s, 5m, 1h, 2d. Default: 1h.
#   --step DURATION     Prometheus range-query step. Default: 60s. Ignored
#                        for instant queries and for loki.
#   --limit N           Loki max lines to return. Default: 100. Ignored for prom.
#   --instant           Force prom to run as an instant query (default already).
#   --datasource NAME   Override the datasource name to resolve. Defaults:
#                        prom  -> $GRAFANA_PROM_DATASOURCE (default: grafanacloud-bashfulrobot-prom)
#                        loki  -> $GRAFANA_LOKI_DATASOURCE (default: grafanacloud-bashfulrobot-logs)
#   --raw               Print the response as-is (skip jq pretty-printing).
#   -h, --help          Show this help.
#
# Config via environment:
#   GRAFANA_TOKEN             Required. A Grafana Service Account token (Bearer).
#   GRAFANA_URL               Default: https://bashfulrobot.grafana.net
#   GRAFANA_PROM_DATASOURCE   Default: grafanacloud-bashfulrobot-prom
#   GRAFANA_LOKI_DATASOURCE   Default: grafanacloud-bashfulrobot-logs
#
# Requires: curl, jq, date (GNU or BSD).

set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-https://bashfulrobot.grafana.net}"
base_url="${GRAFANA_URL%/}/api"
prom_ds_default="${GRAFANA_PROM_DATASOURCE:-grafanacloud-bashfulrobot-prom}"
loki_ds_default="${GRAFANA_LOKI_DATASOURCE:-grafanacloud-bashfulrobot-logs}"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

[[ $# -ge 1 ]] || die "usage: grafana-query.sh <prom|loki> '<query>' [options] (see --help)"

backend="$1"
shift
case "$backend" in
  prom | loki) ;;
  -h | --help)
    sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *) die "first argument must be 'prom' or 'loki', got: $backend" ;;
esac

[[ $# -ge 1 ]] || die "missing query string"
query="$1"
shift

since="1h"
step="60s"
limit="100"
force_instant=""
since_given=""
raw=""
datasource=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      [[ $# -ge 2 ]] || die "--since needs a value"
      since="$2"
      since_given="1"
      shift 2
      ;;
    --step)
      [[ $# -ge 2 ]] || die "--step needs a value"
      step="$2"
      shift 2
      ;;
    --limit)
      [[ $# -ge 2 ]] || die "--limit needs a value"
      limit="$2"
      shift 2
      ;;
    --instant)
      force_instant="1"
      shift
      ;;
    --datasource)
      [[ $# -ge 2 ]] || die "--datasource needs a value"
      datasource="$2"
      shift 2
      ;;
    --raw)
      raw="1"
      shift
      ;;
    -h | --help)
      sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

for dep in curl jq date; do
  command -v "$dep" >/dev/null 2>&1 || die "'$dep' is required but not on PATH"
done

token="${GRAFANA_TOKEN:-}"
[[ -n "$token" ]] || die "GRAFANA_TOKEN is not set. Export a Grafana Service Account token."

# Convert a duration like "30s" / "5m" / "1h" / "2d" to whole seconds.
to_seconds() {
  local dur="$1"
  [[ "$dur" =~ ^([0-9]+)(s|m|h|d)$ ]] || die "invalid duration: $dur (expected e.g. 30s, 5m, 1h, 2d)"
  local num="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
  case "$unit" in
    s) echo "$num" ;;
    m) echo $((num * 60)) ;;
    h) echo $((num * 3600)) ;;
    d) echo $((num * 86400)) ;;
  esac
}

resolve_uid() {
  local name="$1"
  local resp uid
  resp="$(curl -sS -H "Authorization: Bearer $token" -H "Accept: application/json" \
    "$base_url/datasources/name/$(jq -rn --arg n "$name" '$n|@uri')")"
  uid="$(printf '%s' "$resp" | jq -r '.uid // empty')"
  [[ -n "$uid" ]] || die "could not resolve datasource '$name' to a uid. Response: $resp"
  printf '%s' "$uid"
}

now_epoch="$(date +%s)"
since_seconds="$(to_seconds "$since")"
start_epoch=$((now_epoch - since_seconds))

pretty() {
  if [[ -n "$raw" ]]; then
    cat
  else
    jq '.' 2>/dev/null || cat
  fi
}

if [[ "$backend" == "prom" ]]; then
  ds="${datasource:-$prom_ds_default}"
  uid="$(resolve_uid "$ds")"
  if [[ -n "$since_given" && -z "$force_instant" ]]; then
    curl -sS -G -H "Authorization: Bearer $token" \
      --data-urlencode "query=$query" \
      --data-urlencode "start=$start_epoch" \
      --data-urlencode "end=$now_epoch" \
      --data-urlencode "step=$step" \
      "$base_url/datasources/proxy/uid/$uid/api/v1/query_range" | pretty
  else
    curl -sS -G -H "Authorization: Bearer $token" \
      --data-urlencode "query=$query" \
      "$base_url/datasources/proxy/uid/$uid/api/v1/query" | pretty
  fi
else
  ds="${datasource:-$loki_ds_default}"
  uid="$(resolve_uid "$ds")"
  start_ns="$((start_epoch * 1000000000))"
  end_ns="$((now_epoch * 1000000000))"
  curl -sS -G -H "Authorization: Bearer $token" \
    --data-urlencode "query=$query" \
    --data-urlencode "start=$start_ns" \
    --data-urlencode "end=$end_ns" \
    --data-urlencode "limit=$limit" \
    --data-urlencode "direction=backward" \
    "$base_url/datasources/proxy/uid/$uid/loki/api/v1/query_range" | pretty
fi
