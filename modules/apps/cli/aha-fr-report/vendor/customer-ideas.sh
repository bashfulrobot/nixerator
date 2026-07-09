#!/usr/bin/env bash
# Pull-and-assess: list the Aha! ideas a customer has endorsed, with status.
#
# A customer (an Aha "idea organization") endorses ideas via proxy votes. This
# script turns a customer name into an assessed table in three steps, the fast
# way:
#
#   1. Resolve the name to one or more idea organizations
#      (idea_organizations?q=NAME). If a spaced name finds nothing, it retries
#      with the spaces removed -- "Health Equity" -> "HealthEquity".
#   2. For each org, ONE paginated pass over its endorsements with
#      `fields=idea,weight` -- this embeds each idea's ref + name + the
#      customer's vote weight, so no per-idea call is needed just to list them.
#   3. The endorsement payload omits workflow_status, so fetch only that, for
#      the unique ideas, IN PARALLEL (not a serial loop) -- the one place an
#      N+1 is unavoidable, made cheap by concurrency under Aha's rate ceiling.
#
# Then it prints an open-vs-closed table (or JSON with --json).
#
# Usage:
#   customer-ideas.sh "HealthEquity"
#   customer-ideas.sh "HealthEquity" --open          # only still-open ideas
#   customer-ideas.sh "HealthEquity" --json          # assessed array, for jq
#   customer-ideas.sh --org ACCOUNT-O-32404          # pin to one org, skip search
#   customer-ideas.sh "Acme" --exact                 # exact (case-insensitive) name match
#
# Options:
#   --open           Show only ideas whose status is not closed/shipped/declined.
#   --json           Emit the assessed array as JSON instead of a table.
#   --org REF|ID     Use this idea organization directly (repeatable); skips the
#                    name search. REF looks like ACCOUNT-O-32404.
#   --exact          When searching by name, keep only exact name matches
#                    (case-insensitive). Default keeps every fuzzy match.
#   -h, --help       Show this help.
#
# "Closed" is a heuristic on the status name (shipped / will not / declined /
# duplicate / already exists / rejected / complete). The real status is always
# shown, so you can judge the edge cases yourself.
#
# Config via environment:
#   AHA_API_TOKEN              Required (read by aha.sh).
#   AHA_SUBDOMAIN              Account subdomain (default konghq), via aha.sh.
#   CUSTOMER_IDEAS_PARALLEL    Concurrent status fetches (default 6). Aha allows
#                              20 req/s; 6 stays comfortably under it.
#
# Requires: curl, jq (and aha.sh alongside this script).

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AHA="$here/aha.sh"
[[ -x "$AHA" ]] || AHA="bash $here/aha.sh"

PARALLEL="${CUSTOMER_IDEAS_PARALLEL:-6}"
CLOSED_RE='shipped|will not|won.?t|declined|already exists|duplicate|rejected|^complete|^done'

die() {
  echo "ERROR: $*" >&2
  exit 2
}

name=""
want_json=""
open_only=""
exact=""
declare -a org_refs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      want_json="1"
      shift
      ;;
    --open)
      open_only="1"
      shift
      ;;
    --exact)
      exact="1"
      shift
      ;;
    --org)
      [[ $# -ge 2 ]] || die "--org needs a REF or ID"
      org_refs+=("$2")
      shift 2
      ;;
    -h | --help)
      sed -n '2,46p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) die "unknown flag: $1" ;;
    *) if [[ -z "$name" ]]; then
      name="$1"
      shift
    else die "unexpected argument: $1"; fi ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "'jq' is required but not on PATH"
[[ -n "$name" || ${#org_refs[@]} -gt 0 ]] || die "give a customer name (e.g. \"HealthEquity\") or --org REF"

aha() { $AHA "$@"; }

# --- Step 1: resolve organizations -----------------------------------------
# Each entry is "id<TAB>name".
declare -a orgs=()

if [[ ${#org_refs[@]} -gt 0 ]]; then
  for ref in "${org_refs[@]}"; do
    row="$(aha get "idea_organizations/$ref" -q 'fields=id,name' --raw 2>/dev/null |
      jq -r '.idea_organization | select(.id) | "\(.id)\t\(.name)"' || true)"
    [[ -n "$row" ]] || die "idea organization not found: $ref"
    orgs+=("$row")
  done
else
  search_orgs() {
    aha get idea_organizations -q "q=$1" -q 'fields=id,name' -q per_page=50 --raw 2>/dev/null |
      jq -r '.idea_organizations[] | "\(.id)\t\(.name)"'
  }
  mapfile -t orgs < <(search_orgs "$name")
  # Retry without spaces -- "Health Equity" finds nothing; "HealthEquity" does.
  if [[ ${#orgs[@]} -eq 0 && "$name" == *" "* ]]; then
    mapfile -t orgs < <(search_orgs "${name// /}")
  fi
  if [[ -n "$exact" ]]; then
    lc_name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    declare -a kept=()
    for o in "${orgs[@]}"; do
      onm="$(printf '%s' "${o#*$'\t'}" | tr '[:upper:]' '[:lower:]')"
      [[ "$onm" == "$lc_name" ]] && kept+=("$o")
    done
    orgs=("${kept[@]:-}")
    [[ -n "${orgs[0]:-}" ]] || orgs=()
  fi
  [[ ${#orgs[@]} -gt 0 ]] || die "no idea organization matched \"$name\". Try the exact portal name, or --org REF."
fi

echo "Matched ${#orgs[@]} organization(s):" >&2
for o in "${orgs[@]}"; do echo "  - ${o#*$'\t'}  (id ${o%%$'\t'*})" >&2; done

# --- Step 2: one paginated endorsements pass per org -----------------------
# Embeds idea ref + name + the customer's vote weight; no per-idea call here.
endt="$(mktemp)"
trap 'rm -f "$endt"' EXIT
for o in "${orgs[@]}"; do
  oid="${o%%$'\t'*}"
  aha get "idea_organizations/$oid/endorsements" --paginate -q per_page=100 -q 'fields=idea,weight' 2>/dev/null |
    jq -c '.[] | select(.idea != null and .idea.reference_num != null)
             | {ref:.idea.reference_num, name:.idea.name, weight:(.weight // 1)}' >>"$endt"
done

# Aggregate by idea: sum the customer's weight, count endorsements.
agg="$(jq -s 'group_by(.ref) | map({ref:.[0].ref, name:.[0].name,
              cust_weight:(map(.weight)|add), cust_votes:length})' "$endt")"
n_ideas="$(echo "$agg" | jq 'length')"
if [[ "$n_ideas" -eq 0 ]]; then
  echo "No endorsed ideas found for this customer." >&2
  [[ -n "$want_json" ]] && echo "[]"
  exit 0
fi

# --- Step 3: parallel status fetch for the unique ideas --------------------
statdir="$(mktemp -d)"
trap 'rm -f "$endt"; rm -rf "$statdir"' EXIT
fetch_status() {
  local ref="$1"
  $AHA get "ideas/$ref" -q 'fields=reference_num,name,workflow_status,endorsements_count,url' --raw \
    2>/dev/null >"$statdir/$ref.json" || true
}
export -f fetch_status
export AHA statdir
echo "$agg" | jq -r '.[].ref' |
  xargs -P "$PARALLEL" -I{} bash -c 'fetch_status "$@"' _ {}

statuses="$(jq -s '[ .[] | .idea // empty
  | {ref:.reference_num, status:(.workflow_status.name // "Unknown"),
     total_endorsements:.endorsements_count, url} ]' "$statdir"/*.json 2>/dev/null || echo '[]')"

# --- Join + classify -------------------------------------------------------
assessed="$(jq -n --argjson agg "$agg" --argjson st "$statuses" --arg closed "$CLOSED_RE" '
  ($st | map({(.ref): .}) | add // {}) as $byref
  | $agg | map(. + ($byref[.ref] // {status:"(deleted)", url:null, total_endorsements:null}))
  | map(. + {state: (if (.status // "" | ascii_downcase | test($closed)) then "closed" else "open" end)})
  | sort_by(.state != "open", -(.cust_weight // 0), .ref)
')"

[[ -n "$open_only" ]] && assessed="$(echo "$assessed" | jq '[.[] | select(.state=="open")]')"

if [[ -n "$want_json" ]]; then
  echo "$assessed"
  exit 0
fi

# --- Table -----------------------------------------------------------------
open_n="$(echo "$assessed" | jq '[.[]|select(.state=="open")]|length')"
closed_n="$(echo "$assessed" | jq '[.[]|select(.state=="closed")]|length')"
deleted_n="$(echo "$assessed" | jq '[.[]|select(.status=="(deleted)")]|length')"

{
  printf 'STATE\tREF\tWT\tSTATUS\tIDEA\n'
  echo "$assessed" | jq -r '.[]
    | [(if .state=="open" then "OPEN" else "closed" end),
       .ref, (.cust_weight|tostring), .status,
       (.name // "" | if length>58 then .[0:57]+"…" else . end)] | @tsv'
} | column -t -s $'\t'

echo
if [[ -n "$open_only" ]]; then
  echo "→ $open_n open idea(s) shown."
else
  echo "→ $open_n open, $closed_n closed$([[ "$deleted_n" -gt 0 ]] && echo ", $deleted_n deleted/merged")."
fi
