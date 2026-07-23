#!/usr/bin/env bats
# Regression tests for github-issue resume (#267): the pure routable cores of
# re-establishing a worktree on an existing branch. The gh-driven pieces
# (metadata fetch, lease takeover, PR discovery) are thin wrappers exercised in
# integration, not here, matching the setup-preflight suite's scope.
load helper

setup() { setup_fixture; }
teardown() { rm_fixture; }

@test "create_issue_state records a supplied pr_url and initial step" {
  WT="$(mktemp -d)"
  state_build "feat/267-x" "$WT" "267" "a title" "a body" "origin/main" "[]" \
    "https://github.com/o/r/pull/5" "implement" "Worktree resumed on existing branch feat/267-x."
  run jq -r '.pr_url' "$WT/.worktree-state.json"
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/o/r/pull/5" ]
  run jq -r '.workflow_step' "$WT/.worktree-state.json"
  [ "$output" = "implement" ]
  rm -rf "$WT"
}

@test "create_issue_state defaults leave pr_url empty and step assess (fresh setup)" {
  WT="$(mktemp -d)"
  state_build "feat/267-y" "$WT" "267" "a title" "a body" "origin/main"
  run jq -r '.pr_url' "$WT/.worktree-state.json"
  [ "$output" = "" ]
  run jq -r '.workflow_step' "$WT/.worktree-state.json"
  [ "$output" = "assess" ]
  rm -rf "$WT"
}

@test "resume_branch_decision routes existing branches to resume" {
  for s in local remote both; do
    run resume_fn resume_branch_decision "$s"
    [ "$status" -eq 0 ]
    [ "$output" = "resume" ]
  done
}

@test "resume_branch_decision routes none to absent" {
  run resume_fn resume_branch_decision none
  [ "$output" = "absent" ]
}

@test "resume_branch_decision routes unknown to unreachable" {
  run resume_fn resume_branch_decision unknown
  [ "$output" = "unreachable" ]
}

@test "count_ahead_of_origin is 0 when the branch is in sync with origin" {
  git -C "${FIX}/work" branch "feat/267-sync"
  git -C "${FIX}/work" push -q origin "feat/267-sync"
  git -C "${FIX}/work" fetch -q origin
  run ahead_in_fixture "feat/267-sync"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "count_ahead_of_origin counts local commits not on origin" {
  # Stay on the feat branch: count_ahead reads refs directly, so the two extra
  # commits land on refs/heads/feat/267-ahead while origin stays at the pushed
  # tip. No checkout-back is needed (and the fixture's default local branch name
  # is not guaranteed to be "main").
  git -C "${FIX}/work" checkout -q -b "feat/267-ahead"
  git -C "${FIX}/work" push -q origin "feat/267-ahead"
  git -C "${FIX}/work" fetch -q origin
  git -C "${FIX}/work" commit -q --allow-empty -m local-1
  git -C "${FIX}/work" commit -q --allow-empty -m local-2
  run ahead_in_fixture "feat/267-ahead"
  [ "$output" = "2" ]
}

@test "count_ahead_of_origin is 0 for a local-only branch with no origin ref" {
  git -C "${FIX}/work" branch "feat/267-localonly"
  run ahead_in_fixture "feat/267-localonly"
  [ "$output" = "0" ]
}
