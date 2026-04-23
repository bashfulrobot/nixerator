#!/usr/bin/env bash
# Describe a Salesforce SObject.
#
# Usage:
#   sfdc-describe.sh <SObjectName> [--fields-only] [--target-org ALIAS]
#
# Default output: full describe JSON (pretty-printed).
# --fields-only : compact table of NAME / LABEL / TYPE / UPDATEABLE / CREATEABLE
#                 -- the most common thing you want before a query or write.

set -euo pipefail

fields_only=0
target_org=()
sobject=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fields-only)
      fields_only=1
      shift
      ;;
    --target-org)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --target-org needs a value" >&2
        exit 2
      fi
      target_org=(--target-org "$2")
      shift 2
      ;;
    -h | --help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [[ -z "$sobject" ]]; then
        sobject="$1"
        shift
      else
        echo "ERROR: unexpected positional arg: $1" >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$sobject" ]]; then
  echo "ERROR: missing SObject name" >&2
  echo "Usage: $0 <SObjectName> [--fields-only] [--target-org ALIAS]" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

raw=$(sf sobject describe --sobject "$sobject" --json "${target_org[@]}")

if [[ "$fields_only" -eq 1 ]]; then
  jq -r '.result.fields[] | [.name, .label, .type, (.updateable|tostring), (.createable|tostring)] | @tsv' <<<"$raw" |
    (
      printf 'NAME\tLABEL\tTYPE\tUPDATEABLE\tCREATEABLE\n'
      cat
    ) |
    column -t -s $'\t'
else
  jq '.result' <<<"$raw"
fi
