#!/usr/bin/env bash
# Thin, reproducible wrapper around the Grafana HTTP API (dashboards, search,
# datasources, alerting, folders -- anything under /api/).
#
# Auth comes from the GRAFANA_TOKEN environment variable -- the script has no
# dependency on any particular secrets tool, so it stays portable. Everything
# else is a thin pass-through to the Grafana REST API so you can hit any
# endpoint without re-deriving curl + auth each time.
#
# Usage:
#   grafana.sh <method> <path> [options]
#   grafana.sh get  search -q 'query=kubernetes'
#   grafana.sh get  dashboards/uid/k8s-cluster-overview
#   grafana.sh post dashboards/db -d @manifests/base/observability/dashboards/k8s-cluster-overview.json
#   grafana.sh get  datasources
#   grafana.sh get  datasources/name/grafanacloud-bashfulrobot-prom
#   grafana.sh get  v1/provisioning/alert-rules
#   grafana.sh get  alertmanager/grafana/api/v2/alerts
#
# <method>  get | post | put | patch | delete (case-insensitive). Defaults to
#           get if the first arg already looks like a path.
# <path>    Path relative to /api/ (leading slash optional).
#
# Options:
#   -q, --query KEY=VALUE   Add a query param (repeatable). Value is URL-encoded.
#   -d, --data BODY         Request body: inline JSON, or @file to read a file.
#       --raw               Print the response as-is (skip jq pretty-printing).
#       --status            Also print the HTTP status line to stderr.
#   -h, --help              Show this help.
#
# Auth: the API token is read from the GRAFANA_TOKEN environment variable.
# How that variable gets set is up to you -- a shell export, a `.env` you
# source, a CI secret, or a secrets manager. The script stays portable and
# carries no dependency on any particular vault or tool. (On this user's
# machines it's exported by the shared fish module from the rendered
# nixerator secrets blob -- see modules/apps/cli/fish/default.nix.)
#
# Config via environment:
#   GRAFANA_TOKEN   Required. A Grafana Service Account token (Bearer).
#   GRAFANA_URL     Base URL of the Grafana instance.
#                   Default: https://bashfulrobot.grafana.net
#
# Note on dashboard JSON: the dashboard files in the `iac` repo
# (manifests/base/observability/dashboards/*.json) already carry the full
# `{dashboard, overwrite, message}` envelope the /api/dashboards/db endpoint
# expects, so `grafana.sh post dashboards/db -d @<file>` works directly on
# them -- no re-wrapping needed.
#
# Requires: curl, jq.

set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-https://bashfulrobot.grafana.net}"
base_url="${GRAFANA_URL%/}/api"

method=""
path=""
declare -a query=()
data=""
raw=""
show_status=""

die() {
  echo "ERROR: $*" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    get | GET | post | POST | put | PUT | patch | PATCH | delete | DELETE)
      if [[ -z "$method" ]]; then
        method="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
        shift
      else
        break
      fi
      ;;
    -q | --query)
      [[ $# -ge 2 ]] || die "$1 needs a KEY=VALUE argument"
      query+=("$2")
      shift 2
      ;;
    -d | --data)
      [[ $# -ge 2 ]] || die "$1 needs a value"
      data="$2"
      shift 2
      ;;
    --raw)
      raw="1"
      shift
      ;;
    --status)
      show_status="1"
      shift
      ;;
    -h | --help)
      sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*) die "unknown flag: $1" ;;
    *)
      if [[ -z "$path" ]]; then
        path="$1"
        shift
      else break; fi
      ;;
  esac
done

if [[ -z "$path" && $# -ge 1 ]]; then
  path="$1"
  shift
fi
[[ -n "$path" ]] || die "missing API path (e.g. 'search' or 'dashboards/uid/k8s-cluster-overview')"
[[ -z "$method" ]] && method="GET"
path="${path#/}"

for dep in curl jq; do
  command -v "$dep" >/dev/null 2>&1 || die "'$dep' is required but not on PATH"
done

token="${GRAFANA_TOKEN:-}"
[[ -n "$token" ]] || die "GRAFANA_TOKEN is not set. Export a Grafana Service Account token, e.g. 'export GRAFANA_TOKEN=...' (create one under Administration -> Service accounts in Grafana Cloud)."

body_arg=()
if [[ -n "$data" ]]; then
  if [[ "$data" == @* ]]; then
    file="${data#@}"
    [[ -f "$file" ]] || die "data file not found: $file"
    body_arg=(--data-binary "@$file")
  else
    body_arg=(--data-binary "$data")
  fi
fi

build_query_url() {
  local url="$base_url/$path"
  if [[ ${#query[@]} -gt 0 ]]; then
    local enc kv k v
    enc="$(
      for kv in "${query[@]}"; do
        k="${kv%%=*}" v="${kv#*=}"
        jq -rn --arg k "$k" --arg v "$v" '"\($k)=\($v|@uri)"'
      done | paste -sd '&' -
    )"
    url="$url?$enc"
  fi
  printf '%s' "$url"
}

declare -a curl_cmd=(curl -sS -X "$method"
  -H "Authorization: Bearer $token"
  -H "Content-Type: application/json"
  -H "Accept: application/json")
[[ -n "$show_status" ]] && curl_cmd+=(-w '\nHTTP %{http_code}\n')
curl_cmd+=("${body_arg[@]}" "$(build_query_url)")

resp="$("${curl_cmd[@]}")"
if [[ -n "$raw" ]]; then
  printf '%s\n' "$resp"
else
  printf '%s' "$resp" | jq '.' 2>/dev/null || printf '%s\n' "$resp"
fi
