#!/usr/bin/env bats
# Tests for the gopass-default render: required map rows fail closed, the default
# source is gopass, and identity-file modes are re-asserted without op. A stub
# `gopass` serves made-up marker values, so no store, GPG key or 1Password is used.

load helper

setup() {
  setup_home
  STUBS="${THOME}/stubs"
  ENTRIES="${THOME}/entries"
  mkdir -p "${STUBS}" "${ENTRIES}"
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
  GOPASS_MAP="${MAP}" HOME="${THOME}" RENDER_SECRETS_SOURCE_ONLY=1 "$@" bash -c '
    source "'"${SCRIPT}"'"
    gopass_inject "$1" "$2"
  ' _ "${TPLF}" "${THOME}/out.json" 2>"${THOME}/err.txt"
}

@test "a missing required entry fails the render and writes no output" {
  printf 'g/user\top://v/g/user\trequired\ng/pass\top://v/g/pass\trequired\n' >"${MAP}"
  echo '{"gui":{"user":"{{ op://v/g/user }}","password":"{{ op://v/g/pass }}"}}' >"${TPLF}"
  put g/user MARKER-U
  run inject env
  [ "$status" -ne 0 ]
  [ ! -e "${THOME}/out.json" ]
  grep -q 'required gopass entries are missing' "${THOME}/err.txt"
  grep -q 'g/pass' "${THOME}/err.txt"
  ! grep -q 'MARKER-U' "${THOME}/err.txt"
}

@test "required entries that are present render normally" {
  printf 'g/user\top://v/g/user\trequired\n' >"${MAP}"
  echo '{"gui":{"user":"{{ op://v/g/user }}"}}' >"${TPLF}"
  put g/user MARKER-U
  run inject env
  [ "$status" -eq 0 ]
  [ "$(jq -r '.gui.user' "${THOME}/out.json")" = "MARKER-U" ]
}

@test "RENDER_SECRETS_ALLOW_MISSING=1 lets a bootstrap render without required entries" {
  printf 'g/user\top://v/g/user\trequired\n' >"${MAP}"
  echo '{"gui":{"user":"{{ op://v/g/user }}"},"keep":1}' >"${TPLF}"
  run inject env RENDER_SECRETS_ALLOW_MISSING=1
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("gui")' "${THOME}/out.json")" = "false" ]
  [ "$(jq -r '.keep' "${THOME}/out.json")" = "1" ]
}

@test "an optional entry that is missing is still just left out" {
  printf 'a/cred\top://v/a/cred\n' >"${MAP}"
  echo '{"a":"{{ op://v/a/cred }}"}' >"${TPLF}"
  run inject env
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("a")' "${THOME}/out.json")" = "false" ]
}

@test "the default source is gopass" {
  grep -q 'RENDER_SECRETS_FROM:-gopass' "${SCRIPT}"
}

@test "a gopass-mode render re-asserts identity-file modes without op" {
  # Run a copy of the script with the build-time placeholders filled in.
  RUN="${THOME}/render-secrets"
  : >"${THOME}/docs.psv"
  : >"${THOME}/map.empty"
  echo '{}' >"${THOME}/tpl.empty"
  sed -e "s|@DEST@|${THOME}/.config/nixos-secrets/secrets.json|" \
    -e "s|@TPL@|${THOME}/tpl.empty|" \
    -e "s|@MAP@|${THOME}/map.empty|" \
    -e "s|@DOCS@|${THOME}/docs.psv|" "${SCRIPT}" >"${RUN}"
  mkdir -p "${THOME}/git/homelab" "${THOME}/.config/git-crypt"
  printf 'x' >"${THOME}/.config/git-crypt/homelab.key"
  chmod 644 "${THOME}/.config/git-crypt/homelab.key"
  # op is deliberately absent from PATH; the render must not need it.
  run env -i HOME="${THOME}" PATH="${STUBS}:$(dirname "$(command -v bash)"):$(dirname "$(command -v jq)"):$(dirname "$(command -v awk)"):$(dirname "$(command -v grep)"):$(dirname "$(command -v mktemp)")" \
    bash "${RUN}"
  [ "$status" -eq 0 ]
  [ "$(stat -c '%a' "${THOME}/.config/git-crypt/homelab.key")" = "600" ]
}

@test "a symlinked identity file is refused, not chmod'ed" {
  RUN="${THOME}/render-secrets"
  : >"${THOME}/docs.psv"
  : >"${THOME}/map.empty"
  echo '{}' >"${THOME}/tpl.empty"
  sed -e "s|@DEST@|${THOME}/.config/nixos-secrets/secrets.json|" \
    -e "s|@TPL@|${THOME}/tpl.empty|" \
    -e "s|@MAP@|${THOME}/map.empty|" \
    -e "s|@DOCS@|${THOME}/docs.psv|" "${SCRIPT}" >"${RUN}"
  mkdir -p "${THOME}/git/homelab" "${THOME}/.config/git-crypt"
  printf 'x' >"${THOME}/target"
  chmod 644 "${THOME}/target"
  ln -s "${THOME}/target" "${THOME}/.config/git-crypt/homelab.key"
  run env -i HOME="${THOME}" PATH="${STUBS}:$(dirname "$(command -v bash)"):$(dirname "$(command -v jq)"):$(dirname "$(command -v awk)"):$(dirname "$(command -v grep)"):$(dirname "$(command -v mktemp)")" \
    bash "${RUN}"
  [ "$(stat -c '%a' "${THOME}/target")" = "644" ]
  [[ "${output}" == *"is a symlink, refusing to chmod it"* ]]
}
