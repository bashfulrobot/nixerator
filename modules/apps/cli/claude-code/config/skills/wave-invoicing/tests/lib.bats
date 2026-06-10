#!/usr/bin/env bats
load helper

setup() { make_tmpdir; }
teardown() { rm_tmpdir; }

@test "cfg reads a top-level value from config.json" {
  run bash -c "source '${SCRIPTS}/lib.sh' '${SKILL_DIR}/config.json'; cfg '.issuer.code'"
  [ "$status" -eq 0 ]
  [ "$output" = "BrMfg" ]
}

@test "cfg reads a nested customer value" {
  run bash -c "source '${SCRIPTS}/lib.sh' '${SKILL_DIR}/config.json'; cfg '.customers.camino.name'"
  [ "$status" -eq 0 ]
  [ "$output" = "Camino Corp" ]
}

@test "cfg errors on a missing key" {
  run bash -c "source '${SCRIPTS}/lib.sh' '${SKILL_DIR}/config.json'; cfg '.nope.nope'"
  [ "$status" -ne 0 ]
}

@test "cfg errors on a non-scalar (object) value" {
  run bash -c "source '${SCRIPTS}/lib.sh' '${SKILL_DIR}/config.json'; cfg '.issuer'"
  [ "$status" -ne 0 ]
}

@test "wave_access_token returns WAVE_FULL_ACCESS_TOKEN when set" {
  run bash -c "export WAVE_FULL_ACCESS_TOKEN=tok123; source '${SCRIPTS}/lib.sh' '${SKILL_DIR}/config.json'; wave_access_token"
  [ "$status" -eq 0 ]
  [ "$output" = "tok123" ]
}

@test "wave_access_token errors when WAVE_FULL_ACCESS_TOKEN is unset" {
  run bash -c "unset WAVE_FULL_ACCESS_TOKEN; source '${SCRIPTS}/lib.sh' '${SKILL_DIR}/config.json'; wave_access_token"
  [ "$status" -ne 0 ]
}
