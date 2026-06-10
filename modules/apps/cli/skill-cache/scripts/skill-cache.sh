#!/usr/bin/env bash
# skill-cache — warm cache for query skills.
#
# Stores per-skill identity mappings and slow-changing metadata as JSON at
# $XDG_CACHE_HOME/claude-skills/<skill>.json. Depends only on bash + jq +
# coreutils, so it can be vendored verbatim into a portable skill as
# scripts/skill-cache.sh. Under Nix it is wrapped by writeShellApplication,
# which re-applies the shebang and `set` harmlessly (a second shebang line is
# just a comment to shellcheck).
set -euo pipefail

VERSION="1"

usage() {
  cat <<'EOF'
skill-cache — warm cache for query skills

Usage:
  skill-cache get    <skill> <table> <key> [--allow-stale]
  skill-cache put    <skill> <table> <key> <json-value> [--ttl DURATION] [--alias NAME]...
  skill-cache forget <skill> <table> [<key>]
  skill-cache list   <skill> [<table>] [--json]
  skill-cache path   <skill>

get exit codes: 0 fresh hit, 3 miss, 4 expired (unless --allow-stale).
--ttl DURATION is <n>h or <n>d (e.g. 12h, 7d, 30d). Omit --ttl to store an
identity entry that never expires. Keys match case-insensitively with
whitespace collapsed; register extra lookup names with repeated --alias.
EOF
}

die() { echo "skill-cache: $*" >&2; exit 2; }

cache_dir() { printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/claude-skills"; }

cache_file() {
  [ -n "${1:-}" ] || die "missing <skill>"
  printf '%s/%s.json' "$(cache_dir)" "$1"
}

# normalize: lowercase, collapse whitespace runs to one space, trim ends.
norm() {
  local s
  s="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')"
  s="${s# }"; s="${s% }"
  printf '%s' "$s"
}

# echo the cache JSON, or an empty skeleton when the file is missing/corrupt.
read_cache() {
  if [ -f "$1" ] && jq -e . "$1" >/dev/null 2>&1; then
    cat "$1"
  else
    printf '{"schema":%s,"tables":{}}' "$VERSION"
  fi
}

# atomic write via tempfile + mv in the same directory.
write_cache() {
  local dir tmp
  dir="$(dirname "$1")"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.skill-cache.XXXXXX")"
  printf '%s\n' "$2" > "$tmp"
  mv -f "$tmp" "$1"
}

# duration (<n>h|<n>d) -> seconds. Forces base-10 to avoid octal on leading 0.
ttl_seconds() {
  local d="$1" num unit
  case "$d" in
    *[!0-9hd]* | "") die "bad --ttl '$d' (use <n>h or <n>d)";;
  esac
  num="${d%[hd]}"
  unit="${d##*[0-9]}"
  [ -n "$num" ] || die "bad --ttl '$d' (use <n>h or <n>d)"
  case "$unit" in
    h) printf '%s' "$(( 10#$num * 3600 ))";;
    d) printf '%s' "$(( 10#$num * 86400 ))";;
    *) die "bad --ttl '$d' (use <n>h or <n>d)";;
  esac
}

cmd="${1:-}"; [ -n "$cmd" ] || { usage; exit 2; }
shift || true

case "$cmd" in
  -h|--help|help) usage; exit 0;;

  get)
    allow_stale=0
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --allow-stale) allow_stale=1;;
        -*) die "unknown flag for get: $1";;
        *) args+=("$1");;
      esac
      shift
    done
    [ "${#args[@]}" -eq 3 ] || die "usage: get <skill> <table> <key>"
    skill="${args[0]}"; table="${args[1]}"; nkey="$(norm "${args[2]}")"
    f="$(cache_file "$skill")"
    # alias lookup: first matching entry by object order wins (uniqueness not enforced)
    entry="$(read_cache "$f" | jq -c --arg t "$table" --arg k "$nkey" '
      (.tables[$t] // {}) as $tbl
      | ($tbl[$k] // ([ $tbl | to_entries[]
          | select((.value.aliases // []) | index($k)) | .value ] | first))
    ')"
    if [ -z "$entry" ] || [ "$entry" = "null" ]; then exit 3; fi
    status="$(printf '%s' "$entry" | jq -r '
      .expires_at as $e
      | if $e == null then "fresh"
        elif ($e | fromdateiso8601) > now then "fresh"
        else "expired" end')"
    if [ "$status" = "expired" ] && [ "$allow_stale" -eq 0 ]; then exit 4; fi
    printf '%s' "$entry" | jq -c '.value'
    ;;

  put)
    ttl=""
    aliases='[]'
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --ttl) shift; ttl="${1:-}"; [ -n "$ttl" ] || die "--ttl needs a value";;
        --alias)
          shift; [ -n "${1:-}" ] || die "--alias needs a value"
          aliases="$(printf '%s' "$aliases" | jq -c --arg a "$(norm "$1")" '. + [$a] | unique')";;
        -*) die "unknown flag for put: $1";;
        *) args+=("$1");;
      esac
      shift
    done
    [ "${#args[@]}" -eq 4 ] || die "usage: put <skill> <table> <key> <json-value> [--ttl D] [--alias N]..."
    skill="${args[0]}"; table="${args[1]}"; nkey="$(norm "${args[2]}")"; value="${args[3]}"
    printf '%s' "$value" | jq . >/dev/null 2>&1 || die "<json-value> is not valid JSON"
    if [ -n "$ttl" ]; then ttlsec="$(ttl_seconds "$ttl")"; else ttlsec="null"; fi
    f="$(cache_file "$skill")"
    new="$(read_cache "$f" | jq -c \
      --arg t "$table" --arg k "$nkey" \
      --argjson v "$value" --argjson aliases "$aliases" --argjson ttl "$ttlsec" '
      .tables[$t] = (.tables[$t] // {})
      | .tables[$t][$k] = {
          value: $v,
          aliases: $aliases,
          cached_at: (now | todateiso8601),
          expires_at: (if $ttl == null then null else ((now + $ttl) | todateiso8601) end)
        }')"
    write_cache "$f" "$new"
    ;;

  forget)
    [ $# -ge 2 ] || die "usage: forget <skill> <table> [<key>]"
    skill="$1"; table="$2"; key="${3:-}"
    f="$(cache_file "$skill")"
    if [ -n "$key" ]; then
      nkey="$(norm "$key")"
      new="$(read_cache "$f" | jq -c --arg t "$table" --arg k "$nkey" '
        if .tables[$t] then .tables[$t] |= del(.[$k]) else . end')"
    else
      new="$(read_cache "$f" | jq -c --arg t "$table" 'del(.tables[$t])')"
    fi
    write_cache "$f" "$new"
    ;;

  list)
    as_json=0
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --json) as_json=1;;
        -*) die "unknown flag for list: $1";;
        *) args+=("$1");;
      esac
      shift
    done
    [ "${#args[@]}" -ge 1 ] || die "usage: list <skill> [<table>] [--json]"
    skill="${args[0]}"; table="${args[1]:-}"
    f="$(cache_file "$skill")"
    data="$(read_cache "$f")"
    if [ "$as_json" -eq 1 ]; then
      if [ -n "$table" ]; then
        printf '%s' "$data" | jq --arg t "$table" '.tables[$t] // {}'
      else
        printf '%s' "$data" | jq '.'
      fi
    elif [ -n "$table" ]; then
      printf '%s' "$data" | jq -r --arg t "$table" '
        (.tables[$t] // {}) | to_entries[]
        | "\(.key)\t\(.value.expires_at // "identity")"'
    else
      printf '%s' "$data" | jq -r '
        .tables | to_entries[] as $t
        | $t.value | to_entries[]
        | "\($t.key)\t\(.key)\t\(.value.expires_at // "identity")"'
    fi
    ;;

  path)
    [ $# -eq 1 ] || die "usage: path <skill>"
    printf '%s\n' "$(cache_file "$1")"
    ;;

  *) die "unknown command '$cmd' (try --help)";;
esac
