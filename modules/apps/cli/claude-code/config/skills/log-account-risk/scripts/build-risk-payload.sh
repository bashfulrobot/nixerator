#!/usr/bin/env bash
# Build the JSON body for an Account_Risk__c create.
#
# The Next_Steps__c HTML and the Help_Needed__c plain text are loaded from
# files via `jq --rawfile`, so multi-line HTML/text is embedded safely --
# never hand-concatenated into a string, which is what makes
# `sf data create --values` fragile for rich-text fields.
#
# Usage:
#   build-risk-payload.sh --fields fields.json --html next_steps.html \
#     [--help-file help_needed.txt] > payload.json
#
#   --fields FILE  JSON object of the scalar createable fields, e.g.
#                  {"Name":"...", "Account__c":"001...", "Type__c":"Late Deployment",
#                   "Status__c":"1. Open", "Source__c":"CSM Sentiment Update",
#                   "Trend__c":"Decreasing", "Opportunity__c":"006...",
#                   "Mitigation_Plan__c":"..."}
#                  Do NOT put Next_Steps__c or Help_Needed__c here; they come
#                  from the files below. Omit any field you are not setting.
#   --html FILE    File containing the Next_Steps__c rich-text HTML
#                  (per references/narrative-format.md).
#   --help-file    File containing the Help_Needed__c plain-text paragraph.
#                  Optional; if omitted, Help_Needed__c is left unset.
#
# The trailing newline on each rawfile is trimmed so the stored value is clean.

set -euo pipefail

fields_file=""
html_file=""
help_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fields)
      fields_file="${2:?--fields needs a file}"
      shift 2
      ;;
    --html)
      html_file="${2:?--html needs a file}"
      shift 2
      ;;
    --help-file)
      help_file="${2:?--help-file needs a file}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$fields_file" ]] || {
  echo "ERROR: --fields file not found: $fields_file" >&2
  exit 2
}
[[ -f "$html_file" ]] || {
  echo "ERROR: --html file not found: $html_file" >&2
  exit 2
}

# Validate the fields file is a JSON object up front, so a typo fails here
# rather than at the Salesforce API.
if ! jq -e 'type == "object"' "$fields_file" >/dev/null 2>&1; then
  echo "ERROR: --fields must contain a single JSON object" >&2
  exit 2
fi

if [[ -n "$help_file" ]]; then
  [[ -f "$help_file" ]] || {
    echo "ERROR: --help-file not found: $help_file" >&2
    exit 2
  }
  jq \
    --rawfile next_steps "$html_file" \
    --rawfile help_needed "$help_file" \
    '. + {
       Next_Steps__c: ($next_steps | rtrimstr("\n")),
       Help_Needed__c: ($help_needed | rtrimstr("\n"))
     }' \
    "$fields_file"
else
  jq \
    --rawfile next_steps "$html_file" \
    '. + { Next_Steps__c: ($next_steps | rtrimstr("\n")) }' \
    "$fields_file"
fi
