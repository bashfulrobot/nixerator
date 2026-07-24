#!/usr/bin/env bats
# Tests for `github-issue findings`: the frozen review-finding ledger.
#
# The ledger exists so the review loop can terminate. Round 1 freezes the full
# adversarial finding set into the worktree state file; later rounds only look
# at the fix delta and append what that delta introduced. These tests pin the
# contract the review skills depend on: the freeze is one-shot, ids are unique,
# severities are validated per reviewer, a rejection must carry a reason, and
# the gating count only counts the severities that justify another round.
load helper

setup() { setup_fixture; }
teardown() { rm_fixture; }

DEV_CRIT='[{"id":"d1","source":"dev","severity":"critical","title":"nil deref","location":"a.sh:12"}]'
DEV_MINOR='[{"id":"d2","source":"dev","severity":"minor","title":"stale comment"}]'
SEC_LOW='[{"id":"s1","source":"security","severity":"low","title":"verbose error"}]'

@test "get on a fresh worktree reports an empty ledger at round 0" {
  seed_state 42 >/dev/null
  run findings 42 get
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.review_round')" = "0" ]
  [ "$(echo "$output" | jq -c '.findings')" = "[]" ]
  [ "$(echo "$output" | jq -r '.summary.total')" = "0" ]
  [ "$(echo "$output" | jq -r '.summary.gating_open')" = "0" ]
}

@test "set freezes the round-1 finding set and starts the round counter" {
  seed_state 42 >/dev/null
  run findings 42 set --json "$DEV_CRIT"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.added')" = "1" ]

  run findings 42 get
  [ "$(echo "$output" | jq -r '.review_round')" = "1" ]
  [ "$(echo "$output" | jq -r '.findings[0].id')" = "d1" ]
  [ "$(echo "$output" | jq -r '.findings[0].status')" = "open" ]
  [ "$(echo "$output" | jq -r '.findings[0].round')" = "1" ]
}

@test "set refuses to replace a ledger that already holds findings" {
  # Silently discarding a frozen set would drop unfixed findings from the gate,
  # which is the one failure mode the ledger exists to prevent.
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_CRIT" >/dev/null
  run findings 42 set --json "$DEV_MINOR"
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "ledger_not_empty" ]
}

@test "add appends delta-round findings stamped with the current round" {
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_CRIT" >/dev/null
  findings 42 round --bump --base-sha deadbeef >/dev/null
  run findings 42 add --json "$DEV_MINOR"
  [ "$status" -eq 0 ]

  run findings 42 get
  [ "$(echo "$output" | jq -r '.review_round')" = "2" ]
  [ "$(echo "$output" | jq -r '.review_base_sha')" = "deadbeef" ]
  [ "$(echo "$output" | jq -r '.findings[] | select(.id=="d2") | .round')" = "2" ]
}

@test "add rejects an id that is already in the ledger" {
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_CRIT" >/dev/null
  run findings 42 add --json "$DEV_CRIT"
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "invalid_finding" ]
}

@test "set rejects duplicate ids inside one batch" {
  seed_state 42 >/dev/null
  run findings 42 set --json '[{"id":"x","source":"dev","severity":"minor","title":"a"},{"id":"x","source":"dev","severity":"minor","title":"b"}]'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "invalid_finding" ]
}

@test "set rejects a severity that does not belong to the reviewer" {
  # "high" is a security tier; the dev reviewer speaks critical/important/minor.
  seed_state 42 >/dev/null
  run findings 42 set --json '[{"id":"x","source":"dev","severity":"high","title":"a"}]'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "invalid_finding" ]
}

@test "set rejects an unknown source" {
  seed_state 42 >/dev/null
  run findings 42 set --json '[{"id":"x","source":"perf","severity":"minor","title":"a"}]'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "invalid_finding" ]
}

@test "set rejects a finding with no id or no title" {
  seed_state 42 >/dev/null
  run findings 42 set --json '[{"source":"dev","severity":"minor","title":"a"}]'
  [ "$status" -ne 0 ]
  run findings 42 set --json '[{"id":"x","source":"dev","severity":"minor"}]'
  [ "$status" -ne 0 ]
}

@test "set rejects a payload that is not a JSON array" {
  seed_state 42 >/dev/null
  run findings 42 set --json '{"id":"x"}'
  [ "$status" -ne 0 ]
  run findings 42 set --json 'not json'
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "invalid_json" ]
}

@test "resolve marks findings fixed and drops them out of the open count" {
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_CRIT" >/dev/null
  run findings 42 resolve d1
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.summary.open')" = "0" ]
  [ "$(echo "$output" | jq -r '.summary.fixed')" = "1" ]
  [ "$(echo "$output" | jq -r '.summary.gating_open')" = "0" ]
}

@test "resolve refuses an unknown finding id" {
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_CRIT" >/dev/null
  run findings 42 resolve nope
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "unknown_finding" ]
}

@test "reject requires a reason and records it on the finding" {
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_CRIT" >/dev/null

  run findings 42 reject d1
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "missing_reason" ]

  run findings 42 reject d1 --reason "the guard upstream already covers this"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.summary.rejected')" = "1" ]

  run findings 42 get
  [ "$(echo "$output" | jq -r '.findings[0].note')" = "the guard upstream already covers this" ]
}

@test "gating_open counts only the severities that justify another round" {
  # critical/important (dev) and critical/high/medium (security) gate. A leftover
  # minor or low gets fixed like anything else, it just does not buy a new round.
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_MINOR" >/dev/null
  findings 42 add --json "$SEC_LOW" >/dev/null
  run findings 42 get
  [ "$(echo "$output" | jq -r '.summary.open')" = "2" ]
  [ "$(echo "$output" | jq -r '.summary.gating_open')" = "0" ]

  findings 42 add --json '[{"id":"s2","source":"security","severity":"medium","title":"open redirect"}]' >/dev/null
  run findings 42 get
  [ "$(echo "$output" | jq -r '.summary.gating_open')" = "1" ]
}

@test "get --pending returns only open findings" {
  seed_state 42 >/dev/null
  findings 42 set --json "$DEV_CRIT" >/dev/null
  findings 42 add --json "$DEV_MINOR" >/dev/null
  findings 42 resolve d1 >/dev/null
  run findings 42 get --pending
  [ "$(echo "$output" | jq -r '.findings | length')" = "1" ]
  [ "$(echo "$output" | jq -r '.findings[0].id')" = "d2" ]
  # The summary still reports the whole ledger, not just the filtered view.
  [ "$(echo "$output" | jq -r '.summary.total')" = "2" ]
}

@test "round --base-sha alone pins the delta base without bumping" {
  seed_state 42 >/dev/null
  run findings 42 round --base-sha cafe1234
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.review_round')" = "0" ]
  [ "$(echo "$output" | jq -r '.review_base_sha')" = "cafe1234" ]
}

@test "round with no flags is an error" {
  seed_state 42 >/dev/null
  run findings 42 round
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "missing_arg" ]
}

@test "a v3 state file migrates forward and accepts findings" {
  # A worktree created before the ledger existed must not have to be recreated.
  seed_state 77 3 >/dev/null
  run findings 77 set --json "$DEV_CRIT"
  [ "$status" -eq 0 ]

  wt="$(fixture_worktree 77)"
  [ "$(jq -r '.version' "${wt}/.worktree-state.json")" = "4" ]
  [ "$(jq -r '.workflow_detail.findings[0].id' "${wt}/.worktree-state.json")" = "d1" ]
}

@test "an issue with no worktree is reported, not silently created" {
  run findings 999 get
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "no_worktree" ]
}

@test "a non-numeric issue number is rejected" {
  run findings abc get
  [ "$status" -ne 0 ]
  [ "$(echo "$output" | jq -r '.error.cause')" = "invalid_issue_number" ]
}

@test "an unknown action is rejected" {
  seed_state 42 >/dev/null
  run findings 42 frobnicate
  [ "$status" -ne 0 ]
}
