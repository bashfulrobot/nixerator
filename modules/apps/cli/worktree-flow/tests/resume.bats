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

@test "count_behind_of_origin counts commits origin has that local lacks" {
  orig="$(git -C "${FIX}/work" rev-parse --abbrev-ref HEAD)"
  git -C "${FIX}/work" checkout -q -b "feat/267-behind"
  git -C "${FIX}/work" push -q origin "feat/267-behind"
  git -C "${FIX}/work" commit -q --allow-empty -m origin-only
  git -C "${FIX}/work" push -q origin "feat/267-behind"
  git -C "${FIX}/work" reset -q --hard HEAD~1
  git -C "${FIX}/work" fetch -q origin
  git -C "${FIX}/work" checkout -q "$orig"
  run behind_in_fixture "feat/267-behind"
  [ "$output" = "1" ]
}

@test "add_resume_worktree remote creates a tracking branch on origin's tip" {
  push_remote_only "feat/267-r"
  git -C "${FIX}/work" fetch -q origin
  originref="$(git -C "${FIX}/work" rev-parse "refs/remotes/origin/feat/267-r")"
  run resume_wt_add remote 0 "feat/267-r" "${FIX}/wt-r"
  [ "$status" -eq 0 ]
  [ "$(git -C "${FIX}/wt-r" rev-parse HEAD)" = "$originref" ]
  git -C "${FIX}/work" show-ref --verify --quiet "refs/heads/feat/267-r"
}

@test "add_resume_worktree both with local ahead preserves the local commits" {
  orig="$(git -C "${FIX}/work" rev-parse --abbrev-ref HEAD)"
  git -C "${FIX}/work" checkout -q -b "feat/267-ba"
  git -C "${FIX}/work" push -q origin "feat/267-ba"
  git -C "${FIX}/work" fetch -q origin
  git -C "${FIX}/work" commit -q --allow-empty -m local-1
  git -C "${FIX}/work" commit -q --allow-empty -m local-2
  tip="$(git -C "${FIX}/work" rev-parse HEAD)"
  git -C "${FIX}/work" checkout -q "$orig"
  run resume_wt_add both 2 "feat/267-ba" "${FIX}/wt-ba"
  [ "$status" -eq 0 ]
  # Worktree is on the local tip, so the two unpushed commits are not discarded.
  [ "$(git -C "${FIX}/wt-ba" rev-parse HEAD)" = "$tip" ]
}

@test "add_resume_worktree both in sync lands on origin's tip" {
  orig="$(git -C "${FIX}/work" rev-parse --abbrev-ref HEAD)"
  git -C "${FIX}/work" branch "feat/267-bs"
  git -C "${FIX}/work" push -q origin "feat/267-bs"
  git -C "${FIX}/work" fetch -q origin
  originref="$(git -C "${FIX}/work" rev-parse "refs/remotes/origin/feat/267-bs")"
  run resume_wt_add both 0 "feat/267-bs" "${FIX}/wt-bs"
  [ "$status" -eq 0 ]
  [ "$(git -C "${FIX}/wt-bs" rev-parse HEAD)" = "$originref" ]
}

@test "add_resume_worktree local attaches the local-only branch" {
  git -C "${FIX}/work" branch "feat/267-lo"
  localref="$(git -C "${FIX}/work" rev-parse "refs/heads/feat/267-lo")"
  run resume_wt_add local 0 "feat/267-lo" "${FIX}/wt-lo"
  [ "$status" -eq 0 ]
  [ "$(git -C "${FIX}/wt-lo" rev-parse HEAD)" = "$localref" ]
}

@test "add_resume_worktree returns 3 when the origin tracking ref is missing" {
  # Split-brain: ls-remote reported the branch (state "remote") but a failed
  # fetch left no tracking ref. add_resume_worktree must refuse with 3, not let
  # git worktree add abort raw.
  push_remote_only "feat/267-noref"
  git -C "${FIX}/work" fetch -q origin
  git -C "${FIX}/work" update-ref -d "refs/remotes/origin/feat/267-noref"
  run resume_wt_add remote 0 "feat/267-noref" "${FIX}/wt-noref"
  [ "$status" -eq 3 ]
  [ ! -e "${FIX}/wt-noref" ]
}
