#!/usr/bin/env bats
# Tests for extras/helpers/import-op-to-gopass.sh --check and --update. Stub `op`
# and `gopass` serve made-up marker values. The tests pin that drift is found by
# digest, that --update overwrites only a differing entry, that --check writes
# nothing, and that no value reaches stdout.

load helper

HELPER="$(cd "${BATS_TEST_DIRNAME}/../../../../../extras/helpers" && pwd)/import-op-to-gopass.sh"

setup() {
  setup_home
  STUBS="${THOME}/stubs"
  STORE="${THOME}/store"
  mkdir -p "${STUBS}" "${STORE}" "${THOME}/op"
  cat >"${STUBS}/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  read) cat "${OP_STUB_DIR}/read.${2//\//_}" 2>/dev/null || exit 1 ;;
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
  export PATH="${STUBS}:${PATH}"
  export XDG_STATE_HOME="${THOME}/state"
  printf 'aha/credential\top://nixerator/aha/credential\nwave/credential\top://nixerator/wave/credential\trequired\n' >"${THOME}/map.tsv"
  export GOPASS_MAP="${THOME}/map.tsv"
  printf 'NEW-AHA' >"${OP_STUB_DIR}/read.op:__nixerator_aha_credential"
  printf 'NEW-WAVE' >"${OP_STUB_DIR}/read.op:__nixerator_wave_credential"
}
teardown() { rm_home; }

run_helper() { HOME="${THOME}" run bash "${HELPER}" "$@"; }

@test "--check passes and records a stamp when every entry matches" {
  printf 'NEW-AHA' >"${STORE}/aha__credential"
  printf 'NEW-WAVE' >"${STORE}/wave__credential"
  run_helper --check
  [ "$status" -eq 0 ]
  [[ "${output}" == *"drift=0"* ]]
  [ -f "${XDG_STATE_HOME}/nixerator/snapshot-verified" ]
}

@test "--check names a differing entry, exits non-zero, writes nothing and prints no value" {
  printf 'OLD-AHA' >"${STORE}/aha__credential"
  printf 'NEW-WAVE' >"${STORE}/wave__credential"
  run_helper --check
  [ "$status" -ne 0 ]
  [[ "${output}" == *"drift aha/credential"* ]]
  [[ "${output}" != *"OLD-AHA"* && "${output}" != *"NEW-AHA"* ]]
  [ "$(cat "${STORE}/aha__credential")" = "OLD-AHA" ]
  [ ! -e "${XDG_STATE_HOME}/nixerator/snapshot-verified" ]
}

@test "--check reports a missing entry as drift" {
  printf 'NEW-WAVE' >"${STORE}/wave__credential"
  run_helper --check
  [ "$status" -ne 0 ]
  [[ "${output}" == *"drift aha/credential"* ]]
}

@test "--update overwrites only the differing entry" {
  printf 'OLD-AHA' >"${STORE}/aha__credential"
  printf 'NEW-WAVE' >"${STORE}/wave__credential"
  run_helper --update
  [ "$status" -eq 0 ]
  [[ "${output}" == *"updated aha/credential"* ]]
  [[ "${output}" == *"same  wave/credential"* ]]
  [ "$(cat "${STORE}/aha__credential")" = "NEW-AHA" ]
  [[ "${output}" != *"NEW-AHA"* && "${output}" != *"OLD-AHA"* ]]
}

@test "--update --dry-run writes nothing" {
  printf 'OLD-AHA' >"${STORE}/aha__credential"
  printf 'NEW-WAVE' >"${STORE}/wave__credential"
  run_helper --update --dry-run
  [ "$status" -eq 0 ]
  [[ "${output}" == *"would update aha/credential"* ]]
  [ "$(cat "${STORE}/aha__credential")" = "OLD-AHA" ]
}

@test "an empty 1Password read is a failure, never a write" {
  : >"${OP_STUB_DIR}/read.op:__nixerator_aha_credential"
  printf 'OLD-AHA' >"${STORE}/aha__credential"
  printf 'NEW-WAVE' >"${STORE}/wave__credential"
  run_helper --update
  [ "$status" -ne 0 ]
  [ "$(cat "${STORE}/aha__credential")" = "OLD-AHA" ]
}
