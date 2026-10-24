#!/usr/bin/env bash
# Split the secauto gopass store by recipient: a top-level directory listed in
# secauto-recipients.tsv is encrypted only to the writer (qbert) plus the hosts named
# on its row, using a .gpg-id file in that directory. A host that is not a recipient
# cannot decrypt those entries, so a compromised reader exposes only its own subset.
#
# Run it on qbert (the writer, which holds every host's PUBLIC key in its keyring).
# It never prints a value: re-encryption pipes `gopass show -f` straight into
# `gopass insert -f` inside this process.
#
#   secauto-recipients.sh plan            show what would change, write nothing
#   secauto-recipients.sh apply --yes     write the .gpg-id files and re-encrypt
#
# Inputs (names and public fingerprints only, safe in git):
#   secauto-hosts.tsv        host <TAB> GPG fingerprint of that host's own key
#   secauto-recipients.tsv   gopass directory <TAB> comma-separated hosts
# The writer host (WRITER, default qbert) is always a recipient.
#
# Verified on a throwaway store (gopass 1.17.4): a .gpg-id in a subdirectory of one
# store is honoured, entry names do not change, and a host outside the list cannot
# decrypt the entry. Root entries and unlisted directories keep their current
# recipients; change the root .gpg-id (`gopass recipients remove`) only after every
# host works with its own key.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hosts_file="${SECAUTO_HOSTS:-${here}/secauto-hosts.tsv}"
rows_file="${SECAUTO_RECIPIENTS:-${here}/secauto-recipients.tsv}"
store="${SECAUTO_STORE:-${HOME}/.local/share/gopass/stores/root}"
writer="${SECAUTO_WRITER:-qbert}"

mode="${1:-}"
yes=0
[[ "${2:-}" == "--yes" ]] && yes=1
case "${mode}" in
  plan | apply) ;;
  *)
    echo "usage: secauto-recipients.sh plan | apply --yes" >&2
    exit 2
    ;;
esac
if [[ "${mode}" == "apply" && "${yes}" -ne 1 ]]; then
  echo "secauto-recipients: apply rewrites .gpg-id files and re-encrypts entries; pass --yes" >&2
  exit 2
fi
for tool in gopass gpg awk; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "secauto-recipients: '${tool}' not in PATH" >&2
    exit 1
  }
done
[[ -d "${store}" ]] || {
  echo "secauto-recipients: store not found: ${store}" >&2
  exit 1
}

# fingerprint HOST — the host's fingerprint from the hosts table, or empty.
fingerprint() { awk -F'\t' -v h="$1" '$0 !~ /^#/ && $1 == h { print $2; exit }' "${hosts_file}"; }

fail=0 changed=0
while IFS=$'\t' read -r dir hosts; do
  [[ -z "${dir}" || "${dir}" == \#* ]] && continue
  if [[ "${dir}" == *..* || "${dir}" == /* ]]; then
    echo "FAIL  ${dir}: path must be a relative directory inside the store"
    fail=$((fail + 1))
    continue
  fi
  fprs=()
  ok=1
  for h in "${writer}" ${hosts//,/ }; do
    f="$(fingerprint "${h}")"
    if [[ -z "${f}" ]]; then
      echo "FAIL  ${dir}: no fingerprint for host '${h}' in ${hosts_file##*/}"
      ok=0
      break
    fi
    if ! gpg --list-keys "${f}" >/dev/null 2>&1; then
      echo "FAIL  ${dir}: public key ${f} (${h}) is not in this keyring"
      ok=0
      break
    fi
    [[ " ${fprs[*]:-} " == *" ${f} "* ]] || fprs+=("${f}")
  done
  if [[ "${ok}" -ne 1 ]]; then
    fail=$((fail + 1))
    continue
  fi
  count=0
  while IFS= read -r -d '' file; do
    count=$((count + 1))
  done < <(find "${store}/${dir}" -type f -name '*.gpg' -print0 2>/dev/null)
  echo "${mode}  ${dir} -> ${writer},${hosts} (${#fprs[@]} recipients, ${count} entries)"
  [[ "${mode}" == "plan" ]] && continue

  mkdir -p "${store}/${dir}"
  printf '%s\n' "${fprs[@]}" >"${store}/${dir}/.gpg-id"
  # Re-encrypt every entry so its recipient list matches the new .gpg-id. The value
  # moves through a pipe inside this process and is never printed.
  while IFS= read -r -d '' file; do
    entry="${file#"${store}"/}"
    entry="${entry%.gpg}"
    if gopass show -f -- "${entry}" 2>/dev/null | gopass insert -f -- "${entry}" >/dev/null 2>&1; then
      changed=$((changed + 1))
    else
      echo "FAIL  ${entry}: re-encrypt failed"
      fail=$((fail + 1))
    fi
  done < <(find "${store}/${dir}" -type f -name '*.gpg' -print0)
done <"${rows_file}"

echo "---"
echo "${mode}: re-encrypted=${changed} failed=${fail}"
if [[ "${mode}" == "apply" && "${changed}" -gt 0 ]]; then
  echo "Next: gopass sync (push the store), then verify each host with: gopass show -o <entry>"
fi
[[ "${fail}" -eq 0 ]]
