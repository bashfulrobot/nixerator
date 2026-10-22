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

sa_file="${HOME}/.config/op/service-account-token"
if [[ "${1:-}" == "--desktop" || ! -r "${sa_file}" ]]; then
  unset OP_SERVICE_ACCOUNT_TOKEN
else
  OP_SERVICE_ACCOUNT_TOKEN="$(<"${sa_file}")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

ok=0 skip=0 fail=0
while IFS=$'\t' read -r entry ref; do
  [[ -z "${entry}" || "${entry}" == \#* ]] && continue
  if [[ -n "$(gopass show -o "${entry}" 2>/dev/null)" ]]; then
    echo "skip  ${entry} (present, non-empty)"
    skip=$((skip + 1))
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

echo "---"
echo "imported=${ok} skipped=${skip} failed=${fail}"
if gopass sync >/dev/null 2>&1; then
  echo "synced with the secauto remote"
else
  echo "gopass sync failed: run 'gopass sync' and read its output"
fi
[[ "${fail}" -eq 0 ]]
