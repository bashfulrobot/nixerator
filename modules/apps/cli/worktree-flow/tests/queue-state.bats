#!/usr/bin/env bats
# Tests for `github-issue queue-state` (#260): reboot-safe persistence of the
# github-issues-auto batch cursor.
#
# The command reads and writes a single .queue-state.json in the shared worktree
# base (outside any one worktree, so it outlives a finished issue's cleanup),
# atomically and under a per-host flock. The skill owns the JSON shape; these
# tests pin the durability contract: absent reads as not-present, a set/get
# round-trips the payload, writes are stamped and validated, corrupt state is
# surfaced not swallowed, and clear removes the file.
load helper

setup() { setup_fixture; }
teardown() { rm_fixture; }

@test "get reports exists:false when no queue state is on disk" {
  run qstate get
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.exists')" = "false" ]
  [ "$(echo "$output" | jq -r '.state')" = "null" ]
}

@test "set then get round-trips the payload" {
  run qstate set --json '{"queue":[260,263,261],"cursor":1,"chain":["feat/262-x"],"decisions":{}}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.ok')" = "true" ]

  run qstate get
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.exists')" = "true" ]
  [ "$(echo "$output" | jq -r '.state.cursor')" = "1" ]
  [ "$(echo "$output" | jq -c '.state.queue')" = "[260,263,261]" ]
  [ "$(echo "$output" | jq -c '.state.chain')" = '["feat/262-x"]' ]
}

@test "set stamps a version and a write timestamp" {
  run qstate set --json '{"queue":[1],"cursor":0}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.state.queue_state_version')" = "1" ]
  # ISO-8601 UTC, e.g. 2026-07-22T04:05:06Z
  echo "$output" | jq -r '.state.written_at' | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

@test "set rejects a non-JSON payload" {
  run qstate set --json 'not json at all'
  [ "$status" -ne 0 ]
}

@test "set requires --json" {
  run qstate set
  [ "$status" -ne 0 ]
}

@test "clear removes the file so a later get is exists:false" {
  qstate set --json '{"queue":[1,2],"cursor":0}'
  run qstate clear
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.cleared')" = "true" ]

  run qstate get
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.exists')" = "false" ]
}

@test "clear on an already-absent file still succeeds" {
  run qstate clear
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.cleared')" = "true" ]
}

@test "get surfaces a corrupt state file instead of swallowing it" {
  local f
  f="$(queue_state_file)"
  mkdir -p "$(dirname "$f")"
  printf 'this is not json\n' >"$f"
  run qstate get
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_corrupt" ]
}

@test "the latest set wins on a second write" {
  qstate set --json '{"queue":[1,2,3],"cursor":0}'
  qstate set --json '{"queue":[1,2,3],"cursor":2}'
  run qstate get
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.state.cursor')" = "2" ]
}
