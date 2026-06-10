#!/usr/bin/env bash
# Thin, reproducible wrapper around the Aha! REST API.
#
# Auth comes from the AHA_API_TOKEN environment variable -- the script has no
# dependency on any particular secrets tool, so it stays portable. Everything
# else is a thin pass-through to the Aha! v1 API so you can hit any endpoint
# without re-deriving curl + auth.
#
# Usage:
#   aha.sh <method> <path> [options]
#   aha.sh get  features/DEVP-123
#   aha.sh get  products/DEVP/ideas -q 'q=rate limiting' -q per_page=50
#   aha.sh get  products/DEVP/ideas --paginate -q 'category=Security'
#   aha.sh post ideas/PROD-I-42/votes -d '{"idea_vote":{"email":"a@b.com","vote_weight":5}}'
#   aha.sh put  features/DEVP-123 -d @body.json
#   aha.sh delete features/DEVP-123
#
# <method>  get | post | put | delete (case-insensitive). Defaults to get if
#           the first arg already looks like a path.
# <path>    Path relative to /api/v1/ (leading slash optional).
#
# Options:
#   -q, --query KEY=VALUE   Add a query param (repeatable). Value is URL-encoded.
#   -d, --data BODY         Request body: inline JSON, or @file to read a file.
#       --paginate          Follow every page and merge the collection array
#                           into a single JSON array (GET only).
#       --per-page N        Page size (default 100, max 200).
#       --raw               Print the response as-is (skip jq pretty-printing).
#       --status            Also print the HTTP status line to stderr.
#   -h, --help              Show this help.
#
# Auth: the API token is read from the AHA_API_TOKEN environment variable.
# How that variable gets set is up to you -- a shell export, a `.env` you
# source, a CI secret, or a secrets manager. The script stays portable and
# carries no dependency on any particular vault or tool.
#
# Config via environment (sensible defaults for Kong):
#   AHA_API_TOKEN   Required. Your Aha! API key (Bearer token).
#   AHA_SUBDOMAIN   Account subdomain. Default: konghq  (=> konghq.aha.io)
#
# Requires: curl, jq.

set -euo pipefail

AHA_SUBDOMAIN="${AHA_SUBDOMAIN:-konghq}"
base_url="https://${AHA_SUBDOMAIN}.aha.io/api/v1"

method=""
path=""
declare -a query=()
data=""
paginate=""
per_page="100"
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
    --paginate)
      paginate="1"
      shift
      ;;
    --per-page)
      [[ $# -ge 2 ]] || die "--per-page needs a value"
      per_page="$2"
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
      sed -n '2,41p' "$0" | sed 's/^# \{0,1\}//'
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

# First positional after flags may still be the path (when method was omitted).
if [[ -z "$path" && $# -ge 1 ]]; then
  path="$1"
  shift
fi
[[ -n "$path" ]] || die "missing API path (e.g. 'features/DEVP-123')"
[[ -z "$method" ]] && method="GET"
path="${path#/}"

for dep in curl jq; do
  command -v "$dep" >/dev/null 2>&1 || die "'$dep' is required but not on PATH"
done

token="${AHA_API_TOKEN:-}"
[[ -n "$token" ]] || die "AHA_API_TOKEN is not set. Export your Aha! API key, e.g. 'export AHA_API_TOKEN=...' (generate one at https://secure.aha.io/settings/api_keys)."

# Resolve request body (inline JSON or @file).
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

# Build the query string. curl --data-urlencode handles encoding; we use a
# throwaway GET-style assembly so values like 'q=rate limiting' work.
build_query_url() {
  local page="${1:-}"
  local url="$base_url/$path"
  local -a parts=()
  local kv
  for kv in "${query[@]}"; do parts+=("$kv"); done
  [[ -n "$page" ]] && parts+=("page=$page" "per_page=$per_page")
  if [[ ${#parts[@]} -gt 0 ]]; then
    local enc
    enc="$(
      for kv in "${parts[@]}"; do
        local k="${kv%%=*}" v="${kv#*=}"
        jq -rn --arg k "$k" --arg v "$v" '"\($k)=\($v|@uri)"'
      done | paste -sd '&' -
    )"
    url="$url?$enc"
  fi
  printf '%s' "$url"
}

curl_call() {
  local url="$1"
  local -a c=(curl -sS -X "$method"
    -H "Authorization: Bearer $token"
    -H "Content-Type: application/json"
    -H "Accept: application/json")
  [[ -n "$show_status" ]] && c+=(-w '\nHTTP %{http_code}\n')
  c+=("${body_arg[@]}" "$url")
  "${c[@]}"
}

if [[ -n "$paginate" ]]; then
  [[ "$method" == "GET" ]] || die "--paginate only works with GET"
  page=1
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  : >"$tmp"
  while :; do
    resp="$(curl_call "$(build_query_url "$page")")"
    # The collection is the first top-level array key (features, ideas, ...).
    echo "$resp" | jq -c '(to_entries | map(select(.value|type=="array"))[0].value // [])[]' >>"$tmp"
    total_pages="$(echo "$resp" | jq -r '.pagination.total_pages // 1')"
    [[ "$page" -ge "$total_pages" ]] && break
    page=$((page + 1))
    sleep 0.1 # stay well under Aha's 20 req/s ceiling
  done
  jq -s '.' "$tmp"
else
  resp="$(curl_call "$(build_query_url)")"
  if [[ -n "$raw" ]]; then
    printf '%s\n' "$resp"
  else
    # Pretty-print when it's JSON; fall back to raw for empty/204 bodies.
    printf '%s' "$resp" | jq '.' 2>/dev/null || printf '%s\n' "$resp"
  fi
fi
