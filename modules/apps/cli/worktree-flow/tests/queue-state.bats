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

@test "set rejects a valid-JSON but non-object payload" {
  # An array clears a bare `jq -e .` gate, then the '. + {..}' stamp would abort
  # jq with a raw error and no JSON. The type guard must reject it structurally.
  run qstate set --json '[1,2,3]'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_not_object" ]
}

@test "set rejects a JSON null payload" {
  # `jq -e .` treats null as falsey and would misreport it as "not valid JSON".
  # The object guard rejects it with the correct cause instead.
  run qstate set --json 'null'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_not_object" ]
}

@test "queue-state outside a git work tree fails with a routable cause" {
  # ${FIX} itself is not a repo (it holds origin.git and work). worktree_base
  # would abort on git rev-parse; the up-front guard must surface not_in_repo.
  run qstate_at "${FIX}" get
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "not_in_repo" ]
}

@test "queue-state inside a bare repo is refused, not run against a nonsense path" {
  # In a bare repo `git rev-parse --is-inside-work-tree` exits 0 but prints
  # "false", so an exit-status-only guard would wave it through and let
  # worktree_base resolve to garbage. The output check must catch it.
  run qstate_at "${FIX}/origin.git" get
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "not_in_repo" ]
}

@test "set requires --json" {
  run qstate set
  [ "$status" -ne 0 ]
}

@test "set rejects a queue with a non-integer issue number" {
  run qstate set --json '{"queue":[1,"two",3],"cursor":0}'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_invalid" ]
}

@test "set rejects a cursor out of range for the queue" {
  run qstate set --json '{"queue":[1,2],"cursor":9}'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_invalid" ]
}

@test "set rejects a prev_branch with unsafe characters" {
  run qstate set --json '{"queue":[1],"cursor":0,"prev_branch":"feat/x; rm -rf /"}'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_invalid" ]
}

@test "set rejects a concatenated multi-document payload" {
  # Two objects in one argument. A bare `jq -e type=="object"` exits on the last
  # truthy document and would wave this through, then silently persist a corrupt
  # two-document file. The slurp gate must reject it up front.
  run qstate set --json '{"queue":[1],"cursor":0}{"queue":[2],"cursor":0}'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_not_object" ]
}

@test "get surfaces a concatenated multi-document state file as corrupt" {
  local f
  f="$(queue_state_file)"
  mkdir -p "$(dirname "$f")"
  printf '{"queue":[1],"cursor":0}\n{"queue":[2],"cursor":0}\n' >"$f"
  run qstate get
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_corrupt" ]
}

@test "set accepts cursor equal to queue length (all issues done)" {
  run qstate set --json '{"queue":[1,2,3],"cursor":3}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.ok')" = "true" ]
}

@test "set rejects a payload over the size cap" {
  # ~90 KiB: over the 64 KiB cap, but under the kernel's ~128 KiB single-arg
  # limit so the payload actually reaches the command rather than failing at exec.
  local pad
  pad="$(printf 'a%.0s' $(seq 1 90000))"
  run qstate set --json "{\"queue\":[1],\"cursor\":0,\"pad\":\"${pad}\"}"
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_too_large" ]
}

@test "set refuses when the state path is a symlink" {
  local f dir
  f="$(queue_state_file)"
  dir="$(dirname "$f")"
  mkdir -p "$dir"
  ln -s /tmp/some-target "$f"
  run qstate set --json '{"queue":[1],"cursor":0}'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_symlink" ]
}

@test "get surfaces a shape-invalid (hand-edited) state file" {
  local f
  f="$(queue_state_file)"
  mkdir -p "$(dirname "$f")"
  # Valid JSON, wrong shape (cursor is not an integer).
  printf '{"queue":[1,2],"cursor":"nope"}\n' >"$f"
  run qstate get
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "queue_state_invalid" ]
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
