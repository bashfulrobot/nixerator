#!/usr/bin/env bats
# Tests for render-secrets --from gopass (gopass_inject). A stub `gopass` serves
# entries from a temp directory, so no real store, GPG key or 1Password is used.
# Every value here is a made-up marker. The tests assert that markers land in
# the output file and never appear on stderr.

load helper

setup() {
  setup_home
  STUBS="${THOME}/stubs"
  ENTRIES="${THOME}/entries"
  mkdir -p "${STUBS}" "${ENTRIES}"
  # gopass show -f ENTRY  ->  contents of $ENTRIES/<entry with / as __>
  cat >"${STUBS}/gopass" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "show" && "$2" == "-f" ]] || exit 2
e="${*: -1}"; f="${GOPASS_STUB_DIR}/${e//\//__}"
[[ -f "$f" ]] || exit 11
cat "$f"
EOF
  chmod +x "${STUBS}/gopass"
  export GOPASS_STUB_DIR="${ENTRIES}"
  export PATH="${STUBS}:${PATH}"
  MAP="${THOME}/map.tsv"
  TPLF="${THOME}/tpl.json"
}
teardown() { rm_home; }

put() { printf '%s' "$2" >"${ENTRIES}/${1//\//__}"; }

inject() {
  GOPASS_MAP="${MAP}" HOME="${THOME}" RENDER_SECRETS_SOURCE_ONLY=1 bash -c '
    source "'"${SCRIPT}"'"
    gopass_inject "$1" "$2"
  ' _ "${TPLF}" "${THOME}/out.json" 2>"${THOME}/err.txt"
}

@test "fills nested keys and a reference used twice" {
  printf 'a/cred\top://v/a/credential\nb/user\top://v/b/user\n' >"${MAP}"
  cat >"${TPLF}" <<'EOF'
{"aha":{"apiToken":"{{ op://v/a/credential }}"},"aha_token":"{{ op://v/a/credential }}","svc":{"user":"{{ op://v/b/user }}"}}
EOF
  put a/cred MARKER-A
  put b/user MARKER-B
  run inject
  [ "$status" -eq 0 ]
  [ "$(jq -r '.aha.apiToken' "${THOME}/out.json")" = "MARKER-A" ]
  [ "$(jq -r '.aha_token' "${THOME}/out.json")" = "MARKER-A" ]
  [ "$(jq -r '.svc.user' "${THOME}/out.json")" = "MARKER-B" ]
}

@test "quotes, backslashes, newlines and unicode survive as valid JSON" {
  printf 'k/v\top://v/k/v\n' >"${MAP}"
  echo '{"k":"{{ op://v/k/v }}"}' >"${TPLF}"
  put k/v $'line "one"\\two\nthree é'
  run inject
  [ "$status" -eq 0 ]
  [ "$(jq -r '.k' "${THOME}/out.json")" = $'line "one"\\two\nthree é' ]
}

@test "a reference missing from the map is left out and named on stderr" {
  printf 'a/cred\top://v/a/credential\n' >"${MAP}"
  echo '{"keep":"{{ op://v/a/credential }}","sa":{"token":"{{ op://v/sa/credential }}"}}' >"${TPLF}"
  put a/cred MARKER-A
  run inject
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("keep")' "${THOME}/out.json")" = "true" ]
  [ "$(jq -r 'has("sa")' "${THOME}/out.json")" = "false" ]
  grep -q 'op://v/sa/credential (not in map)' "${THOME}/err.txt"
}

@test "a missing or empty entry is left out and its parent object pruned" {
  printf 'm/gone\top://v/m/gone\nm/empty\top://v/m/empty\nok/one\top://v/ok/one\n' >"${MAP}"
  echo '{"g":{"x":"{{ op://v/m/gone }}","y":"{{ op://v/m/empty }}"},"ok":"{{ op://v/ok/one }}"}' >"${TPLF}"
  put m/empty ''
  put ok/one MARKER-OK
  run inject
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("g")' "${THOME}/out.json")" = "false" ]
  [ "$(jq -r '.ok' "${THOME}/out.json")" = "MARKER-OK" ]
  grep -q 'm/gone (missing or empty)' "${THOME}/err.txt"
  grep -q 'm/empty (missing or empty)' "${THOME}/err.txt"
}

@test "values never appear on stderr" {
  printf 'a/cred\top://v/a/credential\nz/miss\top://v/z/miss\n' >"${MAP}"
  echo '{"a":"{{ op://v/a/credential }}","z":"{{ op://v/z/miss }}","u":"{{ op://v/unmapped/x }}"}' >"${TPLF}"
  put a/cred SECRET-MARKER-DO-NOT-LEAK
  run inject
  [ "$status" -eq 0 ]
  ! grep -q 'SECRET-MARKER-DO-NOT-LEAK' "${THOME}/err.txt"
}

@test "no temp files are left behind next to the output" {
  printf 'a/cred\top://v/a/credential\n' >"${MAP}"
  echo '{"a":"{{ op://v/a/credential }}"}' >"${TPLF}"
  put a/cred MARKER-A
  run inject
  [ "$status" -eq 0 ]
  [ -z "$(find "${THOME}" -maxdepth 1 -name '.gopass-vals.*')" ]
}

@test "the shipped map covers every reference in the repo template except the service-account token" {
  repo="$(cd "${TESTS_DIR}/../../../../.." && pwd)"
  tpl="$(ls "${repo}"/secrets.*.tpl | head -1)"
  shipped="${repo}/modules/apps/cli/render-secrets/gopass-map.tsv"
  missing="$(comm -23 <(grep -o 'op://[^ }"]*' "${tpl}" | sort -u) <(awk -F'\t' '!/^#/ && NF>=2 {print $2}' "${shipped}" | sort -u))"
  [ "${missing}" = "op://nixerator/zm7ky22lk75tfi4absvvfewd3q/credential" ]
}
