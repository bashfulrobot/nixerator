#!/usr/bin/env bats
# Tests for extras/helpers/secauto-recipients.sh against a throwaway gopass store,
# throwaway GPG keys and made-up values. Uses real gopass and gpg (no stubs) because
# the point is that a .gpg-id in a subdirectory really changes who can decrypt.
# Skipped when gopass or gpg is not on PATH.

HELPER="$(cd "${BATS_TEST_DIRNAME}/../../../../../extras/helpers" && pwd)/secauto-recipients.sh"

setup() {
  command -v gopass >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1 || skip "gopass or gpg missing"
  T="$(mktemp -d)"
  export HOME="${T}/home" XDG_CONFIG_HOME="${T}/home/.config" XDG_DATA_HOME="${T}/home/.local/share" XDG_CACHE_HOME="${T}/home/.cache"
  export GOPASS_HOMEDIR="${T}/home" GOPASS_NO_NOTIFY=true GOPASS_NOCOLOR=true
  mkdir -p "${HOME}/.config/gopass"
  # Two throwaway keys: A is the writer ("qbert"), B is a reader ("srv").
  for pair in "A:qbert" "B:srv"; do
    d="${T}/g${pair%%:*}"
    mkdir -m700 "${d}"
    GNUPGHOME="${d}" gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key "${pair##*:} <${pair##*:}@test.invalid>" ed25519 sign,cert never >/dev/null 2>&1
    f="$(GNUPGHOME="${d}" gpg --list-keys --with-colons "${pair##*:}@test.invalid" | awk -F: '/^fpr/{print $10; exit}')"
    GNUPGHOME="${d}" gpg --batch --pinentry-mode loopback --passphrase '' --quick-add-key "${f}" cv25519 encr never >/dev/null 2>&1
    printf -v "F${pair%%:*}" '%s' "${f}"
  done
  GNUPGHOME="${T}/gB" gpg --export "${FB}" | GNUPGHOME="${T}/gA" gpg --import >/dev/null 2>&1
  GNUPGHOME="${T}/gA" gpg --export "${FA}" | GNUPGHOME="${T}/gB" gpg --import >/dev/null 2>&1
  for g in gA gB; do
    printf '%s:6:\n%s:6:\n' "${FA}" "${FB}" | GNUPGHOME="${T}/${g}" gpg --import-ownertrust >/dev/null 2>&1
  done
  export STORE="${T}/store"
  mkdir -p "${STORE}"
  echo "${FA}" >"${STORE}/.gpg-id"
  git -C "${STORE}" init -q
  cat >"${HOME}/.config/gopass/config" <<EOF
[mounts]
    path = ${STORE}
[core]
    autosync = false
    notifications = false
EOF
  export GNUPGHOME="${T}/gA"
  printf 'SHARED-MARKER' | gopass insert -f shared/token >/dev/null 2>&1
  printf 'PRIVATE-MARKER' | gopass insert -f private/token >/dev/null 2>&1
  printf 'qbert\t%s\nsrv\t%s\n' "${FA}" "${FB}" >"${T}/hosts.tsv"
  export SECAUTO_HOSTS="${T}/hosts.tsv" SECAUTO_STORE="${STORE}"
}

teardown() {
  [ -n "${T:-}" ] || return 0
  for g in gA gB; do gpgconf --homedir "${T}/${g}" --kill gpg-agent 2>/dev/null || true; done
  rm -rf "${T}"
}

reader_can_read() { # entry file under STORE
  GNUPGHOME="${T}/gB" gpg --batch --pinentry-mode loopback --passphrase '' -d "${STORE}/$1.gpg" >/dev/null 2>&1
}

@test "plan writes nothing and prints no value" {
  printf 'shared\tsrv\n' >"${T}/rows.tsv"
  SECAUTO_RECIPIENTS="${T}/rows.tsv" run bash "${HELPER}" plan
  [ "$status" -eq 0 ]
  [[ "${output}" == *"shared -> qbert,srv"* ]]
  [[ "${output}" != *"MARKER"* ]]
  [ ! -e "${STORE}/shared/.gpg-id" ]
}

@test "apply without --yes refuses" {
  printf 'shared\tsrv\n' >"${T}/rows.tsv"
  SECAUTO_RECIPIENTS="${T}/rows.tsv" run bash "${HELPER}" apply
  [ "$status" -eq 2 ]
}

@test "apply gives the reader access to the listed entry and not to the rest" {
  # Both entries start encrypted to the writer only; the reader reads neither.
  ! reader_can_read shared/token
  ! reader_can_read private/token
  # Only the `shared` directory is listed, so only it opens up to the reader.
  printf 'shared\tsrv\n' >"${T}/rows.tsv"
  SECAUTO_RECIPIENTS="${T}/rows.tsv" GNUPGHOME="${T}/gA" run bash "${HELPER}" apply --yes
  [ "$status" -eq 0 ]
  [[ "${output}" != *"MARKER"* ]]
  reader_can_read shared/token
  ! reader_can_read private/token
  # The writer still reads both, with the original values.
  [ "$(GNUPGHOME="${T}/gA" gopass show -o shared/token)" = "SHARED-MARKER" ]
  [ "$(GNUPGHOME="${T}/gA" gopass show -o private/token)" = "PRIVATE-MARKER" ]
}

@test "a host with no fingerprint fails the row and changes nothing" {
  printf 'shared\tmac\n' >"${T}/rows.tsv"
  SECAUTO_RECIPIENTS="${T}/rows.tsv" GNUPGHOME="${T}/gA" run bash "${HELPER}" apply --yes
  [ "$status" -ne 0 ]
  [[ "${output}" == *"no fingerprint for host 'mac'"* ]]
  [ ! -e "${STORE}/shared/.gpg-id" ]
}

@test "a directory path that escapes the store is refused" {
  printf '../outside\tsrv\n' >"${T}/rows.tsv"
  SECAUTO_RECIPIENTS="${T}/rows.tsv" run bash "${HELPER}" plan
  [ "$status" -ne 0 ]
  [[ "${output}" == *"relative directory inside the store"* ]]
}
