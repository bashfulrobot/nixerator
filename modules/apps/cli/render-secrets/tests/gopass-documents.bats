#!/usr/bin/env bats
# Documents that live in the secauto gopass store: the restore function in
# render-secrets.sh (gopass_materialize_one) and the --documents import in
# extras/helpers/import-op-to-gopass.sh. Stub `gopass` and `op` serve made-up
# marker bytes, so no real store, key, vault or secret is touched.

load helper

HELPER="$(cd "${BATS_TEST_DIRNAME}/../../../../../extras/helpers" && pwd)/import-op-to-gopass.sh"
SHIPPED="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)/gopass-documents.psv"

setup() {
  setup_home
  STUBS="${THOME}/stubs"
  STORE="${THOME}/store"
  mkdir -p "${STUBS}" "${STORE}" "${THOME}/op"
  cat >"${STUBS}/gopass" <<'EOF'
#!/usr/bin/env bash
# show -f ENTRY | show -o ENTRY | insert -f ENTRY | sync
e="${*: -1}"; f="${GOPASS_STUB_STORE}/${e//\//__}"
case "$1 $2" in
  "show -f") [[ -s "$f" ]] && cat "$f" || exit 11 ;;
  "show -o") [[ -s "$f" ]] && head -n1 "$f" || exit 11 ;;
  "insert -f") cat >"$f" ;;
  sync*) exit 0 ;;
  *) exit 2 ;;
esac
EOF
  cat >"${STUBS}/op" <<'EOF'
#!/usr/bin/env bash
# op document get TITLE --vault nixerator
[[ "$1 $2" == "document get" ]] || exit 2
cat "${OP_STUB_DIR}/doc.$3" 2>/dev/null || exit 1
EOF
  chmod +x "${STUBS}/gopass" "${STUBS}/op"
  export GOPASS_STUB_STORE="${STORE}" OP_STUB_DIR="${THOME}/op"
  export PATH="${STUBS}:${PATH}"
}
teardown() { rm_home; }

put() { printf '%s' "$2" >"${STORE}/${1//\//__}"; }

# restore ENTRY DEST ENC FMODE DMODE GUARD — call gopass_materialize_one in a fresh shell
restore() {
  HOME="${THOME}" RENDER_SECRETS_HOSTNAME="${HOSTNAME_T:-qbert}" RENDER_SECRETS_SOURCE_ONLY=1 bash -c '
    source "'"${SCRIPT}"'"
    gopass_materialize_one "$@"
  ' _ "$@"
}

@test "restores a text entry with the declared file and directory modes" {
  put documents/crt $'-----BEGIN CERTIFICATE-----\nMARKER\n-----END CERTIFICATE-----\n'
  run restore documents/crt "${THOME}/d/client.crt" text 644 700 ""
  [ "$status" -eq 0 ]
  [ "$(stat -c %a "${THOME}/d/client.crt")" = "644" ]
  [ "$(stat -c %a "${THOME}/d")" = "700" ]
  grep -q MARKER "${THOME}/d/client.crt"
}

@test "restores a base64 entry byte for byte, trailing newline included" {
  printf -- '-----BEGIN KEY-----\nMARKER-KEY\n-----END KEY-----\n' >"${THOME}/orig"
  put documents/key "$(base64 <"${THOME}/orig" | tr -d '\n')"
  run restore documents/key "${THOME}/d/key" b64 600 700 ""
  [ "$status" -eq 0 ]
  cmp -s "${THOME}/orig" "${THOME}/d/key"
  [ "$(stat -c %a "${THOME}/d/key")" = "600" ]
}

@test "never clobbers an existing destination, and still fixes its mode" {
  mkdir -p "${THOME}/d"
  printf 'KEEP-ME' >"${THOME}/d/key"
  chmod 644 "${THOME}/d/key"
  put documents/key "$(printf 'NEW' | base64)"
  run restore documents/key "${THOME}/d/key" b64 600 700 ""
  [ "$status" -eq 0 ]
  [ "$(cat "${THOME}/d/key")" = "KEEP-ME" ]
  [ "$(stat -c %a "${THOME}/d/key")" = "600" ]
}

@test "a failing guard skips the file entirely" {
  put documents/crt 'MARKER'
  HOSTNAME_T=somewhere-else run restore documents/crt "${THOME}/d/client.crt" text 644 700 "host:qbert,srv"
  [ "$status" -eq 0 ]
  [ ! -e "${THOME}/d/client.crt" ]
}

@test "a passing host guard restores the file" {
  put documents/crt 'MARKER'
  HOSTNAME_T=srv run restore documents/crt "${THOME}/d/client.crt" text 644 700 "host:qbert,srv"
  [ "$status" -eq 0 ]
  [ -s "${THOME}/d/client.crt" ]
}

@test "a missing entry returns 3 and leaves nothing behind" {
  run restore documents/absent "${THOME}/d/x" text 644 700 ""
  [ "$status" -eq 3 ]
  [ ! -e "${THOME}/d/x" ]
  [ -z "$(find "${THOME}/d" -name '.materialize.*' 2>/dev/null)" ]
}

@test "an empty entry returns 3 and writes nothing" {
  put documents/empty ''
  run restore documents/empty "${THOME}/d/x" b64 600 700 ""
  [ "$status" -eq 3 ]
  [ ! -e "${THOME}/d/x" ]
}

@test "an unknown encoding is refused" {
  put documents/crt 'MARKER'
  run restore documents/crt "${THOME}/d/x" rot13 644 700 ""
  [ "$status" -eq 1 ]
  [ ! -e "${THOME}/d/x" ]
}

@test "~/ in a destination expands to the home directory" {
  put documents/crt 'MARKER'
  run restore documents/crt '~/.config/incus/client.crt' text 644 700 ""
  [ "$status" -eq 0 ]
  [ -s "${THOME}/.config/incus/client.crt" ]
}

# --- import ------------------------------------------------------------------

make_table() {
  cat >"${THOME}/docs.psv" <<'EOF'
# title|entry|enc|dest|fmode|dmode|guard
k.key|documents/k.key|b64|~/.ssh/k.key|600|700|
c.crt|documents/c.crt|text|~/.config/c.crt|644|700|
EOF
  export GOPASS_DOCS="${THOME}/docs.psv"
}

run_import() { HOME="${THOME}" run bash "${HELPER}" --documents "$@"; }

@test "import stores base64 of the exact bytes and text as text" {
  make_table
  printf -- 'LINE1\nMARKER-KEY\n' >"${THOME}/op/doc.k.key"
  printf 'CERT-MARKER\n' >"${THOME}/op/doc.c.crt"
  run_import
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok    documents/k.key"* ]]
  [[ "$output" == *"ok    documents/c.crt"* ]]
  base64 -d <"${STORE}/documents__k.key" | cmp -s - "${THOME}/op/doc.k.key"
  [ "$(cat "${STORE}/documents__c.crt")" = "CERT-MARKER" ]
}

@test "import refuses an empty read and stores nothing" {
  make_table
  : >"${THOME}/op/doc.k.key"
  run_import
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  documents/k.key"* ]]
  [ ! -e "${STORE}/documents__k.key" ]
}

@test "import refuses a document op cannot read" {
  make_table
  run_import
  [[ "$output" == *"FAIL  documents/c.crt"* ]]
  [ ! -e "${STORE}/documents__c.crt" ]
}

@test "import skips a present entry and a second run changes nothing" {
  make_table
  printf 'A\n' >"${THOME}/op/doc.k.key"
  printf 'B\n' >"${THOME}/op/doc.c.crt"
  run_import
  before="$(cat "${STORE}"/* | md5sum)"
  run_import
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip  documents/k.key (present, non-empty)"* ]]
  [ "$(cat "${STORE}"/* | md5sum)" = "${before}" ]
}

@test "import dry run lists names and writes nothing" {
  make_table
  printf 'A\n' >"${THOME}/op/doc.k.key"
  run_import --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would documents/k.key"* ]]
  [ -z "$(ls -A "${STORE}")" ]
}

@test "import never prints contents" {
  make_table
  printf 'SECRET-MARKER-ONE\n' >"${THOME}/op/doc.k.key"
  printf 'SECRET-MARKER-TWO\n' >"${THOME}/op/doc.c.crt"
  run_import
  [[ "$output" != *"SECRET-MARKER-ONE"* ]]
  [[ "$output" != *"SECRET-MARKER-TWO"* ]]
  [[ "$output" != *"$(printf 'SECRET-MARKER-ONE\n' | base64 | tr -d '\n')"* ]]
}

# --- the shipped table -----------------------------------------------------------

@test "every shipped row has seven fields and a valid encoding" {
  bad=0
  while IFS= read -r line; do
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    n="$(awk -F'|' '{print NF}' <<<"${line}")"
    enc="$(awk -F'|' '{print $3}' <<<"${line}")"
    [[ "${n}" == 7 && ( "${enc}" == b64 || "${enc}" == text ) ]] || bad=$((bad + 1))
  done <"${SHIPPED}"
  [ "${bad}" -eq 0 ]
}

@test "the shipped table leaves out the identity-class files" {
  ! grep -v '^#' "${SHIPPED}" | grep -E 'id_ed25519|id_rsa|git-crypt|\.pfx|okular'
}

@test "a symlink at the destination is refused and its target keeps its mode" {
  mkdir -p "${THOME}/d"
  printf 'TARGET' >"${THOME}/victim"
  chmod 644 "${THOME}/victim"
  ln -s "${THOME}/victim" "${THOME}/d/key"
  put documents/key "$(printf 'NEW' | base64)"
  run restore documents/key "${THOME}/d/key" b64 600 700 ""
  [ "$status" -eq 1 ]
  [ "$(stat -c %a "${THOME}/victim")" = "644" ]
  [ "$(cat "${THOME}/victim")" = "TARGET" ]
}

@test "the import helper never yields a dot component for a slug" {
  run bash -c 'source <(sed -n "/^slug()/,/^}/p" "'"${HELPER}"'"); slug ..; slug .; slug "My Item"'
  [ "${lines[0]}" = "x" ]
  [ "${lines[1]}" = "x" ]
  [ "${lines[2]}" = "my-item" ]
}
