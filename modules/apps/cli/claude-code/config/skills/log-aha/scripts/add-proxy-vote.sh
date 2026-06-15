#!/usr/bin/env bash
# Add a proxy vote (idea endorsement) to an Aha idea on a customer's behalf.
#
# The endpoint is POST /ideas/{ref}/endorsements with the body keyed on
# "idea_endorsement". Two gotchas are encoded here so they are not rediscovered
# the hard way:
#   * It is /endorsements, NOT /votes, and the dollar field is "value"
#     (not "vote_weight").
#   * "email" and the custom fields are effectively create-time. Many Aha API
#     tokens are reviewer-role and CANNOT edit or delete an endorsement
#     afterward, so email/value/org/custom-fields MUST be right on this first
#     POST. Confirm them with the user before calling this.
#
# Usage:
#   add-proxy-vote.sh <idea_ref> <org_id> <email> [options]
#
# Options:
#   --value N            Dollar value of the vote. OMIT when the ask is
#                        post-deal or not tied to an opportunity. Do not send 0.
#   --link URL           Source link (e.g. the Slack thread).
#   --desc HTML          Endorsement description (HTML). Or:
#   --desc-file F        Read the description from a file.
#   --cf KEY=VALUE       Set a custom field (repeatable). VALUE is sent as a
#                        string, which is correct for dropdowns (e.g.
#                        blocks_customer, stage), dates (YYYY-MM-DD, e.g.
#                        when_does_the_customer_need_it_by, close_date), and the
#                        reason note (HTML string).
#   --cf-file KEY=PATH   Like --cf but read VALUE from a file (handy for the
#                        long HTML "reason" note).
#   --cf-num KEY=N       Set a numeric custom field (e.g. probability).
#
# Custom-field keys (verified on konghq.aha.io; dropdown OPTION strings must be
# read from the Aha UI since the API does not expose the allowed list):
#   reason                              note (HTML)
#   blocks_customer                     dropdown (e.g. "No ...", "Yes ...")
#   when_does_the_customer_need_it_by   date (YYYY-MM-DD)
#   stage                               dropdown (e.g. "0. Pending Renewal")
#   probability                         number   (use --cf-num)
#   close_date                          date (YYYY-MM-DD)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ref="${1:?usage: add-proxy-vote.sh <idea_ref> <org_id> <email> [options]}"
org="${2:?missing org_id (numeric idea_organization_id)}"
email="${3:?missing email}"
shift 3

value=""; link=""; desc=""
cf_json="{}"

set_cf() { # key, value-as-json
  cf_json="$(printf '%s' "$cf_json" | jq --arg k "$1" --argjson v "$2" '.[$k]=$v')"
}
split_kv() { # "KEY=VALUE" -> sets _k and _v (value may contain '=')
  _k="${1%%=*}"; _v="${1#*=}"
  [[ "$1" == *=* && -n "$_k" ]] || { echo "ERROR: expected KEY=VALUE, got: $1" >&2; exit 2; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --value)     value="$2"; shift 2 ;;
    --link)      link="$2";  shift 2 ;;
    --desc)      desc="$2";  shift 2 ;;
    --desc-file) [[ -f "$2" ]] || { echo "ERROR: desc file not found: $2" >&2; exit 2; }
                 desc="$(cat "$2")"; shift 2 ;;
    --cf)        split_kv "$2"; set_cf "$_k" "$(jq -n --arg v "$_v" '$v')"; shift 2 ;;
    --cf-file)   split_kv "$2"; [[ -f "$_v" ]] || { echo "ERROR: cf file not found: $_v" >&2; exit 2; }
                 set_cf "$_k" "$(jq -Rs '.' "$_v")"; shift 2 ;;
    --cf-num)    split_kv "$2"; set_cf "$_k" "$_v"; shift 2 ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
  esac
done

# jq 1.7+ preserves large integer literals, so the 19-digit org id round-trips
# through --argjson without precision loss.
body="$(jq -n \
  --arg email "$email" \
  --argjson org "$org" \
  --arg link "$link" \
  --arg desc "$desc" \
  --argjson cf "$cf_json" '
  {idea_endorsement: (
     {email: $email, idea_organization_id: $org}
     + (if $link != ""        then {link: $link}        else {} end)
     + (if $desc != ""        then {description: $desc}  else {} end)
     + (if ($cf|length) > 0   then {custom_fields: $cf}  else {} end)
  )}')"

if [[ -n "$value" ]]; then
  body="$(printf '%s' "$body" | jq --argjson v "$value" '.idea_endorsement.value = $v')"
fi

bash "$here/aha.sh" post "ideas/$ref/endorsements" -d "$body"
