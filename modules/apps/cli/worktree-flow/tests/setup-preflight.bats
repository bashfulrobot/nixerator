#!/usr/bin/env bats
# Regression tests for github-issue setup's branch-existence preflight (#262).
#
# The preflight refuses `setup` when this issue's branch already exists, so a
# second agent that slipped past the issue lease (or a prior run whose worktree
# was removed without deleting the branch) does not start a duplicate copy of
# the work. detect_existing_branch is the routable core of that check. These
# tests pin its four resolutions against real refs, including the local-branch
# case that would otherwise die later at `git worktree add -b` with a raw git
# error instead of a structured cause.
load helper

setup() { setup_fixture; }
teardown() { rm_fixture; }

@test "none when the branch exists neither locally nor on origin" {
  run detect "feat/262-absent"
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

@test "remote when the branch exists only on origin" {
  push_remote_only "feat/262-remote"
  run detect "feat/262-remote"
  [ "$status" -eq 0 ]
  [ "$output" = "remote" ]
}

@test "local when the branch exists only locally" {
  git -C "${FIX}/work" branch "feat/262-local"
  run detect "feat/262-local"
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

@test "both when the branch exists locally and on origin" {
  git -C "${FIX}/work" branch "feat/262-both"
  git -C "${FIX}/work" push -q origin "feat/262-both"
  run detect "feat/262-both"
  [ "$status" -eq 0 ]
  [ "$output" = "both" ]
}

@test "branch names with slashes resolve correctly" {
  push_remote_only "feat/262-a/b/c"
  run detect "feat/262-a/b/c"
  [ "$status" -eq 0 ]
  [ "$output" = "remote" ]
}
