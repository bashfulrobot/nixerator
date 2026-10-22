#!/usr/bin/env bash
# One-time bootstrap: copy values from 1Password into the secauto gopass store.
#
# Reads the shared map (modules/apps/cli/render-secrets/gopass-map.tsv), runs
# `op read` per row and pipes each value straight into `gopass insert`. A value
# never reaches stdout, argv or a log; the output is entry names plus
# ok / skip / FAIL.
#
# Run it where `gopass` can write to the secauto store (qbert, the writer). Auth:
# the service-account token file when it exists (no desktop prompt), otherwise
# the 1Password desktop session. Pass --desktop to force the desktop session.
#
# Safe to rerun. An entry that is present and non-empty is skipped, and a value
# is inserted only when `op read` returned something: piping an empty read
# straight into `gopass insert -f` would store an empty entry and hide the
# failure from every later run.
#
# Not covered: Document items (SSH keys, certificates). Those stay on
# render-secrets' MATERIALIZE path until they get their own pass.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
map="${GOPASS_MAP:-${here}/../../modules/apps/cli/render-secrets/gopass-map.tsv}"
[[ -r "${map}" ]] || {
  echo "import-op-to-gopass: map not found: ${map}" >&2
  exit 1
}
for tool in op gopass; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "import-op-to-gopass: '${tool}' not in PATH" >&2
    exit 1
  }
done

desktop=0 mirror=0 dry=0
for arg in "$@"; do
  case "${arg}" in
    --desktop) desktop=1 ;;
    --mirror) mirror=1 ;;
    --dry-run) dry=1 ;;
    *)
      echo "usage: import-op-to-gopass.sh [--desktop] [--mirror] [--dry-run]" >&2
      exit 2
      ;;
  esac
done

sa_file="${HOME}/.config/op/service-account-token"
if [[ "${desktop}" -eq 1 || ! -r "${sa_file}" ]]; then
  unset OP_SERVICE_ACCOUNT_TOKEN
else
  OP_SERVICE_ACCOUNT_TOKEN="$(<"${sa_file}")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

ok=0 skip=0 fail=0

# slug TEXT — lowercase, anything outside [a-z0-9._-] becomes '-', trimmed.
slug() {
  tr '[:upper:]' '[:lower:]' <<<"$1" | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

# mirror_vault VAULT — copy every non-empty credential field of every item in
# VAULT to the gopass entry <vault>/<item>/<field> (slugged). Skipped on purpose:
#   - Documents and SSH keys: identity-class files stay in render-secrets'
#     MATERIALIZE, because the one shared GPG key would expose them on every host.
#   - 1Password service-account tokens: being retired from automation.
#   - fields the map already covers (they live under their map name).
# Item JSON is held only in this shell's memory. Field values flow
# jq -> gopass insert and are never printed.
mirror_vault() {
  local vault="$1" row id title cat dups item_json idx label ref entry name_title
  dups="$(op item list --vault "${vault}" --format=json 2>/dev/null | jq -r '[.[].title] | group_by(.) | map(select(length > 1) | .[0]) | .[]')"
  while IFS= read -r row; do
    [[ -n "${row}" ]] || continue
    id="$(jq -r '.id' <<<"${row}")"
    title="$(jq -r '.title' <<<"${row}")"
    cat="$(jq -r '.category' <<<"${row}")"
    case "${cat}" in
      DOCUMENT | SSH_KEY)
        echo "skip  ${vault}/${title} [${cat}] (identity-class file, stays in MATERIALIZE)"
        skip=$((skip + 1))
        continue
        ;;
    esac
    if [[ "${title}" == *"Service Account Auth Token"* ]]; then
      echo "skip  ${vault}/${title} (service-account token)"
      skip=$((skip + 1))
      continue
    fi
    item_json="$(op item get "${id}" --vault "${vault}" --format=json 2>/dev/null)"
    if [[ -z "${item_json}" ]]; then
      echo "FAIL  ${vault}/${title} (could not read item)"
      fail=$((fail + 1))
      continue
    fi
    name_title="$(slug "${title}")"
    if grep -qxF -- "${title}" <<<"${dups}"; then
      name_title="${name_title}-$(slug "${id}" | cut -c1-6)"
    fi
    for ((idx = 0; idx < $(jq -r '.fields | length' <<<"${item_json}"); idx++)); do
      label="$(jq -r --argjson i "${idx}" '.fields[$i].label // .fields[$i].id' <<<"${item_json}")"
      [[ -n "$(jq -r --argjson i "${idx}" '.fields[$i] | select(.id != "notesPlain") | .value // empty' <<<"${item_json}")" ]] || continue
      ref="op://${vault}/${title}/${label}"
      if awk -F'\t' -v r="${ref}" '$0 !~ /^#/ && $2 == r { found = 1 } END { exit !found }' "${map}"; then
        echo "skip  ${vault}/${title}/${label} (covered by the map)"
        skip=$((skip + 1))
        continue
      fi
      entry="${vault}/${name_title}/$(slug "${label}")"
      if [[ -n "$(gopass show -o "${entry}" 2>/dev/null)" ]]; then
        echo "skip  ${entry} (present, non-empty)"
        skip=$((skip + 1))
        continue
      fi
      if [[ "${dry}" -eq 1 ]]; then
        echo "would ${entry}"
        ok=$((ok + 1))
        continue
      fi
      if jq -j --argjson i "${idx}" '.fields[$i].value' <<<"${item_json}" | gopass insert -f "${entry}" >/dev/null 2>&1 &&
        [[ -n "$(gopass show -o "${entry}" 2>/dev/null)" ]]; then
        echo "ok    ${entry}"
        ok=$((ok + 1))
      else
        echo "FAIL  ${entry}"
        fail=$((fail + 1))
      fi
    done
  done < <(op item list --vault "${vault}" --format=json 2>/dev/null | jq -c '.[] | {id, title, category}')
  unset item_json
}
while IFS=$'\t' read -r entry ref; do
  [[ -z "${entry}" || "${entry}" == \#* ]] && continue
  if [[ -n "$(gopass show -o "${entry}" 2>/dev/null)" ]]; then
    echo "skip  ${entry} (present, non-empty)"
    skip=$((skip + 1))
    continue
  fi
  if [[ "${dry}" -eq 1 ]]; then
    echo "would ${entry}"
    ok=$((ok + 1))
    continue
  fi
  val="$(op read "${ref}" 2>/dev/null)"
  if [[ -n "${val}" ]] &&
    printf '%s' "${val}" | gopass insert -f "${entry}" >/dev/null 2>&1 &&
    [[ -n "$(gopass show -o "${entry}" 2>/dev/null)" ]]; then
    echo "ok    ${entry}"
    ok=$((ok + 1))
  else
    echo "FAIL  ${entry}  <- ${ref}"
    fail=$((fail + 1))
  fi
  unset val
done <"${map}"

if [[ "${mirror}" -eq 1 ]]; then
  for vault in automation nixerator; do
    echo "=== mirror: ${vault}"
    mirror_vault "${vault}"
  done
fi

echo "---"
if [[ "${dry}" -eq 1 ]]; then
  echo "dry run: would_write=${ok} skipped=${skip} failed=${fail}"
  exit 0
fi
echo "imported=${ok} skipped=${skip} failed=${fail}"
if gopass sync >/dev/null 2>&1; then
  echo "synced with the secauto remote"
else
  echo "gopass sync failed: run 'gopass sync' and read its output"
fi
[[ "${fail}" -eq 0 ]]
