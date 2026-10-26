#!/usr/bin/env bats
# Tests for extras/helpers/import-op-to-gopass.sh --mirror. Stub `op` and `gopass`
# serve and record made-up marker values, so no vault, store or GPG key is used.
# The tests pin the naming rule, what is skipped on purpose, and that no value
# reaches stdout.

load helper

HELPER="$(cd "${BATS_TEST_DIRNAME}/../../../../../extras/helpers" && pwd)/import-op-to-gopass.sh"

setup() {
  setup_home
  STUBS="${THOME}/stubs"
  STORE="${THOME}/store"
  mkdir -p "${STUBS}" "${STORE}"
  cat >"${STUBS}/op" <<'EOF'
#!/usr/bin/env bash
# op item list --vault V --format=json | op item get ID --vault V --format=json | op read REF
case "$1 $2" in
  "item list")
    cat "${OP_STUB_DIR}/list.$4" ;;
  "item get")
    cat "${OP_STUB_DIR}/item.$3" ;;
  "read "*) cat "${OP_STUB_DIR}/read.${2//\//_}" 2>/dev/null || exit 1 ;;
  *) exit 2 ;;
esac
EOF
  cat >"${STUBS}/gopass" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  show) e="${*: -1}"; f="${GOPASS_STUB_STORE}/${e//\//__}"; [[ -s "$f" ]] && head -n1 "$f" || exit 11 ;;
  insert) e="${*: -1}"; cat >"${GOPASS_STUB_STORE}/${e//\//__}" ;;
  sync) exit 0 ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "${STUBS}/op" "${STUBS}/gopass"
  export OP_STUB_DIR="${THOME}/op" GOPASS_STUB_STORE="${STORE}"
  mkdir -p "${OP_STUB_DIR}"
  export PATH="${STUBS}:${PATH}"

  printf 'aha/credential\top://nixerator/aha/credential\n' >"${THOME}/map.tsv"
  export GOPASS_MAP="${THOME}/map.tsv"
  printf 'MAPPED-MARKER' >"${OP_STUB_DIR}/read.op:__nixerator_aha_credential"

  echo '[
    {"id":"pu1","title":"Pushover-api","category":"PASSWORD"},
    {"id":"aaaaaa111","title":"FLUX-PAT-INFRA","category":"API_CREDENTIAL"},
    {"id":"bbbbbb222","title":"FLUX-PAT-INFRA","category":"PASSWORD"},
    {"id":"ssh1","title":"ssh_key_id_ed25519","category":"SSH_KEY"},
    {"id":"sa1","title":"Service Account Auth Token: opcli","category":"API_CREDENTIAL"}
  ]' >"${OP_STUB_DIR}/list.automation"
  echo '{"fields":[{"id":"u","label":"user-key","value":"UK-MARKER"},{"id":"t","label":"api-token","value":"AT-MARKER"},{"id":"notesPlain","label":"notesPlain","value":"NOTE-MARKER"},{"id":"e","label":"empty","value":""}]}' >"${OP_STUB_DIR}/item.pu1"
  echo '{"fields":[{"id":"c","label":"credential","value":"FLUX-A-MARKER"}]}' >"${OP_STUB_DIR}/item.aaaaaa111"
  echo '{"fields":[{"id":"p","label":"password","value":"FLUX-B-MARKER"}]}' >"${OP_STUB_DIR}/item.bbbbbb222"
  echo '[
    {"id":"ah1","title":"aha","category":"API_CREDENTIAL"},
    {"id":"fa1","title":"feral-arr","category":"DOCUMENT"},
    {"id":"cx1","title":"context7","category":"API_CREDENTIAL"}
  ]' >"${OP_STUB_DIR}/list.nixerator"
  echo '{"fields":[{"id":"c","label":"credential","value":"AHA-MARKER"}]}' >"${OP_STUB_DIR}/item.ah1"
  echo '{"fields":[{"id":"c","label":"credential","value":"CTX-MARKER"}]}' >"${OP_STUB_DIR}/item.cx1"
}
teardown() { rm_home; }

run_helper() { HOME="${THOME}" run bash "${HELPER}" "$@"; }
entry() { printf '%s' "${STORE}/${1//\//__}"; }

@test "mirror writes credential fields under vault/item/field" {
  run_helper --mirror
  [ "$status" -eq 0 ]
  [ "$(cat "$(entry automation/pushover-api/user-key)")" = "UK-MARKER" ]
  [ "$(cat "$(entry automation/pushover-api/api-token)")" = "AT-MARKER" ]
  [ "$(cat "$(entry nixerator/context7/credential)")" = "CTX-MARKER" ]
}

@test "notes fields and empty fields are not copied" {
  run_helper --mirror
  [ ! -e "$(entry automation/pushover-api/notesplain)" ]
  [ ! -e "$(entry automation/pushover-api/empty)" ]
}

@test "documents, ssh keys and service-account tokens are skipped" {
  run_helper --mirror
  [[ "$output" == *"skip  nixerator/feral-arr [DOCUMENT]"* ]]
  [[ "$output" == *"skip  automation/ssh_key_id_ed25519 [SSH_KEY]"* ]]
  [[ "$output" == *"skip  automation/Service Account Auth Token: opcli (service-account token)"* ]]
  [ -z "$(ls "${STORE}" | grep -i -E 'feral|ssh_key|service')" ]
}

@test "a field the map covers is not mirrored under a second name" {
  run_helper --mirror
  [[ "$output" == *"skip  nixerator/aha/credential (covered by the map)"* ]]
  [ ! -e "$(entry nixerator/aha/credential)" ]
  [ "$(cat "$(entry aha/credential)")" = "MAPPED-MARKER" ]
}

@test "two items with the same title get distinct names" {
  run_helper --mirror
  [ "$(cat "$(entry automation/flux-pat-infra-aaaaaa/credential)")" = "FLUX-A-MARKER" ]
  [ "$(cat "$(entry automation/flux-pat-infra-bbbbbb/password)")" = "FLUX-B-MARKER" ]
}

@test "no value ever appears in the output" {
  run_helper --mirror
  for m in UK-MARKER AT-MARKER NOTE-MARKER FLUX-A-MARKER FLUX-B-MARKER AHA-MARKER CTX-MARKER MAPPED-MARKER; do
    [[ "$output" != *"$m"* ]]
  done
}

@test "dry run lists names and writes nothing" {
  run_helper --mirror --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would automation/pushover-api/user-key"* ]]
  [[ "$output" == *"dry run: would_write="* ]]
  [ -z "$(ls -A "${STORE}")" ]
}

@test "a second run skips entries that are present" {
  run_helper --mirror
  run_helper --mirror
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip  automation/pushover-api/user-key (present, non-empty)"* ]]
  [[ "$output" == *"imported=0"* ]]
}
